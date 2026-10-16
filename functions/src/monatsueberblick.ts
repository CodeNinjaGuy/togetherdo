/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Monatsüberblick-Mail („Was kommt im Monat“): am 1. jedes Monats um 07:00
// (Europe/Vienna) an Nutzer mit `mailEinstellungen.monatsueberblick === true`.
// Inhalt über alle Listen des Nutzers (`lists where allUserIds array-contains
// uid`): Highlights, freie Wochenenden, gemeinsamer Urlaub, wer wie viel
// unterwegs ist. Die Rechnerei steckt in `monatsueberblick_logik.ts`; der Kern
// `monatsueberblickVerarbeiten` nimmt seine Abhängigkeiten als Parameter und
// ist gegen den Emulator testbar.

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { REGION } from './common';
import { STANDARD_ZEITZONE } from './termine_logik';
import { KalenderDeps, ListenInfo, listenInfoAus, ladeNutzer, nameVon, fussLinks, mailSicherSenden, standardDeps } from './empfaenger';
import { termineDerListen } from './erinnerungen';
import { MonatsListe, monatsFenster, monatsueberblickBerechnen } from './monatsueberblick_logik';
import { sesSecrets } from './mail/sesVersand';
import { monatsueberblickMail } from './mail/vorlagen';

export interface MonatsErgebnis {
  nutzer: number;
  gesendet: number;
  /** Nutzer ohne ein einziges Vorkommen im Monat (keine Mail) */
  leer: number;
}

/** Kern des Monatslaufs. `jetzt` bestimmt den Monat (in Europe/Vienna). */
export async function monatsueberblickVerarbeiten(jetzt: Date, deps: KalenderDeps = standardDeps()): Promise<MonatsErgebnis> {
  const ergebnis: MonatsErgebnis = { nutzer: 0, gesendet: 0, leer: 0 };
  const abonnenten = await deps.db.collection('users').where('mailEinstellungen.monatsueberblick', '==', true).get();
  const zeitzone = STANDARD_ZEITZONE;
  const monat = monatsFenster(jetzt, zeitzone);

  for (const doc of abonnenten.docs) {
    ergebnis.nutzer++;
    const nutzer = (await ladeNutzer(deps, [doc.id])).get(doc.id);
    if (!nutzer || !nutzer.email || !nutzer.monatsueberblick) continue;
    try {
      const listenSnap = await deps.db.collection('lists').where('allUserIds', 'array-contains', nutzer.uid).get();
      const listen = new Map<string, ListenInfo>();
      listenSnap.forEach((l) => {
        const info = listenInfoAus(l.id, l.data());
        if (info) listen.set(l.id, info);
      });
      const termine = await termineDerListen(deps, [...listen.keys()], monat.start);
      const alleUids = new Set<string>();
      listen.forEach((l) => l.allUserIds.forEach((uid) => alleUids.add(uid)));
      termine.forEach((te) => te.personen.forEach((p) => alleUids.add(p)));
      const namenNutzer = await ladeNutzer(deps, [...alleUids]);

      const monatsListen: MonatsListe[] = [...listen.values()].map((l) => ({
        id: l.id,
        name: l.name,
        allUserIds: l.allUserIds,
        termine: termine.filter((te) => te.listId === l.id),
      }));
      const ueberblick = monatsueberblickBerechnen(monatsListen, monat, {
        zeitzone,
        nameVon: (uid, liste) => nameVon(uid, listen.get(liste.id) ?? null, namenNutzer),
      });
      if (ueberblick.anzahlVorkommen === 0) {
        ergebnis.leer++;
        continue;
      }
      const fuss = await fussLinks(deps, nutzer, 'monatsueberblick-aus');
      const vorlage = monatsueberblickMail({
        sprache: nutzer.sprache,
        empfaengerName: nutzer.displayName,
        zeitzone,
        monatsStart: monat.start,
        ueberblick,
        fuss,
      });
      const ok = await mailSicherSenden(deps, {
        an: nutzer.email,
        betreff: vorlage.betreff,
        html: vorlage.html,
        text: vorlage.text,
        art: 'monatsueberblick',
      });
      if (ok) ergebnis.gesendet++;
    } catch (e) {
      console.error('🚨 Monatsüberblick für Nutzer', nutzer.uid, 'fehlgeschlagen:', (e as Error).message);
    }
  }
  return ergebnis;
}

export const monatsueberblickSenden = onSchedule(
  { schedule: '1 of month 07:00', region: REGION, timeZone: 'Europe/Vienna', secrets: sesSecrets, timeoutSeconds: 540 },
  async () => {
    const e = await monatsueberblickVerarbeiten(new Date());
    console.log(`ℹ️ Monatsüberblick: nutzer=${e.nutzer} gesendet=${e.gesendet} leer=${e.leer}`);
  },
);
