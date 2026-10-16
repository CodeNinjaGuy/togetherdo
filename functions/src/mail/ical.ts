/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// iCalendar-Ausgabe (RFC 5545) für einen Termin oder ein einzelnes Vorkommen.
//
// Zeiten stehen als UTC („…Z“), damit keine VTIMEZONE-Definition nötig ist.
// Ganztägige Termine als VALUE=DATE (lokale Tage in der Zeitzone des Termins).
// Serien bekommen eine RRULE; zu beachten: Bei UTC-Zeiten wandert eine
// 6:00-Serie für Kalender-Clients über die Sommerzeit um eine Stunde. Für die
// Erinnerungs-Mail wird darum nur das konkrete Vorkommen angehängt.

import { Termin, Vorkommen, lokalesDatum, alleVorkommen, zuWandMs, ausWandMs } from '../termine_logik';

const WOCHENTAGE = ['', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const FREQ: Record<string, string> = {
  taeglich: 'DAILY',
  woechentlich: 'WEEKLY',
  monatlich: 'MONTHLY',
  jaehrlich: 'YEARLY',
};

export interface IcsOptionen {
  /** Nur dieses Vorkommen als Einzeltermin ausgeben (keine RRULE). */
  vorkommen?: Vorkommen;
  /** Namen der betroffenen Personen für die Beschreibung. */
  personenNamen?: string[];
  /** Zeitstempel der Erzeugung (Tests). */
  jetzt?: Date;
  /** Kennung der Quelle, Standard „togetherdo.seebubble.me“. */
  domain?: string;
}

/** TEXT-Escaping nach RFC 5545 §3.3.11. */
export function icsText(wert: string): string {
  return wert
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r\n|\r|\n/g, '\\n');
}

/** Zeilenfaltung auf 75 Oktette (RFC 5545 §3.1), UTF-8-sicher. */
export function icsFalten(zeile: string): string {
  const enc = new TextEncoder();
  const ergebnis: string[] = [];
  let aktuell = '';
  let aktuellBytes = 0;
  let grenze = 75;
  for (const zeichen of zeile) {
    const b = enc.encode(zeichen).length;
    if (aktuellBytes + b > grenze) {
      ergebnis.push(aktuell);
      aktuell = ' ';
      aktuellBytes = 1;
      grenze = 75;
    }
    aktuell += zeichen;
    aktuellBytes += b;
  }
  ergebnis.push(aktuell);
  return ergebnis.join('\r\n');
}

/** UTC-Zeitstempel „20260329T050000Z“. */
export function icsUtc(zeitpunkt: Date): string {
  return zeitpunkt.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

/** Datum „20260329“ in der Zeitzone. */
export function icsDatum(zeitpunkt: Date, zeitzone: string): string {
  return lokalesDatum(zeitpunkt, zeitzone).replace(/-/g, '');
}

function rrule(termin: Termin): string | null {
  const w = termin.wiederholung;
  if (!w) return null;
  const teile = [`FREQ=${FREQ[w.typ]}`];
  if (w.intervall > 1) teile.push(`INTERVAL=${w.intervall}`);
  if (w.typ === 'woechentlich' && w.wochentage.length > 0) {
    teile.push(`BYDAY=${w.wochentage.map((d) => WOCHENTAGE[d]).join(',')}`);
  }
  if (w.anzahl !== null) teile.push(`COUNT=${w.anzahl}`);
  else if (w.bisDatum) {
    teile.push(`UNTIL=${termin.ganztaegig ? icsDatum(w.bisDatum, termin.zeitzone) : icsUtc(w.bisDatum)}`);
  }
  return teile.join(';');
}

/** EXDATE-Zeitpunkte: die Ausnahme-Tage mit der Uhrzeit des Serienstarts. */
function exdates(termin: Termin): string[] {
  const w = termin.wiederholung;
  if (!w || w.ausnahmen.length === 0) return [];
  const startWand = zuWandMs(termin.start, termin.zeitzone);
  const uhr = startWand - Date.UTC(new Date(startWand).getUTCFullYear(), new Date(startWand).getUTCMonth(), new Date(startWand).getUTCDate());
  return w.ausnahmen
    .filter((a) => /^\d{4}-\d{2}-\d{2}$/.test(a))
    .map((a) => {
      if (termin.ganztaegig) return a.replace(/-/g, '');
      const [j, m, t] = a.split('-').map(Number);
      return icsUtc(ausWandMs(Date.UTC(j, m - 1, t) + uhr, termin.zeitzone));
    });
}

/** Baut die .ics-Datei (eine VEVENT) als Zeichenkette mit CRLF-Zeilen. */
export function icsFuerTermin(termin: Termin, optionen: IcsOptionen = {}): string {
  const jetzt = optionen.jetzt ?? new Date();
  const domain = optionen.domain ?? 'togetherdo.seebubble.me';
  const einzeln = optionen.vorkommen;
  const start = einzeln ? einzeln.start : termin.start;
  const ende = einzeln ? einzeln.ende : termin.ende;
  const uid = einzeln && termin.wiederholung ? `${termin.id}-${icsUtc(start)}@${domain}` : `${termin.id}@${domain}`;

  const zeilen: string[] = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//SeeBubble Media FlexCo//ToGetherDo//DE',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${uid}`,
    `DTSTAMP:${icsUtc(jetzt)}`,
  ];
  if (termin.ganztaegig) {
    zeilen.push(`DTSTART;VALUE=DATE:${icsDatum(start, termin.zeitzone)}`);
    const endTag = ende.getTime() > start.getTime() ? ende : new Date(start.getTime() + 24 * 60 * 60 * 1000);
    zeilen.push(`DTEND;VALUE=DATE:${icsDatum(endTag, termin.zeitzone)}`);
  } else {
    zeilen.push(`DTSTART:${icsUtc(start)}`);
    zeilen.push(`DTEND:${icsUtc(ende.getTime() > start.getTime() ? ende : start)}`);
  }
  if (!einzeln) {
    const regel = rrule(termin);
    if (regel) zeilen.push(`RRULE:${regel}`);
    for (const ex of exdates(termin)) {
      zeilen.push(termin.ganztaegig ? `EXDATE;VALUE=DATE:${ex}` : `EXDATE:${ex}`);
    }
  }
  zeilen.push(`SUMMARY:${icsText(termin.titel || 'Termin')}`);
  if (termin.ort) zeilen.push(`LOCATION:${icsText(termin.ort)}`);
  const beschreibung: string[] = [];
  if (termin.notiz) beschreibung.push(termin.notiz);
  if (optionen.personenNamen && optionen.personenNamen.length > 0) {
    beschreibung.push(optionen.personenNamen.join(', '));
  }
  if (beschreibung.length > 0) zeilen.push(`DESCRIPTION:${icsText(beschreibung.join('\n\n'))}`);
  zeilen.push(`CATEGORIES:${icsText(termin.art)}`);
  zeilen.push(termin.ganztaegig ? 'TRANSP:TRANSPARENT' : 'TRANSP:OPAQUE');
  zeilen.push('END:VEVENT', 'END:VCALENDAR');
  return zeilen.map(icsFalten).join('\r\n') + '\r\n';
}

/** Erstes Vorkommen eines Termins (für Tests und Vorschauen). */
export function erstesVorkommen(termin: Termin): Vorkommen | null {
  for (const v of alleVorkommen(termin)) return v;
  return null;
}
