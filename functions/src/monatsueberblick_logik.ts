/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Reine Logik des Monatsüberblicks („Was kommt im Monat“), ohne Firestore,
// testbar mit `node --test`. Rechnet in lokalen Tagen ('JJJJ-MM-TT'):
// Vorkommen werden in der Zeitzone des jeweiligen Termins auf Tage gelegt,
// das Monatsfenster liegt in der Zeitzone des Empfängers (Europe/Vienna).
//
// - Highlights: Urlaube, Geburtstage, Arzttermine, mehrtägige Termine.
// - Freie Wochenenden: Samstag und Sonntag ohne irgendeinen Eintrag (Termin,
//   Urlaub, Arbeit) für irgendein Mitglied der Listen.
// - Unterwegs: je Mitglied Urlaubstage, Arbeitstage/-stunden, Anzahl Termine.
// - Alle frei: Tage, an denen ALLE Mitglieder einer Liste Urlaub haben,
//   zu Zeiträumen zusammengefasst und auf den Monat beschnitten.

import { Termin, Vorkommen, betroffenePersonen, gueltigeZeitzone, vorkommenImFenster, zuWandMs, ausWandMs } from './termine_logik';

const MS_TAG = 24 * 60 * 60 * 1000;
const MS_STUNDE = 60 * 60 * 1000;
/** Höchstens so viele Vorkommen je Termin im Monat (tägliche Serie = 31). */
const MAX_VORKOMMEN_JE_TERMIN = 100;

export type HighlightArt = 'urlaub' | 'geburtstag' | 'arzt' | 'mehrtaegig';

/** Was die Logik über eine Liste wissen muss. */
export interface MonatsListe {
  id: string;
  name: string;
  allUserIds: string[];
  termine: Termin[];
}

export interface Zeitfenster {
  start: Date;
  /** exklusiv */
  ende: Date;
}

export interface MonatsHighlight {
  art: HighlightArt;
  termin: Termin;
  vorkommen: Vorkommen;
  listenName: string;
  personenNamen: string[];
  /** erster und letzter Tag ('JJJJ-MM-TT') innerhalb des Monats */
  vonTag: string;
  bisTag: string;
}

export interface FreiesWochenende {
  samstag: string;
  sonntag: string;
}

export interface Unterwegs {
  uid: string;
  name: string;
  urlaubstage: number;
  arbeitstage: number;
  /** nur Arbeitstermine mit Uhrzeit, auf den Monat beschnitten */
  arbeitsstunden: number;
  /** Vorkommen im Monat ohne Urlaub und Arbeit */
  termine: number;
}

export interface AlleFrei {
  listenId: string;
  listenName: string;
  vonTag: string;
  bisTag: string;
}

export interface Monatsueberblick {
  highlights: MonatsHighlight[];
  freieWochenenden: FreiesWochenende[];
  unterwegs: Unterwegs[];
  alleFrei: AlleFrei[];
  /** Vorkommen im Monat insgesamt (0 = nichts zu berichten) */
  anzahlVorkommen: number;
}

// ----------------------------------------------------------------- Zeitraum

/** Erster des Monats 0:00 bis Erster des Folgemonats 0:00 in `zeitzone`. */
export function monatsFenster(jetzt: Date, zeitzone: string): Zeitfenster {
  const w = new Date(zuWandMs(jetzt, zeitzone));
  const j = w.getUTCFullYear();
  const m = w.getUTCMonth();
  return { start: ausWandMs(Date.UTC(j, m, 1), zeitzone), ende: ausWandMs(Date.UTC(j, m + 1, 1), zeitzone) };
}

function tagVonWand(wandMs: number): string {
  const d = new Date(Math.floor(wandMs / MS_TAG) * MS_TAG);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

/** 'JJJJ-MM-TT' → Wand-Millisekunden um 0:00. */
export function tagZuWand(tag: string): number {
  const [j, m, t] = tag.split('-').map(Number);
  return Date.UTC(j, m - 1, t);
}

/** Lokale Tage, die ein Vorkommen innerhalb des Fensters berührt (Zeitzone des Termins). */
export function tageDesVorkommens(v: Vorkommen, zeitzone: string, fenster: Zeitfenster): string[] {
  const tz = gueltigeZeitzone(zeitzone);
  const von = Math.max(v.start.getTime(), fenster.start.getTime());
  const endeExkl = Math.min(v.ende.getTime(), fenster.ende.getTime());
  if (von >= fenster.ende.getTime()) return [];
  if (v.ende.getTime() > v.start.getTime() && v.ende.getTime() <= fenster.start.getTime()) return [];
  const letzter = endeExkl > von ? endeExkl - 1 : von;
  const ersterTag = Math.floor(zuWandMs(new Date(von), tz) / MS_TAG);
  const letzterTag = Math.floor(zuWandMs(new Date(letzter), tz) / MS_TAG);
  const tage: string[] = [];
  for (let t = ersterTag; t <= letzterTag && tage.length <= 400; t++) tage.push(tagVonWand(t * MS_TAG));
  return tage;
}

/** Alle lokalen Tage des Fensters (Zeitzone des Empfängers), aufsteigend. */
export function tageImFenster(fenster: Zeitfenster, zeitzone: string): string[] {
  const von = Math.floor(zuWandMs(fenster.start, zeitzone) / MS_TAG);
  const bis = Math.floor((zuWandMs(fenster.ende, zeitzone) - 1) / MS_TAG);
  const tage: string[] = [];
  for (let t = von; t <= bis && tage.length <= 400; t++) tage.push(tagVonWand(t * MS_TAG));
  return tage;
}

/** Wochentag 1 = Mo … 7 = So eines lokalen Tags. */
function wochentagVon(tag: string): number {
  const w = new Date(tagZuWand(tag)).getUTCDay();
  return w === 0 ? 7 : w;
}

function naechsterTag(tag: string): string {
  return tagVonWand(tagZuWand(tag) + MS_TAG);
}

/** Aufsteigend sortierte Tage zu zusammenhängenden Zeiträumen zusammenfassen. */
export function zeitraeumeAus(tage: Iterable<string>): { vonTag: string; bisTag: string }[] {
  const sortiert = [...new Set(tage)].sort();
  const bereiche: { vonTag: string; bisTag: string }[] = [];
  for (const tag of sortiert) {
    const letzter = bereiche[bereiche.length - 1];
    if (letzter && naechsterTag(letzter.bisTag) === tag) letzter.bisTag = tag;
    else bereiche.push({ vonTag: tag, bisTag: tag });
  }
  return bereiche;
}

// ----------------------------------------------------------------- Zählung

interface Eintrag {
  liste: MonatsListe;
  termin: Termin;
  vorkommen: Vorkommen;
  betroffene: string[];
  tage: string[];
}

function eintraegeImMonat(listen: MonatsListe[], monat: Zeitfenster, mitFolgetag: boolean): Eintrag[] {
  const fenster = mitFolgetag ? { start: monat.start, ende: new Date(monat.ende.getTime() + MS_TAG) } : monat;
  const eintraege: Eintrag[] = [];
  for (const liste of listen) {
    for (const termin of liste.termine) {
      const betroffene = betroffenePersonen(termin, liste.allUserIds);
      for (const vorkommen of vorkommenImFenster(termin, fenster.start, fenster.ende, MAX_VORKOMMEN_JE_TERMIN)) {
        const tage = tageDesVorkommens(vorkommen, termin.zeitzone, fenster);
        if (tage.length === 0) continue;
        eintraege.push({ liste, termin, vorkommen, betroffene, tage });
      }
    }
  }
  return eintraege;
}

function highlightArt(e: Eintrag): HighlightArt | null {
  if (e.termin.art === 'urlaub') return 'urlaub';
  if (e.termin.art === 'geburtstag') return 'geburtstag';
  if (e.termin.art === 'arzt') return 'arzt';
  // Mehrtägig: berührt (ungeschnitten) mindestens zwei lokale Tage.
  const ganz = tageDesVorkommens(e.vorkommen, e.termin.zeitzone, {
    start: e.vorkommen.start,
    ende: new Date(Math.max(e.vorkommen.ende.getTime(), e.vorkommen.start.getTime() + 1)),
  });
  return ganz.length >= 2 ? 'mehrtaegig' : null;
}

/** Stunden des Vorkommens innerhalb des Fensters (nur mit Uhrzeit). */
function stundenImFenster(v: Vorkommen, fenster: Zeitfenster): number {
  const von = Math.max(v.start.getTime(), fenster.start.getTime());
  const bis = Math.min(v.ende.getTime(), fenster.ende.getTime());
  return bis > von ? (bis - von) / MS_STUNDE : 0;
}

export interface MonatsOptionen {
  /** Zeitzone des Empfängers (Monatsfenster, Wochenenden). */
  zeitzone: string;
  nameVon: (uid: string, liste: MonatsListe) => string;
}

/** Baut den vollständigen Monatsüberblick für die Listen eines Empfängers. */
export function monatsueberblickBerechnen(listen: MonatsListe[], monat: Zeitfenster, optionen: MonatsOptionen): Monatsueberblick {
  const imMonat = eintraegeImMonat(listen, monat, false);
  const zeitzone = gueltigeZeitzone(optionen.zeitzone);

  // Highlights, sortiert nach Beginn.
  const highlights: MonatsHighlight[] = [];
  for (const e of imMonat) {
    const art = highlightArt(e);
    if (!art) continue;
    highlights.push({
      art,
      termin: e.termin,
      vorkommen: e.vorkommen,
      listenName: e.liste.name,
      personenNamen: e.termin.personen.map((uid) => optionen.nameVon(uid, e.liste)).filter(Boolean),
      vonTag: e.tage[0],
      bisTag: e.tage[e.tage.length - 1],
    });
  }
  highlights.sort((a, b) => a.vorkommen.start.getTime() - b.vorkommen.start.getTime() || a.termin.titel.localeCompare(b.termin.titel));

  // Freie Wochenenden: Samstag im Monat, Sonntag darf in den Folgemonat fallen.
  const belegt = new Set<string>();
  for (const e of eintraegeImMonat(listen, monat, true)) e.tage.forEach((t) => belegt.add(t));
  const freieWochenenden: FreiesWochenende[] = [];
  for (const tag of tageImFenster(monat, zeitzone)) {
    if (wochentagVon(tag) !== 6) continue;
    const sonntag = naechsterTag(tag);
    if (!belegt.has(tag) && !belegt.has(sonntag)) freieWochenenden.push({ samstag: tag, sonntag });
  }

  // Unterwegs je Mitglied (über alle Listen, Tage je Person nur einmal).
  const personen = new Map<string, { name: string; urlaub: Set<string>; arbeit: Set<string>; stunden: number; termine: number }>();
  for (const liste of listen) {
    for (const uid of liste.allUserIds) {
      if (!personen.has(uid)) personen.set(uid, { name: optionen.nameVon(uid, liste), urlaub: new Set(), arbeit: new Set(), stunden: 0, termine: 0 });
      else if (!personen.get(uid)!.name) personen.get(uid)!.name = optionen.nameVon(uid, liste);
    }
  }
  for (const e of imMonat) {
    for (const uid of e.betroffene) {
      const p = personen.get(uid);
      if (!p) continue;
      if (e.termin.art === 'urlaub') e.tage.forEach((t) => p.urlaub.add(t));
      else if (e.termin.art === 'arbeit') {
        e.tage.forEach((t) => p.arbeit.add(t));
        if (!e.termin.ganztaegig) p.stunden += stundenImFenster(e.vorkommen, monat);
      } else p.termine++;
    }
  }
  const unterwegs: Unterwegs[] = [...personen.entries()]
    .map(([uid, p]) => ({
      uid,
      name: p.name,
      urlaubstage: p.urlaub.size,
      arbeitstage: p.arbeit.size,
      arbeitsstunden: Math.round(p.stunden * 10) / 10,
      termine: p.termine,
    }))
    .sort((a, b) => a.name.localeCompare(b.name) || a.uid.localeCompare(b.uid));

  // Alle frei: je Liste (ab 2 Mitgliedern) Tage, an denen jedes Mitglied Urlaub hat.
  const alleFrei: AlleFrei[] = [];
  for (const liste of listen) {
    const mitglieder = [...new Set(liste.allUserIds)];
    if (mitglieder.length < 2) continue;
    const urlaubJeTag = new Map<string, Set<string>>();
    for (const e of imMonat) {
      if (e.liste !== liste || e.termin.art !== 'urlaub') continue;
      for (const tag of e.tage) {
        const s = urlaubJeTag.get(tag) ?? new Set<string>();
        e.betroffene.forEach((uid) => s.add(uid));
        urlaubJeTag.set(tag, s);
      }
    }
    const gemeinsam = [...urlaubJeTag.entries()].filter(([, s]) => mitglieder.every((uid) => s.has(uid))).map(([tag]) => tag);
    for (const z of zeitraeumeAus(gemeinsam)) alleFrei.push({ listenId: liste.id, listenName: liste.name, ...z });
  }
  alleFrei.sort((a, b) => a.vonTag.localeCompare(b.vonTag) || a.listenName.localeCompare(b.listenName));

  return { highlights, freieWochenenden, unterwegs, alleFrei, anzahlVorkommen: imMonat.length };
}
