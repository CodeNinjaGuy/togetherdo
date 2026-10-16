/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Zeitgesteuerte Kalender-Functions:
// - `erinnerungenSenden` alle 5 Minuten: fällige Termin-Erinnerungen als Push
//   und/oder E-Mail, genau einmal (Idempotenz über `letzteErinnerungSchluessel`,
//   „Claim“ in einer Transaktion vor dem Versand).
// - `wochenueberblickSenden` sonntags 18:00 (Europe/Vienna): Wochenüberblick
//   der kommenden Woche an Nutzer mit `mailEinstellungen.wochenueberblick`.
//
// Die Kerne `erinnerungenVerarbeiten` und `wochenueberblickVerarbeiten` nehmen
// ihre Abhängigkeiten als Parameter und sind gegen den Emulator testbar.

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { Timestamp } from 'firebase-admin/firestore';
import { REGION } from './common';
import {
  Termin,
  Vorkommen,
  Erinnerung,
  terminAusDaten,
  naechsteErinnerung,
  betroffenePersonen,
  vorkommenImFenster,
  zuWandMs,
  ausWandMs,
  STANDARD_ZEITZONE,
} from './termine_logik';
import {
  KalenderDeps,
  ListenInfo,
  Nutzer,
  listenInfoAus,
  ladeListe,
  ladeNutzer,
  nameVon,
  fussLinks,
  mailSicherSenden,
  standardDeps,
} from './empfaenger';
import { sesSecrets } from './mail/sesVersand';
import { erinnerungsMail, wochenueberblickMail, WochenEintrag } from './mail/vorlagen';
import { icsFuerTermin } from './mail/ical';
import { t, uhrzeitText, datumKurz } from './mail/texte';

export const PUSH_TYP_ERINNERUNG = 'termin_erinnerung';

/** Älter als das → nicht mehr senden, nur fortschreiben. */
export const MAX_VERSPAETUNG_MS = 2 * 60 * 60 * 1000;
/** Höchstens so viele Termine je Lauf. */
export const GRENZE_JE_LAUF = 1000;

const MS_TAG = 24 * 60 * 60 * 1000;

export interface ErinnerungsErgebnis {
  geprueft: number;
  gesendet: number;
  /** nur fortgeschrieben (schon gesendet, verspätet oder noch nicht fällig) */
  fortgeschrieben: number;
  fehler: number;
}

type Entscheidung =
  | { art: 'senden'; termin: Termin; erinnerung: Erinnerung }
  | { art: 'nur-fortschreiben' }
  | { art: 'ungueltig' };

/**
 * Entscheidet in einer Transaktion, was mit einem fälligen Termin passiert, und
 * schreibt `naechsteErinnerungAm` (und beim Claim `letzteErinnerungSchluessel`).
 */
async function beanspruche(deps: KalenderDeps, terminId: string, jetzt: Date): Promise<Entscheidung> {
  const ref = deps.db.collection('termine').doc(terminId);
  return deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { art: 'ungueltig' };
    const termin = terminAusDaten(snap.id, snap.data() as Record<string, unknown>);
    if (!termin) return { art: 'ungueltig' };
    const faelligAb = termin.naechsteErinnerungAm;
    if (!faelligAb || faelligAb.getTime() > jetzt.getTime()) return { art: 'nur-fortschreiben' };

    // Die Erinnerung, die diesen Lauf ausgelöst hat: die erste ab dem
    // gespeicherten Fälligkeitspunkt (einschließlich).
    const faellig = naechsteErinnerung(termin, new Date(faelligAb.getTime() - 1));
    const danach = naechsteErinnerung(termin, jetzt);
    const naechste = danach ? Timestamp.fromDate(danach.zeitpunkt) : null;

    if (!faellig || faellig.zeitpunkt.getTime() > jetzt.getTime()) {
      // Nichts (mehr) fällig, z. B. Termin verschoben: nur den Zeiger richten.
      tx.update(ref, { naechsteErinnerungAm: naechste });
      return { art: 'nur-fortschreiben' };
    }
    const verspaetet = jetzt.getTime() - faellig.zeitpunkt.getTime() > MAX_VERSPAETUNG_MS;
    if (verspaetet || faellig.schluessel === termin.letzteErinnerungSchluessel) {
      tx.update(ref, { naechsteErinnerungAm: naechste });
      return { art: 'nur-fortschreiben' };
    }
    tx.update(ref, { naechsteErinnerungAm: naechste, letzteErinnerungSchluessel: faellig.schluessel });
    return { art: 'senden', termin, erinnerung: faellig };
  });
}

function pushErlaubt(n: Nutzer): boolean {
  return (n.erinnerungen === 'push' || n.erinnerungen === 'beide') && !!n.fcmToken;
}

function mailErlaubt(n: Nutzer): boolean {
  return (n.erinnerungen === 'mail' || n.erinnerungen === 'beide') && !!n.email;
}

/** Vorkommen, das zur Erinnerung gehört (Ende aus der Dauer des Termins). */
function vorkommenZu(termin: Termin, erinnerung: Erinnerung): Vorkommen {
  const treffer = vorkommenImFenster(termin, erinnerung.vorkommenStart, new Date(erinnerung.vorkommenStart.getTime() + 1), 1);
  if (treffer.length > 0 && treffer[0].start.getTime() === erinnerung.vorkommenStart.getTime()) return treffer[0];
  const dauer = termin.ende.getTime() - termin.start.getTime();
  return { start: erinnerung.vorkommenStart, ende: new Date(erinnerung.vorkommenStart.getTime() + dauer) };
}

async function versende(deps: KalenderDeps, termin: Termin, erinnerung: Erinnerung): Promise<number> {
  const liste = await ladeListe(deps, termin.listId);
  const empfaengerIds = betroffenePersonen(termin, liste?.allUserIds ?? []);
  if (empfaengerIds.length === 0) return 0;
  const nutzer = await ladeNutzer(deps, [...empfaengerIds, ...(liste?.allUserIds ?? [])]);
  const vorkommen = vorkommenZu(termin, erinnerung);
  const personenNamen =
    termin.personen.length > 0 ? termin.personen.map((uid) => nameVon(uid, liste, nutzer)).filter(Boolean) : [];
  let gesendet = 0;

  // Push: je Sprache ein Text, Tokens gebündelt.
  const pushGruppen = new Map<string, string[]>();
  for (const uid of empfaengerIds) {
    const n = nutzer.get(uid);
    if (!n || !pushErlaubt(n)) continue;
    const gruppe = pushGruppen.get(n.sprache) ?? [];
    gruppe.push(n.fcmToken as string);
    pushGruppen.set(n.sprache, gruppe);
  }
  for (const [sprache, tokens] of pushGruppen) {
    const sp = sprache as 'de' | 'en';
    const zeit = termin.ganztaegig
      ? `${datumKurz(sp, vorkommen.start, termin.zeitzone)}, ${t(sp, 'ganztaegig')}`
      : `${datumKurz(sp, vorkommen.start, termin.zeitzone)}, ${uhrzeitText(sp, vorkommen.start, termin.zeitzone)}`;
    const body = [zeit, termin.ort ?? ''].filter(Boolean).join(' · ');
    try {
      await deps.pushSenden(tokens, {
        title: termin.titel || t(sp, 'erinnerung.titel'),
        body,
        data: {
          type: PUSH_TYP_ERINNERUNG,
          terminId: termin.id,
          listId: termin.listId,
          vorkommenStart: vorkommen.start.toISOString(),
        },
      });
      gesendet += tokens.length;
    } catch (e) {
      console.warn('⚠️ Push-Erinnerung fehlgeschlagen:', (e as Error).message);
    }
  }

  // Mail: je Empfänger eigene Sprache, eigener Abmelde-Link, .ics-Anhang.
  for (const uid of empfaengerIds) {
    const n = nutzer.get(uid);
    if (!n || !mailErlaubt(n)) continue;
    const fuss = await fussLinks(deps, n, 'abmelden');
    const vorlage = erinnerungsMail({
      sprache: n.sprache,
      empfaengerName: nameVon(uid, liste, nutzer),
      termin,
      vorkommen,
      minuten: erinnerung.minuten,
      listenName: liste?.name ?? '',
      personenNamen,
      fuss,
    });
    const ics = icsFuerTermin(termin, { vorkommen, personenNamen });
    const ok = await mailSicherSenden(deps, {
      an: n.email as string,
      betreff: vorlage.betreff,
      html: vorlage.html,
      text: vorlage.text,
      anhaenge: [{ dateiname: 'termin.ics', inhalt: ics, typ: 'text/calendar; charset=utf-8; method=PUBLISH' }],
      art: 'erinnerung',
    });
    if (ok) gesendet++;
  }
  return gesendet;
}

/** Kern des 5-Minuten-Laufs. `jetzt` ist injizierbar (Tests). */
export async function erinnerungenVerarbeiten(jetzt: Date, deps: KalenderDeps = standardDeps()): Promise<ErinnerungsErgebnis> {
  const ergebnis: ErinnerungsErgebnis = { geprueft: 0, gesendet: 0, fortgeschrieben: 0, fehler: 0 };
  const snap = await deps.db
    .collection('termine')
    .where('naechsteErinnerungAm', '<=', Timestamp.fromDate(jetzt))
    .orderBy('naechsteErinnerungAm')
    .limit(GRENZE_JE_LAUF)
    .get();
  for (const doc of snap.docs) {
    ergebnis.geprueft++;
    try {
      const entscheidung = await beanspruche(deps, doc.id, jetzt);
      if (entscheidung.art === 'senden') {
        ergebnis.gesendet += await versende(deps, entscheidung.termin, entscheidung.erinnerung);
      } else if (entscheidung.art === 'nur-fortschreiben') {
        ergebnis.fortgeschrieben++;
      }
    } catch (e) {
      ergebnis.fehler++;
      console.error('🚨 Erinnerung für Termin', doc.id, 'fehlgeschlagen:', (e as Error).message);
    }
  }
  return ergebnis;
}

export const erinnerungenSenden = onSchedule(
  { schedule: 'every 5 minutes', region: REGION, timeZone: 'Europe/Vienna', secrets: sesSecrets, timeoutSeconds: 300 },
  async () => {
    const e = await erinnerungenVerarbeiten(new Date());
    console.log(`ℹ️ Erinnerungen: geprüft=${e.geprueft} gesendet=${e.gesendet} fortgeschrieben=${e.fortgeschrieben} fehler=${e.fehler}`);
  },
);

// ---------------------------------------------------------- Wochenüberblick

export interface WochenErgebnis {
  nutzer: number;
  gesendet: number;
  /** Nutzer ohne Termine in der Woche (keine Mail) */
  leer: number;
}

/** Montag 0:00 der auf `jetzt` folgenden Woche in `zeitzone` (plus 7 Tage). */
export function kommendeWoche(jetzt: Date, zeitzone: string): { start: Date; ende: Date } {
  const wand = zuWandMs(jetzt, zeitzone);
  const tagStart = Math.floor(wand / MS_TAG) * MS_TAG;
  const wt = new Date(tagStart).getUTCDay(); // 0 = So
  const bisMontag = wt === 0 ? 1 : 8 - wt;
  const montag = tagStart + bisMontag * MS_TAG;
  return { start: ausWandMs(montag, zeitzone), ende: ausWandMs(montag + 7 * MS_TAG, zeitzone) };
}

/** Termine der Listen, deren `sichtbarBis` nicht vor `von` liegt (10er-Pakete). */
export async function termineDerListen(deps: KalenderDeps, listIds: string[], von: Date): Promise<Termin[]> {
  const termine: Termin[] = [];
  for (let i = 0; i < listIds.length; i += 10) {
    const chunk = listIds.slice(i, i + 10);
    const snap = await deps.db
      .collection('termine')
      .where('listId', 'in', chunk)
      .where('sichtbarBis', '>=', Timestamp.fromDate(von))
      .get();
    snap.forEach((doc) => {
      const termin = terminAusDaten(doc.id, doc.data() as Record<string, unknown>);
      if (termin) termine.push(termin);
    });
  }
  return termine;
}

/** Kern des Sonntagslaufs. */
export async function wochenueberblickVerarbeiten(jetzt: Date, deps: KalenderDeps = standardDeps()): Promise<WochenErgebnis> {
  const ergebnis: WochenErgebnis = { nutzer: 0, gesendet: 0, leer: 0 };
  const abonnenten = await deps.db.collection('users').where('mailEinstellungen.wochenueberblick', '==', true).get();
  const zeitzone = STANDARD_ZEITZONE;
  const woche = kommendeWoche(jetzt, zeitzone);

  for (const doc of abonnenten.docs) {
    ergebnis.nutzer++;
    const nutzer = (await ladeNutzer(deps, [doc.id])).get(doc.id);
    if (!nutzer || !nutzer.email || !nutzer.wochenueberblick) continue;
    try {
      const listenSnap = await deps.db.collection('lists').where('allUserIds', 'array-contains', nutzer.uid).get();
      const listen = new Map<string, ListenInfo>();
      listenSnap.forEach((l) => {
        const info = listenInfoAus(l.id, l.data());
        if (info) listen.set(l.id, info);
      });
      const termine = await termineDerListen(deps, [...listen.keys()], woche.start);
      const alleUids = new Set<string>();
      termine.forEach((te) => te.personen.forEach((p) => alleUids.add(p)));
      const namenNutzer = await ladeNutzer(deps, [...alleUids]);

      const eintraege: WochenEintrag[] = [];
      for (const termin of termine) {
        const liste = listen.get(termin.listId) ?? null;
        if (!betroffenePersonen(termin, liste?.allUserIds ?? []).includes(nutzer.uid)) continue;
        for (const vorkommen of vorkommenImFenster(termin, woche.start, woche.ende, 50)) {
          eintraege.push({
            termin,
            vorkommen,
            listenName: liste?.name ?? '',
            personenNamen: termin.personen.map((uid) => nameVon(uid, liste, namenNutzer)).filter(Boolean),
          });
        }
      }
      if (eintraege.length === 0) {
        ergebnis.leer++;
        continue;
      }
      const fuss = await fussLinks(deps, nutzer, 'wochenueberblick-aus');
      const vorlage = wochenueberblickMail({
        sprache: nutzer.sprache,
        empfaengerName: nutzer.displayName,
        zeitzone,
        wochenStart: woche.start,
        wochenEnde: woche.ende,
        eintraege,
        fuss,
      });
      const ok = await mailSicherSenden(deps, {
        an: nutzer.email,
        betreff: vorlage.betreff,
        html: vorlage.html,
        text: vorlage.text,
        art: 'wochenueberblick',
      });
      if (ok) ergebnis.gesendet++;
    } catch (e) {
      console.error('🚨 Wochenüberblick für Nutzer', nutzer.uid, 'fehlgeschlagen:', (e as Error).message);
    }
  }
  return ergebnis;
}

export const wochenueberblickSenden = onSchedule(
  { schedule: 'every sunday 18:00', region: REGION, timeZone: 'Europe/Vienna', secrets: sesSecrets, timeoutSeconds: 540 },
  async () => {
    const e = await wochenueberblickVerarbeiten(new Date());
    console.log(`ℹ️ Wochenüberblick: nutzer=${e.nutzer} gesendet=${e.gesendet} leer=${e.leer}`);
  },
);
