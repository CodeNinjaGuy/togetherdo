/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Reine Kalenderlogik ohne Firebase-Abhängigkeit (testbar mit `node --test`).
//
// - Wiederholungen werden in der Wanduhrzeit der `zeitzone` des Termins
//   fortgeschrieben (6:00 bleibt 6:00, auch über die Sommerzeit hinweg).
//   Die Zeitzonen-Umrechnung läuft über `Intl.DateTimeFormat` (Node 22 hat
//   volle ICU), kein zusätzliches Paket.
// - `naechsteErinnerung` liefert den nächsten fälligen Erinnerungszeitpunkt
//   samt Idempotenz-Schlüssel `"<Vorkommen-Start ISO UTC>|<Minuten>"`.
// - `sichtbarBis` liefert das Ende des letzten Vorkommens (endlos = 2200-01-01).

export type WiederholungTyp = 'taeglich' | 'woechentlich' | 'monatlich' | 'jaehrlich';

export const WIEDERHOLUNG_TYPEN: readonly WiederholungTyp[] = ['taeglich', 'woechentlich', 'monatlich', 'jaehrlich'];

export interface Wiederholung {
  typ: WiederholungTyp;
  /** >= 1 */
  intervall: number;
  /** 1 = Mo … 7 = So, nur bei `woechentlich` */
  wochentage: number[];
  /** einschließlich; Vorkommen mit Start nach diesem Zeitpunkt entfallen */
  bisDatum: Date | null;
  anzahl: number | null;
  /** 'JJJJ-MM-TT' lokale Tage in `zeitzone`, die übersprungen werden */
  ausnahmen: string[];
}

export interface Termin {
  id: string;
  listId: string;
  titel: string;
  art: string;
  /** leer = alle Mitglieder der Liste */
  personen: string[];
  start: Date;
  /** exklusiv; bei Serien das Ende des ersten Vorkommens */
  ende: Date;
  ganztaegig: boolean;
  ort: string | null;
  notiz: string | null;
  zeitzone: string;
  wiederholung: Wiederholung | null;
  /** Minuten vor Start, 0 = zum Start */
  erinnerungen: number[];
  erstelltVon: string;
  erstelltAm: Date | null;
  aktualisiertAm: Date | null;
  sichtbarBis: Date | null;
  naechsteErinnerungAm: Date | null;
  letzteErinnerungSchluessel: string | null;
}

export interface Vorkommen {
  start: Date;
  ende: Date;
}

export interface Erinnerung {
  zeitpunkt: Date;
  vorkommenStart: Date;
  minuten: number;
  schluessel: string;
}

export const STANDARD_ZEITZONE = 'Europe/Vienna';

/** Letzter sichtbarer Zeitpunkt endloser Serien (wie `terminUnendlich` in der App). */
export const TERMIN_UNENDLICH = new Date(Date.UTC(2200, 0, 1));

const MS_TAG = 24 * 60 * 60 * 1000;
/** Sicherheitsgrenze gegen Endlosschleifen bei der Expansion. */
const MAX_SCHRITTE = 200_000;

// ------------------------------------------------------------------ Zeitzone

const formatter = new Map<string, Intl.DateTimeFormat>();

function holeFormatter(zeitzone: string): Intl.DateTimeFormat {
  let f = formatter.get(zeitzone);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: zeitzone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    formatter.set(zeitzone, f);
  }
  return f;
}

/** Liefert eine gültige IANA-Zeitzone (unbekannte → Europe/Vienna). */
export function gueltigeZeitzone(zeitzone: unknown): string {
  if (typeof zeitzone !== 'string' || !zeitzone) return STANDARD_ZEITZONE;
  try {
    holeFormatter(zeitzone);
    return zeitzone;
  } catch {
    return STANDARD_ZEITZONE;
  }
}

/**
 * Wanduhrzeit eines Zeitpunkts in `zeitzone` als „Wand-Millisekunden“: die
 * lokalen Felder (Jahr, Monat, Tag, Stunde, …) so interpretiert, als wären sie
 * UTC. Damit lässt sich mit `Date.UTC`/`getUTC*` bequem in Tagen, Monaten und
 * Jahren rechnen.
 */
export function zuWandMs(zeitpunkt: Date, zeitzone: string): number {
  const teile = holeFormatter(zeitzone).formatToParts(zeitpunkt);
  const w: Record<string, number> = {};
  for (const t of teile) {
    if (t.type !== 'literal') w[t.type] = Number(t.value);
  }
  // Intl liefert für Mitternacht in manchen ICU-Fassungen „24“.
  const stunde = w.hour === 24 ? 0 : w.hour;
  const ms = zeitpunkt.getTime() % 1000;
  return Date.UTC(w.year, w.month - 1, w.day, stunde, w.minute, w.second) + (ms < 0 ? ms + 1000 : ms);
}

/** Zeitzonen-Versatz (Ortszeit minus UTC) in Millisekunden zu einem Zeitpunkt. */
export function versatzMs(zeitpunkt: Date, zeitzone: string): number {
  const t = zeitpunkt.getTime();
  const sekunde = t - (((t % 1000) + 1000) % 1000);
  return zuWandMs(new Date(sekunde), zeitzone) - sekunde;
}

/**
 * Wand-Millisekunden (siehe `zuWandMs`) zurück in einen echten Zeitpunkt.
 * Bei der Umstellung auf Sommerzeit nicht existierende Zeiten (z. B. 2:30 am
 * 2026-03-29) werden um den Sprung nach vorn verschoben; bei doppelten Zeiten
 * im Herbst gilt das erste Vorkommen (Sommerzeit).
 */
export function ausWandMs(wandMs: number, zeitzone: string): Date {
  const versatz1 = versatzMs(new Date(wandMs), zeitzone);
  const kandidat1 = wandMs - versatz1;
  const versatz2 = versatzMs(new Date(kandidat1), zeitzone);
  if (versatz2 === versatz1) {
    // Doppelte Stunde im Herbst: liegt eine Stunde früher dieselbe Wanduhrzeit
    // (Sommerzeit), gilt dieses frühere Vorkommen.
    const frueher = kandidat1 - 3_600_000;
    if (zuWandMs(new Date(frueher), zeitzone) === wandMs) return new Date(frueher);
    return new Date(kandidat1);
  }
  const kandidat2 = wandMs - versatz2;
  if (zuWandMs(new Date(kandidat2), zeitzone) === wandMs) {
    // Doppelte Stunde im Herbst: das frühere (Sommerzeit-)Vorkommen nehmen.
    if (zuWandMs(new Date(kandidat1), zeitzone) === wandMs) return new Date(Math.min(kandidat1, kandidat2));
    return new Date(kandidat2);
  }
  if (zuWandMs(new Date(kandidat1), zeitzone) === wandMs) return new Date(kandidat1);
  // Lücke (Zeit existiert nicht): um den Sprung nach vorn schieben.
  return new Date(wandMs - Math.min(versatz1, versatz2));
}

/** Lokales Datum 'JJJJ-MM-TT' eines Zeitpunkts in `zeitzone`. */
export function lokalesDatum(zeitpunkt: Date, zeitzone: string): string {
  return wandMsZuDatum(zuWandMs(zeitpunkt, zeitzone));
}

function wandMsZuDatum(wandMs: number): string {
  const d = new Date(wandMs);
  const j = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const t = String(d.getUTCDate()).padStart(2, '0');
  return `${j}-${m}-${t}`;
}

/** Wochentag 1 = Mo … 7 = So eines Wand-Zeitpunkts. */
function wochentag(wandMs: number): number {
  const w = new Date(wandMs).getUTCDay();
  return w === 0 ? 7 : w;
}

// ------------------------------------------------------------- Wiederholung

function normalisiereWiederholung(w: Wiederholung): Wiederholung {
  const intervall = Number.isFinite(w.intervall) ? Math.max(1, Math.floor(w.intervall)) : 1;
  const wochentage = [...new Set((w.wochentage ?? []).filter((t) => Number.isInteger(t) && t >= 1 && t <= 7))].sort(
    (a, b) => a - b,
  );
  const anzahl = w.anzahl != null && Number.isFinite(w.anzahl) && w.anzahl >= 1 ? Math.floor(w.anzahl) : null;
  return { ...w, intervall, wochentage, anzahl, ausnahmen: w.ausnahmen ?? [] };
}

/**
 * Erzeugt die Start-Wandzeiten der Serie in aufsteigender Reihenfolge, ohne
 * Rücksicht auf Ausnahmen, Anzahl oder Enddatum (das macht der Aufrufer).
 * Monatlich/jährlich: Tage, die es im Zielmonat nicht gibt (31., 29.2.),
 * werden übersprungen.
 */
function* rohVorkommen(startWand: number, w: Wiederholung): Generator<number> {
  const s = new Date(startWand);
  const jahr = s.getUTCFullYear();
  const monat = s.getUTCMonth();
  const tag = s.getUTCDate();
  const uhr = startWand - Date.UTC(jahr, monat, tag);

  switch (w.typ) {
    case 'taeglich':
      for (let n = 0; n < MAX_SCHRITTE; n++) yield startWand + n * w.intervall * MS_TAG;
      return;

    case 'woechentlich': {
      if (w.wochentage.length === 0) {
        for (let n = 0; n < MAX_SCHRITTE; n++) yield startWand + n * w.intervall * 7 * MS_TAG;
        return;
      }
      // Montag 0:00 der Startwoche (plus Uhrzeit) als Anker.
      const montag = startWand - (wochentag(startWand) - 1) * MS_TAG;
      for (let woche = 0; woche < MAX_SCHRITTE; woche++) {
        const basis = montag + woche * w.intervall * 7 * MS_TAG;
        for (const wt of w.wochentage) {
          const kandidat = basis + (wt - 1) * MS_TAG;
          if (kandidat >= startWand) yield kandidat;
        }
      }
      return;
    }

    case 'monatlich':
      for (let n = 0; n < MAX_SCHRITTE; n++) {
        const gesamt = monat + n * w.intervall;
        const j = jahr + Math.floor(gesamt / 12);
        const m = gesamt % 12;
        const kandidat = Date.UTC(j, m, tag) + uhr;
        if (new Date(kandidat).getUTCDate() !== tag) continue; // Tag gibt es nicht
        yield kandidat;
      }
      return;

    case 'jaehrlich':
      for (let n = 0; n < MAX_SCHRITTE; n++) {
        const kandidat = Date.UTC(jahr + n * w.intervall, monat, tag) + uhr;
        if (new Date(kandidat).getUTCDate() !== tag) continue; // 29.2. in Nicht-Schaltjahr
        yield kandidat;
      }
      return;
  }
}

function dauerAlsTage(termin: Termin): number {
  return Math.max(1, Math.round((termin.ende.getTime() - termin.start.getTime()) / MS_TAG));
}

function vorkommenAus(termin: Termin, startWand: number, zeitzone: string): Vorkommen {
  const start = ausWandMs(startWand, zeitzone);
  if (termin.ganztaegig) {
    return { start, ende: ausWandMs(startWand + dauerAlsTage(termin) * MS_TAG, zeitzone) };
  }
  const dauer = Math.max(0, termin.ende.getTime() - termin.start.getTime());
  return { start, ende: new Date(start.getTime() + dauer) };
}

/**
 * Alle Vorkommen des Termins in aufsteigender Reihenfolge (als Generator,
 * damit Aufrufer früh abbrechen können). Ausnahmen zählen bei `anzahl` mit
 * (wie EXDATE bei COUNT in RFC 5545), werden aber nicht geliefert.
 */
export function* alleVorkommen(termin: Termin): Generator<Vorkommen> {
  const zeitzone = gueltigeZeitzone(termin.zeitzone);
  if (!termin.wiederholung) {
    yield { start: termin.start, ende: termin.ende };
    return;
  }
  const w = normalisiereWiederholung(termin.wiederholung);
  const startWand = zuWandMs(termin.start, zeitzone);
  const ausnahmen = new Set(w.ausnahmen);
  const bisMs = w.bisDatum ? w.bisDatum.getTime() : null;
  const obergrenze = TERMIN_UNENDLICH.getTime();
  let gezaehlt = 0;
  let schritte = 0;
  for (const kandidatWand of rohVorkommen(startWand, w)) {
    if (++schritte > MAX_SCHRITTE) return;
    const v = vorkommenAus(termin, kandidatWand, zeitzone);
    if (v.start.getTime() >= obergrenze) return;
    if (bisMs !== null && v.start.getTime() > bisMs) return;
    gezaehlt++;
    if (w.anzahl !== null && gezaehlt > w.anzahl) return;
    if (ausnahmen.has(wandMsZuDatum(kandidatWand))) continue;
    yield v;
  }
}

/**
 * Vorkommen, die das Fenster [von, bis) überlappen (Start < bis und Ende > von;
 * bei Dauer 0 zählt Start >= von). Höchstens `maxAnzahl` Treffer.
 */
export function vorkommenImFenster(termin: Termin, von: Date, bis: Date, maxAnzahl = 1000): Vorkommen[] {
  const treffer: Vorkommen[] = [];
  const vonMs = von.getTime();
  const bisMs = bis.getTime();
  for (const v of alleVorkommen(termin)) {
    if (v.start.getTime() >= bisMs) break;
    const ueberlappt = v.ende.getTime() > vonMs || (v.ende.getTime() === v.start.getTime() && v.start.getTime() >= vonMs);
    if (!ueberlappt) continue;
    treffer.push(v);
    if (treffer.length >= maxAnzahl) break;
  }
  return treffer;
}

/** Ende des letzten Vorkommens; endlose Serien → 2200-01-01. */
export function sichtbarBis(termin: Termin): Date {
  if (!termin.wiederholung) return termin.ende;
  const w = normalisiereWiederholung(termin.wiederholung);
  if (w.bisDatum === null && w.anzahl === null) return TERMIN_UNENDLICH;
  let letztes: Date | null = null;
  let schritte = 0;
  for (const v of alleVorkommen(termin)) {
    letztes = v.ende;
    if (++schritte >= MAX_SCHRITTE) return TERMIN_UNENDLICH;
  }
  return letztes ?? termin.ende;
}

// -------------------------------------------------------------- Erinnerungen

function gueltigeMinuten(termin: Termin): number[] {
  return [...new Set((termin.erinnerungen ?? []).filter((m) => Number.isFinite(m) && m >= 0).map((m) => Math.floor(m)))]
    .sort((a, b) => a - b)
    .slice(0, 5);
}

export function erinnerungsSchluessel(vorkommenStart: Date, minuten: number): string {
  return `${vorkommenStart.toISOString()}|${minuten}`;
}

/**
 * Nächste Erinnerung, deren Zeitpunkt strikt nach `ab` liegt, oder null, wenn
 * keine mehr kommt. Bei gleichem Zeitpunkt gewinnt die kleinere Minutenzahl.
 */
export function naechsteErinnerung(termin: Termin, ab: Date): Erinnerung | null {
  const minuten = gueltigeMinuten(termin);
  if (minuten.length === 0) return null;
  const maxVorlauf = minuten[minuten.length - 1] * 60_000;
  const abMs = ab.getTime();
  let beste: Erinnerung | null = null;
  for (const v of alleVorkommen(termin)) {
    const startMs = v.start.getTime();
    // Alle weiteren Vorkommen liegen später; keine ihrer Erinnerungen kann vor
    // der besten liegen, sobald selbst der längste Vorlauf dahinter liegt.
    if (beste && startMs - maxVorlauf > beste.zeitpunkt.getTime()) break;
    if (startMs <= abMs) continue;
    for (const m of minuten) {
      const zeitpunkt = startMs - m * 60_000;
      if (zeitpunkt <= abMs) continue;
      if (!beste || zeitpunkt < beste.zeitpunkt.getTime() || (zeitpunkt === beste.zeitpunkt.getTime() && m < beste.minuten)) {
        beste = { zeitpunkt: new Date(zeitpunkt), vorkommenStart: v.start, minuten: m, schluessel: erinnerungsSchluessel(v.start, m) };
      }
    }
  }
  return beste;
}

// ----------------------------------------------------- Firestore-Umwandlung

interface TimestampArtig {
  toDate(): Date;
}

function istTimestamp(v: unknown): v is TimestampArtig {
  return typeof v === 'object' && v !== null && typeof (v as TimestampArtig).toDate === 'function';
}

/** Firestore-Timestamp, Date, ISO-String oder Millisekunden → Date (sonst null). */
export function alsDatum(v: unknown): Date | null {
  if (v == null) return null;
  if (v instanceof Date) return Number.isNaN(v.getTime()) ? null : v;
  if (istTimestamp(v)) return v.toDate();
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof v === 'number' && Number.isFinite(v)) return new Date(v);
  return null;
}

function alsText(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

function alsTextListe(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((e): e is string => typeof e === 'string') : [];
}

function alsZahlListe(v: unknown): number[] {
  return Array.isArray(v) ? v.map(Number).filter((n) => Number.isFinite(n)) : [];
}

export function wiederholungAusDaten(v: unknown): Wiederholung | null {
  if (typeof v !== 'object' || v === null) return null;
  const d = v as Record<string, unknown>;
  const typ = d.typ;
  if (typeof typ !== 'string' || !WIEDERHOLUNG_TYPEN.includes(typ as WiederholungTyp)) return null;
  const anzahl = typeof d.anzahl === 'number' && Number.isFinite(d.anzahl) ? d.anzahl : null;
  return normalisiereWiederholung({
    typ: typ as WiederholungTyp,
    intervall: typeof d.intervall === 'number' ? d.intervall : 1,
    wochentage: alsZahlListe(d.wochentage),
    bisDatum: alsDatum(d.bisDatum),
    anzahl,
    ausnahmen: alsTextListe(d.ausnahmen),
  });
}

/** Baut aus einem Firestore-Dokument (`termine/{id}`) einen `Termin`. */
export function terminAusDaten(id: string, daten: Record<string, unknown>): Termin | null {
  const start = alsDatum(daten.start);
  if (!start || typeof daten.listId !== 'string') return null;
  const ende = alsDatum(daten.ende) ?? start;
  return {
    id,
    listId: daten.listId,
    titel: alsText(daten.titel) ?? '',
    art: alsText(daten.art) ?? 'termin',
    personen: alsTextListe(daten.personen),
    start,
    ende: ende.getTime() < start.getTime() ? start : ende,
    ganztaegig: daten.ganztaegig === true,
    ort: alsText(daten.ort),
    notiz: alsText(daten.notiz),
    zeitzone: gueltigeZeitzone(daten.zeitzone),
    wiederholung: wiederholungAusDaten(daten.wiederholung),
    erinnerungen: alsZahlListe(daten.erinnerungen),
    erstelltVon: alsText(daten.erstelltVon) ?? '',
    erstelltAm: alsDatum(daten.erstelltAm),
    aktualisiertAm: alsDatum(daten.aktualisiertAm),
    sichtbarBis: alsDatum(daten.sichtbarBis),
    naechsteErinnerungAm: alsDatum(daten.naechsteErinnerungAm),
    letzteErinnerungSchluessel: alsText(daten.letzteErinnerungSchluessel),
  };
}

/** Die vom Termin betroffenen Mitglieder: `personen` oder alle der Liste. */
export function betroffenePersonen(termin: Termin, alleMitglieder: string[]): string[] {
  const basis = termin.personen.length > 0 ? termin.personen : alleMitglieder;
  return [...new Set(basis)];
}
