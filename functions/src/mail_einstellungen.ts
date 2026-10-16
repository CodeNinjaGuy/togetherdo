/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Abmelde-/Einstellungs-Link aus der Mail-Fußzeile (`mailEinstellungen`).
//
// GET ?uid=…&token=…&aktion=abmelden|wochenueberblick-aus|monatsueberblick-aus
// Das Token ist `users/{uid}.mailAbmeldeToken` (nur die Function schreibt es).
// Bei Erfolg wird die Einstellung gesetzt und eine kleine Bestätigungsseite
// (de/en nach `languageCode`, sonst Browser-Sprache) angezeigt. Der Vergleich
// läuft zeitkonstant; die Antwort ist bei falschem uid und falschem Token gleich.

import { timingSafeEqual } from 'crypto';
import { onRequest } from 'firebase-functions/v2/https';
import type { Firestore } from 'firebase-admin/firestore';
import { db, REGION } from './common';
import { MailAktion } from './empfaenger';
import { Sprache, spracheVon, t } from './mail/texte';
import { einstellungsSeite } from './mail/vorlagen';

export interface Antwort {
  status: number;
  html: string;
}

export const AKTIONEN: readonly MailAktion[] = ['abmelden', 'wochenueberblick-aus', 'monatsueberblick-aus'];

function tokenGleich(a: string, b: string): boolean {
  const ba = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  if (ba.length !== bb.length || ba.length === 0) return false;
  return timingSafeEqual(ba, bb);
}

/** Kern: prüft Token, setzt Einstellung, liefert Seite. */
export async function mailEinstellungenAnwenden(
  query: Record<string, unknown>,
  datenbank: Firestore = db,
  browserSprache: Sprache = 'de',
): Promise<Antwort> {
  const uid = typeof query.uid === 'string' ? query.uid.trim() : '';
  const token = typeof query.token === 'string' ? query.token.trim() : '';
  const aktion = typeof query.aktion === 'string' ? query.aktion.trim() : '';
  const ungueltig = (sprache: Sprache): Antwort => ({ status: 400, html: einstellungsSeite(sprache, t(sprache, 'seite.ungueltig'), false) });

  if (!uid || !token || !AKTIONEN.includes(aktion as MailAktion) || uid.length > 128 || token.length > 256) {
    return ungueltig(browserSprache);
  }
  const ref = datenbank.collection('users').doc(uid);
  const snap = await ref.get();
  const daten = snap.data();
  const sprache = daten ? spracheVon(daten.languageCode) : browserSprache;
  const gespeichert = typeof daten?.mailAbmeldeToken === 'string' ? daten.mailAbmeldeToken : '';
  if (!snap.exists || !tokenGleich(gespeichert, token)) return ungueltig(sprache);

  if (aktion === 'abmelden') {
    await ref.set({ mailEinstellungen: { erinnerungen: 'push' } }, { merge: true });
    return { status: 200, html: einstellungsSeite(sprache, t(sprache, 'seite.abgemeldet'), true) };
  }
  if (aktion === 'monatsueberblick-aus') {
    await ref.set({ mailEinstellungen: { monatsueberblick: false } }, { merge: true });
    return { status: 200, html: einstellungsSeite(sprache, t(sprache, 'seite.monatsueberblick.aus'), true) };
  }
  await ref.set({ mailEinstellungen: { wochenueberblick: false } }, { merge: true });
  return { status: 200, html: einstellungsSeite(sprache, t(sprache, 'seite.wochenueberblick.aus'), true) };
}

export const mailEinstellungen = onRequest({ region: REGION }, async (req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.status(405).set('Allow', 'GET').send('Method Not Allowed');
    return;
  }
  const browserSprache = spracheVon(String(req.headers['accept-language'] ?? '').split(',')[0]);
  const antwort = await mailEinstellungenAnwenden(req.query as Record<string, unknown>, db, browserSprache);
  res
    .status(antwort.status)
    .set('Cache-Control', 'no-store')
    .set('Referrer-Policy', 'no-referrer')
    .set('X-Robots-Tag', 'noindex')
    .type('html')
    .send(antwort.html);
});
