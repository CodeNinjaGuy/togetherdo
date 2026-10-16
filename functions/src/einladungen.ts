/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Einladung zu einer Liste per E-Mail (`inviteByEmail`).
//
// Nur der Besitzer der Liste darf einladen, höchstens 10 Mails je Stunde je
// Nutzer und 3 je Tag an dieselbe Adresse (als Hash). Die Antwort verrät nie,
// ob zur Adresse ein Konto existiert – auch nicht über Fehlercodes oder
// Laufzeit-Unterschiede, die wir beeinflussen können. Adressen werden nirgends
// protokolliert.

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { REGION, requireAuth } from './common';
import { KalenderDeps, ladeListe, ladeNutzer, nameVon, standardDeps, Nutzer } from './empfaenger';
import { pruefeUndZaehle, STUNDE, TAG } from './mail/ratenGrenze';
import { sesSecrets } from './mail/sesVersand';
import { einladungsMail } from './mail/vorlagen';
import { Sprache } from './mail/texte';

export const EINLADUNGEN_JE_STUNDE = 10;
export const EINLADUNGEN_JE_ADRESSE_TAG = 3;

const EMAIL_MUSTER = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export interface EinladungsAuftrag {
  uid: string;
  listId: string;
  email: string;
}

export interface EinladungsErgebnis {
  /** immer true bei gültiger Anfrage – verrät nichts über die Adresse */
  gesendet: true;
}

export function pruefeEmail(wert: unknown): string {
  const email = typeof wert === 'string' ? wert.trim() : '';
  if (!email || email.length > 254 || !EMAIL_MUSTER.test(email)) {
    throw new HttpsError('invalid-argument', 'Ungültige E-Mail-Adresse');
  }
  return email;
}

/** Kern von `inviteByEmail`, testbar mit Fake-Mailversand. */
export async function einladungVersenden(
  auftrag: EinladungsAuftrag,
  deps: KalenderDeps = standardDeps(),
  jetzt: number = Date.now(),
): Promise<EinladungsErgebnis> {
  const listId = typeof auftrag.listId === 'string' ? auftrag.listId.trim() : '';
  if (!listId) throw new HttpsError('invalid-argument', 'listId fehlt');
  const email = pruefeEmail(auftrag.email);

  const liste = await ladeListe(deps, listId);
  if (!liste) throw new HttpsError('not-found', 'Liste nicht gefunden');
  if (liste.ownerId !== auftrag.uid) throw new HttpsError('permission-denied', 'Nur der Besitzer kann einladen');
  if (!liste.shareCode) throw new HttpsError('failed-precondition', 'Liste hat keinen Beitritts-Code');

  if (!(await pruefeUndZaehle(deps.db, 'einladung_nutzer', auftrag.uid, [{ fensterMs: STUNDE, max: EINLADUNGEN_JE_STUNDE }], jetzt))) {
    throw new HttpsError('resource-exhausted', 'Zu viele Einladungen. Bitte später erneut probieren.');
  }
  // Je Adresse (gehasht): still begrenzen, Antwort bleibt gleich.
  const adresseFrei = await pruefeUndZaehle(deps.db, 'einladung_adresse', email, [{ fensterMs: TAG, max: EINLADUNGEN_JE_ADRESSE_TAG }], jetzt);
  if (!adresseFrei) return { gesendet: true };

  const einlader = (await ladeNutzer(deps, [auftrag.uid])).get(auftrag.uid);
  const einladerName = nameVon(auftrag.uid, liste, einlader ? new Map([[auftrag.uid, einlader]]) : new Map()) || 'Jemand';

  // Sprache: Konto zur Adresse (falls vorhanden) → Einlader → Deutsch. Hat der
  // Empfänger Einladungen abgestellt, wird still nicht gesendet.
  let sprache: Sprache = einlader?.sprache ?? 'de';
  const kontoSnap = await deps.db.collection('users').where('email', '==', email).limit(1).get();
  let empfaenger: Nutzer | null = null;
  if (!kontoSnap.empty) {
    const doc = kontoSnap.docs[0];
    empfaenger = (await ladeNutzer(deps, [doc.id])).get(doc.id) ?? null;
    if (empfaenger) sprache = empfaenger.sprache;
  }
  if (empfaenger && !empfaenger.einladungen) return { gesendet: true };
  if (empfaenger && liste.allUserIds.includes(empfaenger.uid)) return { gesendet: true };

  const vorlage = einladungsMail({
    sprache,
    einladerName,
    listenName: liste.name || 'Liste',
    shareCode: liste.shareCode,
    // Einladungen gehen auch an Adressen ohne Konto: kein persönliches Token,
    // der Einstellungs-Link führt allgemein zur App-Seite.
    fuss: { einstellungen: 'https://seebubble.me/togetherdo' },
  });
  try {
    await deps.mailSenden({ an: email, betreff: vorlage.betreff, html: vorlage.html, text: vorlage.text, art: 'einladung' });
  } catch (e) {
    console.warn('⚠️ Einladungsmail nicht verschickt:', (e as Error).message);
    throw new HttpsError('unavailable', 'Die Einladung konnte gerade nicht verschickt werden.');
  }
  return { gesendet: true };
}

export const inviteByEmail = onCall({ region: REGION, secrets: sesSecrets }, async (request) => {
  const uid = requireAuth(request);
  const data = (request.data ?? {}) as { listId?: unknown; email?: unknown };
  return einladungVersenden({ uid, listId: String(data.listId ?? ''), email: String(data.email ?? '') });
});
