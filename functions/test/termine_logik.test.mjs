/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Unit-Tests der reinen Kalenderlogik (kein Emulator nötig):
//   cd functions && npm run build && npm run test:termine

import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import {
  alleVorkommen,
  vorkommenImFenster,
  naechsteErinnerung,
  sichtbarBis,
  terminAusDaten,
  zuWandMs,
  ausWandMs,
  lokalesDatum,
  versatzMs,
  TERMIN_UNENDLICH,
  betroffenePersonen,
} from '../lib/termine_logik.js';
import { icsFuerTermin, icsFalten, icsText } from '../lib/mail/ical.js';
import { erinnerungsMail, wochenueberblickMail, einladungsMail, einstellungsSeite } from '../lib/mail/vorlagen.js';
import { TEXTE, t, spracheVon, dauerText, zeitspanneText } from '../lib/mail/texte.js';
import { kommendeWoche } from '../lib/erinnerungen.js';
import { erlaubt, dokumentId } from '../lib/mail/ratenGrenze.js';

const TZ = 'Europe/Vienna';

/** Wanduhrzeit in Wien → UTC-Date. */
function wien(j, m, t, h = 0, mi = 0) {
  return ausWandMs(Date.UTC(j, m - 1, t, h, mi), TZ);
}

/** Lesbare Wiener Ortszeit „JJJJ-MM-TT HH:MM“ eines Zeitpunkts. */
function ort(d) {
  const w = new Date(zuWandMs(d, TZ));
  const p = (n) => String(n).padStart(2, '0');
  return `${w.getUTCFullYear()}-${p(w.getUTCMonth() + 1)}-${p(w.getUTCDate())} ${p(w.getUTCHours())}:${p(w.getUTCMinutes())}`;
}

function termin(extra = {}) {
  return {
    id: 'T1',
    listId: 'L1',
    titel: 'Zahnarzt',
    art: 'arzt',
    personen: [],
    start: wien(2026, 3, 16, 6, 0),
    ende: wien(2026, 3, 16, 7, 0),
    ganztaegig: false,
    ort: null,
    notiz: null,
    zeitzone: TZ,
    wiederholung: null,
    erinnerungen: [],
    anhaenge: [],
    erstelltVon: 'u1',
    erstelltAm: null,
    aktualisiertAm: null,
    sichtbarBis: null,
    naechsteErinnerungAm: null,
    letzteErinnerungSchluessel: null,
    ...extra,
  };
}

function regel(typ, extra = {}) {
  return { typ, intervall: 1, wochentage: [], bisDatum: null, anzahl: null, ausnahmen: [], ...extra };
}

const starts = (liste) => liste.map((v) => ort(v.start));

describe('Zeitzone', () => {
  test('Versatz Winter +1h, Sommer +2h', () => {
    assert.equal(versatzMs(new Date('2026-01-15T12:00:00Z'), TZ), 3_600_000);
    assert.equal(versatzMs(new Date('2026-07-15T12:00:00Z'), TZ), 7_200_000);
  });

  test('Wanduhr hin und zurück', () => {
    const d = wien(2026, 7, 1, 6, 0);
    assert.equal(d.toISOString(), '2026-07-01T04:00:00.000Z');
    assert.equal(ort(d), '2026-07-01 06:00');
    assert.equal(lokalesDatum(new Date('2026-07-01T22:30:00Z'), TZ), '2026-07-02');
  });

  test('Lücke 2026-03-29 2:30 wird nach vorn geschoben, doppelte Stunde im Herbst nimmt Sommerzeit', () => {
    assert.equal(ort(wien(2026, 3, 29, 2, 30)), '2026-03-29 03:30');
    // 2:30 am 2026-10-25 gibt es zweimal: 00:30Z (CEST) und 01:30Z (CET).
    assert.equal(wien(2026, 10, 25, 2, 30).toISOString(), '2026-10-25T00:30:00.000Z');
  });
});

describe('Expansion', () => {
  test('ohne Wiederholung genau ein Vorkommen im Fenster', () => {
    const tmn = termin();
    assert.equal(vorkommenImFenster(tmn, wien(2026, 3, 1), wien(2026, 4, 1)).length, 1);
    assert.equal(vorkommenImFenster(tmn, wien(2026, 4, 1), wien(2026, 5, 1)).length, 0);
    // Überlappung am Rand: Fenster endet mitten im Termin.
    assert.equal(vorkommenImFenster(tmn, wien(2026, 3, 16, 6, 30), wien(2026, 3, 17)).length, 1);
  });

  test('täglich über die Sommerzeit 2026-03-29: 6:00 bleibt 6:00', () => {
    const tmn = termin({ wiederholung: regel('taeglich'), start: wien(2026, 3, 27, 6), ende: wien(2026, 3, 27, 7) });
    const v = vorkommenImFenster(tmn, wien(2026, 3, 27), wien(2026, 3, 31));
    assert.deepEqual(starts(v), ['2026-03-27 06:00', '2026-03-28 06:00', '2026-03-29 06:00', '2026-03-30 06:00']);
    assert.equal(v[1].start.toISOString(), '2026-03-28T05:00:00.000Z');
    assert.equal(v[2].start.toISOString(), '2026-03-29T04:00:00.000Z');
    // Dauer bleibt eine Stunde.
    assert.equal(v[2].ende.getTime() - v[2].start.getTime(), 3_600_000);
  });

  test('täglich über das Ende der Sommerzeit 2026-10-25', () => {
    const tmn = termin({ wiederholung: regel('taeglich'), start: wien(2026, 10, 24, 6), ende: wien(2026, 10, 24, 6, 30) });
    const v = vorkommenImFenster(tmn, wien(2026, 10, 24), wien(2026, 10, 27));
    assert.deepEqual(starts(v), ['2026-10-24 06:00', '2026-10-25 06:00', '2026-10-26 06:00']);
    assert.equal(v[0].start.toISOString(), '2026-10-24T04:00:00.000Z');
    assert.equal(v[1].start.toISOString(), '2026-10-25T05:00:00.000Z');
  });

  test('täglich mit Intervall 3 und Anzahl 4', () => {
    const tmn = termin({ wiederholung: regel('taeglich', { intervall: 3, anzahl: 4 }) });
    const v = [...alleVorkommen(tmn)];
    assert.deepEqual(starts(v), ['2026-03-16 06:00', '2026-03-19 06:00', '2026-03-22 06:00', '2026-03-25 06:00']);
  });

  test('wöchentlich Mo–Fr, Start an einem Mittwoch', () => {
    // 2026-03-18 ist ein Mittwoch.
    const tmn = termin({
      start: wien(2026, 3, 18, 8),
      ende: wien(2026, 3, 18, 8, 15),
      wiederholung: regel('woechentlich', { wochentage: [1, 2, 3, 4, 5] }),
    });
    const v = vorkommenImFenster(tmn, wien(2026, 3, 16), wien(2026, 3, 25));
    assert.deepEqual(starts(v), [
      '2026-03-18 08:00',
      '2026-03-19 08:00',
      '2026-03-20 08:00',
      '2026-03-23 08:00',
      '2026-03-24 08:00',
    ]);
  });

  test('alle zwei Wochen Sa+So', () => {
    // 2026-03-21 Samstag.
    const tmn = termin({
      start: wien(2026, 3, 21, 10),
      ende: wien(2026, 3, 21, 11),
      wiederholung: regel('woechentlich', { intervall: 2, wochentage: [6, 7] }),
    });
    const v = vorkommenImFenster(tmn, wien(2026, 3, 1), wien(2026, 4, 10));
    assert.deepEqual(starts(v), ['2026-03-21 10:00', '2026-03-22 10:00', '2026-04-04 10:00', '2026-04-05 10:00']);
  });

  test('wöchentlich ohne Wochentage = jede Woche am Starttag', () => {
    const tmn = termin({ wiederholung: regel('woechentlich', { anzahl: 3 }) });
    assert.deepEqual(starts([...alleVorkommen(tmn)]), ['2026-03-16 06:00', '2026-03-23 06:00', '2026-03-30 06:00']);
  });

  test('monatlich am 31. überspringt kurze Monate', () => {
    const tmn = termin({
      start: wien(2026, 1, 31, 9),
      ende: wien(2026, 1, 31, 10),
      wiederholung: regel('monatlich', { anzahl: 4 }),
    });
    assert.deepEqual(starts([...alleVorkommen(tmn)]), ['2026-01-31 09:00', '2026-03-31 09:00', '2026-05-31 09:00', '2026-07-31 09:00']);
  });

  test('monatlich Intervall 2 mit bisDatum einschließlich', () => {
    const tmn = termin({
      start: wien(2026, 1, 15, 9),
      ende: wien(2026, 1, 15, 10),
      wiederholung: regel('monatlich', { intervall: 2, bisDatum: wien(2026, 5, 15, 9) }),
    });
    assert.deepEqual(starts([...alleVorkommen(tmn)]), ['2026-01-15 09:00', '2026-03-15 09:00', '2026-05-15 09:00']);
  });

  test('jährlich (Geburtstag, ganztägig) inkl. 29.2.', () => {
    const tmn = termin({
      titel: 'Geburtstag',
      ganztaegig: true,
      start: wien(2024, 2, 29),
      ende: wien(2024, 3, 1),
      wiederholung: regel('jaehrlich', { anzahl: 3 }),
    });
    const v = [...alleVorkommen(tmn)];
    assert.deepEqual(starts(v), ['2024-02-29 00:00', '2028-02-29 00:00', '2032-02-29 00:00']);
    assert.equal(ort(v[1].ende), '2028-03-01 00:00');
  });

  test('ganztägig mehrtägig bleibt auf Tagesgrenzen über die Zeitumstellung', () => {
    const tmn = termin({
      titel: 'Urlaub',
      art: 'urlaub',
      ganztaegig: true,
      start: wien(2026, 3, 27),
      ende: wien(2026, 3, 30), // 3 Tage
      wiederholung: regel('woechentlich', { anzahl: 2 }),
    });
    const v = [...alleVorkommen(tmn)];
    assert.equal(ort(v[0].ende), '2026-03-30 00:00');
    assert.equal(ort(v[1].start), '2026-04-03 00:00');
    assert.equal(ort(v[1].ende), '2026-04-06 00:00');
  });

  test('Ausnahmen werden übersprungen und zählen bei anzahl mit', () => {
    const tmn = termin({ wiederholung: regel('taeglich', { anzahl: 4, ausnahmen: ['2026-03-17'] }) });
    assert.deepEqual(starts([...alleVorkommen(tmn)]), ['2026-03-16 06:00', '2026-03-18 06:00', '2026-03-19 06:00']);
  });

  test('Fensterbegrenzung bei endloser Serie', () => {
    const tmn = termin({ wiederholung: regel('taeglich') });
    const v = vorkommenImFenster(tmn, wien(2030, 1, 1), wien(2030, 1, 8));
    assert.equal(v.length, 7);
    assert.equal(ort(v[0].start), '2030-01-01 06:00');
    assert.equal(vorkommenImFenster(tmn, wien(2030, 1, 1), wien(2031, 1, 1), 10).length, 10);
  });
});

describe('sichtbarBis', () => {
  test('einzeln = Ende, endlos = 2200, bisDatum/anzahl = Ende des letzten Vorkommens', () => {
    assert.equal(sichtbarBis(termin()).toISOString(), wien(2026, 3, 16, 7).toISOString());
    assert.equal(sichtbarBis(termin({ wiederholung: regel('taeglich') })).getTime(), TERMIN_UNENDLICH.getTime());
    assert.equal(ort(sichtbarBis(termin({ wiederholung: regel('taeglich', { anzahl: 3 }) }))), '2026-03-18 07:00');
    assert.equal(ort(sichtbarBis(termin({ wiederholung: regel('woechentlich', { bisDatum: wien(2026, 4, 1) }) }))), '2026-03-30 07:00');
  });
});

describe('naechsteErinnerung', () => {
  test('einzelner Termin mit 15 Minuten und 1 Tag', () => {
    const tmn = termin({ erinnerungen: [15, 1440] });
    const e1 = naechsteErinnerung(tmn, wien(2026, 3, 1));
    assert.equal(ort(e1.zeitpunkt), '2026-03-15 06:00');
    assert.equal(e1.minuten, 1440);
    assert.equal(e1.schluessel, `${wien(2026, 3, 16, 6).toISOString()}|1440`);
    const e2 = naechsteErinnerung(tmn, e1.zeitpunkt); // strikt danach
    assert.equal(ort(e2.zeitpunkt), '2026-03-16 05:45');
    assert.equal(e2.minuten, 15);
    assert.equal(naechsteErinnerung(tmn, e2.zeitpunkt), null);
  });

  test('ohne Erinnerungen null; 0 Minuten = zum Start', () => {
    assert.equal(naechsteErinnerung(termin(), wien(2026, 1, 1)), null);
    const e = naechsteErinnerung(termin({ erinnerungen: [0] }), wien(2026, 1, 1));
    assert.equal(e.zeitpunkt.getTime(), wien(2026, 3, 16, 6).getTime());
    assert.equal(e.minuten, 0);
  });

  test('Serie: Vorlauf über mehrere Vorkommen, früheste gewinnt', () => {
    // Täglich 6:00, Erinnerungen 0 und 2 Tage. Ab 2026-03-16 05:00:
    // 16.3. 0-Min → 16.3. 06:00; 18.3. 2-Tage → 16.3. 06:00 (gleich, kleinere Minuten gewinnen).
    const tmn = termin({ wiederholung: regel('taeglich'), erinnerungen: [0, 2880] });
    const e = naechsteErinnerung(tmn, wien(2026, 3, 16, 5));
    assert.equal(ort(e.zeitpunkt), '2026-03-16 06:00');
    assert.equal(e.minuten, 0);
    // Ab 16.3. 06:00 → 17.3. 06:00 (0-Min des 17.3.).
    const e2 = naechsteErinnerung(tmn, e.zeitpunkt);
    assert.equal(ort(e2.zeitpunkt), '2026-03-17 06:00');
  });

  test('Serie über die Sommerzeit: Erinnerung folgt der Ortszeit', () => {
    const tmn = termin({
      wiederholung: regel('taeglich'),
      erinnerungen: [30],
      start: wien(2026, 3, 28, 6),
      ende: wien(2026, 3, 28, 7),
    });
    const e = naechsteErinnerung(tmn, wien(2026, 3, 28, 6));
    assert.equal(ort(e.zeitpunkt), '2026-03-29 05:30');
    assert.equal(e.zeitpunkt.toISOString(), '2026-03-29T03:30:00.000Z');
  });

  test('Serie mit Ende liefert null nach dem letzten Vorkommen', () => {
    const tmn = termin({ wiederholung: regel('taeglich', { anzahl: 2 }), erinnerungen: [10] });
    assert.equal(naechsteErinnerung(tmn, wien(2026, 3, 17, 6)), null);
  });
});

describe('terminAusDaten', () => {
  test('wandelt Firestore-ähnliche Daten um und verwirft Unbrauchbares', () => {
    const ts = (d) => ({ toDate: () => d });
    const tmn = terminAusDaten('X', {
      listId: 'L',
      titel: 'Test',
      start: ts(wien(2026, 5, 1, 9)),
      ende: ts(wien(2026, 5, 1, 10)),
      zeitzone: 'Mars/Olympus',
      wiederholung: { typ: 'woechentlich', intervall: 0, wochentage: [1, 9, 5], anzahl: 2.7 },
      erinnerungen: [5, 'x'],
      personen: ['a', 3],
    });
    assert.equal(tmn.zeitzone, TZ);
    assert.equal(tmn.wiederholung.intervall, 1);
    assert.deepEqual(tmn.wiederholung.wochentage, [1, 5]);
    assert.equal(tmn.wiederholung.anzahl, 2);
    assert.deepEqual(tmn.erinnerungen, [5]);
    assert.deepEqual(tmn.personen, ['a']);
    assert.equal(terminAusDaten('Y', { titel: 'ohne start' }), null);
    assert.deepEqual(betroffenePersonen(tmn, ['a', 'b']), ['a']);
    assert.deepEqual(betroffenePersonen({ ...tmn, personen: [] }, ['a', 'b', 'a']), ['a', 'b']);
  });
});

describe('iCalendar', () => {
  test('Einzeltermin als UTC mit Escaping', () => {
    const tmn = termin({ ort: 'Praxis Dr. Huber; 1. Stock', notiz: 'Karte, Überweisung\nmitnehmen' });
    const ics = icsFuerTermin(tmn, { jetzt: new Date('2026-03-01T10:00:00Z'), personenNamen: ['Anna', 'Ben'] });
    assert.ok(ics.startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
    assert.ok(ics.includes('DTSTART:20260316T050000Z\r\n'));
    assert.ok(ics.includes('DTEND:20260316T060000Z\r\n'));
    assert.ok(ics.includes('UID:T1@togetherdo.seebubble.me\r\n'));
    assert.ok(ics.includes('SUMMARY:Zahnarzt\r\n'));
    assert.ok(ics.includes('LOCATION:Praxis Dr. Huber\\; 1. Stock\r\n'));
    assert.ok(ics.includes('DESCRIPTION:Karte\\, Überweisung\\nmitnehmen\\n\\nAnna\\, Ben\r\n'));
    assert.ok(ics.includes('DTSTAMP:20260301T100000Z\r\n'));
    assert.ok(!ics.includes('RRULE'));
    assert.ok(ics.endsWith('END:VEVENT\r\nEND:VCALENDAR\r\n'));
  });

  test('Serie mit RRULE, EXDATE und UNTIL; einzelnes Vorkommen ohne RRULE', () => {
    const tmn = termin({
      wiederholung: regel('woechentlich', { intervall: 2, wochentage: [1, 3], bisDatum: wien(2026, 6, 30, 23, 59), ausnahmen: ['2026-03-30'] }),
    });
    const ics = icsFuerTermin(tmn);
    assert.ok(ics.includes('RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20260630T215900Z\r\n'));
    assert.ok(ics.includes('EXDATE:20260330T040000Z\r\n'));
    const einzeln = icsFuerTermin(tmn, { vorkommen: { start: wien(2026, 3, 30, 6), ende: wien(2026, 3, 30, 7) } });
    assert.ok(!einzeln.includes('RRULE'));
    assert.ok(einzeln.includes('DTSTART:20260330T040000Z\r\n'));
    assert.ok(einzeln.includes('UID:T1-20260330T040000Z@togetherdo.seebubble.me\r\n'));
    const anzahl = icsFuerTermin(termin({ wiederholung: regel('taeglich', { anzahl: 5 }) }));
    assert.ok(anzahl.includes('RRULE:FREQ=DAILY;COUNT=5\r\n'));
  });

  test('ganztägig als VALUE=DATE', () => {
    const tmn = termin({ ganztaegig: true, start: wien(2026, 12, 24), ende: wien(2026, 12, 27) });
    const ics = icsFuerTermin(tmn);
    assert.ok(ics.includes('DTSTART;VALUE=DATE:20261224\r\n'));
    assert.ok(ics.includes('DTEND;VALUE=DATE:20261227\r\n'));
  });

  test('Zeilenfaltung auf 75 Oktette, UTF-8-sicher', () => {
    const lang = 'SUMMARY:' + 'ä'.repeat(100);
    const gefaltet = icsFalten(lang);
    const zeilen = gefaltet.split('\r\n');
    assert.ok(zeilen.length > 1);
    for (const z of zeilen) assert.ok(Buffer.byteLength(z, 'utf8') <= 75, `Zeile zu lang: ${Buffer.byteLength(z)}`);
    for (const z of zeilen.slice(1)) assert.ok(z.startsWith(' '));
    assert.equal(gefaltet.replace(/\r\n /g, ''), lang);
    assert.equal(icsText('a\\b;c,d\ne'), 'a\\\\b\\;c\\,d\\ne');
  });
});

describe('Texte', () => {
  test('alle Schlüssel in de und en mit gleichen Platzhaltern', () => {
    for (const [schluessel, werte] of Object.entries(TEXTE)) {
      assert.ok(werte.de, `${schluessel} ohne de`);
      assert.ok(werte.en, `${schluessel} ohne en`);
      const ph = (s) => [...s.matchAll(/\{([a-zA-Z_]+)\}/g)].map((m) => m[1]).sort();
      assert.deepEqual(ph(werte.de), ph(werte.en), `${schluessel}: Platzhalter unterschiedlich`);
    }
  });

  test('Sprachwahl und Einsetzen', () => {
    assert.equal(spracheVon('en-US'), 'en');
    assert.equal(spracheVon('de'), 'de');
    assert.equal(spracheVon('fr'), 'de');
    assert.equal(spracheVon(undefined), 'de');
    assert.equal(t('en', 'einladung.code'), 'Your join code');
    assert.equal(t('de', 'erinnerung.in', { dauer: dauerText('de', 90) }), 'Dein Termin beginnt in 90 Minuten.');
    assert.equal(dauerText('en', 120), '2 hours');
    assert.equal(dauerText('de', 1440), '1 Tag');
    assert.equal(dauerText('de', 10080), '1 Woche');
  });

  test('Zeitspanne mit Ortszeit', () => {
    const s = zeitspanneText('de', wien(2026, 3, 29, 6), wien(2026, 3, 29, 7, 30), false, TZ);
    assert.match(s, /29\. März 2026, 06:00–07:30$/);
    const g = zeitspanneText('en', wien(2026, 12, 24), wien(2026, 12, 27), true, TZ);
    assert.match(g, /24 December 2026 – .*26 December 2026, all day$/);
  });
});

describe('Vorlagen', () => {
  const fuss = {
    einstellungen: 'https://example.test/mailEinstellungen?uid=u1&token=abc&aktion=abmelden',
    abmelden: { url: 'https://example.test/mailEinstellungen?uid=u1&token=abc&aktion=abmelden', schluessel: 'fuss.abmelden' },
  };

  test('Erinnerungs-Mail: Inhalt, Maskierung, keine Adresse, Fußzeile', () => {
    const tmn = termin({ titel: 'Zahnarzt <Kinder>', ort: 'Praxis & Co', notiz: 'Karte mitnehmen' });
    for (const sprache of ['de', 'en']) {
      const m = erinnerungsMail({
        sprache,
        empfaengerName: 'Anna',
        termin: tmn,
        vorkommen: { start: tmn.start, ende: tmn.ende },
        minuten: 15,
        listenName: 'Familie',
        personenNamen: ['Anna', 'Ben'],
        fuss,
      });
      assert.ok(m.betreff.includes('Zahnarzt <Kinder>'));
      assert.ok(m.html.includes('Zahnarzt &lt;Kinder&gt;'));
      assert.ok(!m.html.includes('<Kinder>'));
      assert.ok(m.html.includes('Praxis &amp; Co'));
      assert.ok(m.html.includes('#5B4BD6'));
      assert.ok(m.html.includes('Anna, Ben'));
      assert.ok(m.html.includes('Familie'));
      assert.ok(m.html.includes(fuss.abmelden.url.replace(/&/g, '&amp;')));
      assert.ok(m.text.includes('Karte mitnehmen'));
      assert.ok(m.text.includes(fuss.einstellungen));
      assert.ok(!/@[a-z0-9.-]+\.[a-z]{2,}/i.test(m.html.replace(/togetherdo\.seebubble\.me/g, '')), 'keine E-Mail-Adresse im HTML');
      assert.ok(!/@/.test(m.text), 'keine E-Mail-Adresse im Text');
      assert.ok(m.html.includes('viewport'));
    }
    const de = erinnerungsMail({ sprache: 'de', empfaengerName: '', termin: tmn, vorkommen: { start: tmn.start, ende: tmn.ende }, minuten: 0, listenName: 'F', personenNamen: [], fuss });
    assert.ok(de.html.includes('Hallo,'));
    assert.ok(de.html.includes('Dein Termin beginnt jetzt.'));
    assert.ok(de.html.includes('Alle in der Liste'));
  });

  test('Wochenüberblick gruppiert nach Tag', () => {
    const a = termin({ titel: 'Schule', start: wien(2026, 3, 16, 8), ende: wien(2026, 3, 16, 12) });
    const b = termin({ id: 'T2', titel: 'Yoga', start: wien(2026, 3, 16, 18), ende: wien(2026, 3, 16, 19) });
    const c = termin({ id: 'T3', titel: 'Oma', ganztaegig: true, start: wien(2026, 3, 18), ende: wien(2026, 3, 19) });
    const m = wochenueberblickMail({
      sprache: 'de',
      empfaengerName: 'Anna',
      zeitzone: TZ,
      wochenStart: wien(2026, 3, 16),
      wochenEnde: wien(2026, 3, 23),
      eintraege: [
        { termin: c, vorkommen: { start: c.start, ende: c.ende }, listenName: 'Familie', personenNamen: [] },
        { termin: b, vorkommen: { start: b.start, ende: b.ende }, listenName: 'Familie', personenNamen: ['Anna'] },
        { termin: a, vorkommen: { start: a.start, ende: a.ende }, listenName: 'Familie', personenNamen: ['Kind'] },
      ],
      fuss: { ...fuss, abmelden: { url: fuss.abmelden.url, schluessel: 'fuss.wochenueberblick.abmelden' } },
    });
    assert.equal(m.betreff, 'Eure Woche: 16. März – 22. März');
    assert.ok(m.text.indexOf('Schule') < m.text.indexOf('Yoga'));
    assert.ok(m.text.indexOf('Yoga') < m.text.indexOf('Oma'));
    assert.ok(m.html.includes('3 Termine'));
    assert.ok(m.html.includes('ganztägig'));
    assert.ok(m.html.includes('Wochenüberblick abbestellen'));
    const leer = wochenueberblickMail({ sprache: 'en', empfaengerName: '', zeitzone: TZ, wochenStart: wien(2026, 3, 16), wochenEnde: wien(2026, 3, 23), eintraege: [], fuss });
    assert.ok(leer.html.includes('No events'));
  });

  test('Einladungs-Mail mit Code und Listenname', () => {
    const m = einladungsMail({ sprache: 'en', einladerName: 'Olga', listenName: 'Haushalt', shareCode: '123456', fuss: { einstellungen: 'https://seebubble.me/togetherdo' } });
    assert.equal(m.betreff, 'Olga invited you to the list “Haushalt”');
    assert.ok(m.html.includes('123456'));
    assert.ok(m.text.includes('Your join code: 123456'));
    assert.ok(!/@/.test(m.text));
  });

  test('Einstellungsseite de/en', () => {
    assert.ok(einstellungsSeite('de', 'Erledigt.', true).includes('<html lang="de">'));
    assert.ok(einstellungsSeite('en', 'Done.', false).includes('Email settings'));
  });
});

describe('Woche und Ratenbegrenzung', () => {
  test('kommendeWoche: Sonntag 18:00 → Montag 0:00 bis Montag 0:00', () => {
    const w = kommendeWoche(wien(2026, 3, 22, 18), TZ); // Sonntag
    assert.equal(ort(w.start), '2026-03-23 00:00');
    assert.equal(ort(w.ende), '2026-03-30 00:00');
    // Woche mit Zeitumstellung: Ende trotzdem Mitternacht Ortszeit.
    const w2 = kommendeWoche(wien(2026, 3, 25, 12), TZ); // Mittwoch → nächster Montag 30.3.
    assert.equal(ort(w2.start), '2026-03-30 00:00');
    assert.equal(ort(w2.ende), '2026-04-06 00:00');
    assert.equal(w2.ende.getTime() - w2.start.getTime(), 7 * 24 * 3_600_000);
  });

  test('erlaubt und Hash-ID', () => {
    const jetzt = 1_000_000;
    assert.equal(erlaubt([], jetzt, [{ fensterMs: 1000, max: 1 }]), true);
    assert.equal(erlaubt([jetzt - 500], jetzt, [{ fensterMs: 1000, max: 1 }]), false);
    assert.equal(erlaubt([jetzt - 1500], jetzt, [{ fensterMs: 1000, max: 1 }]), true);
    assert.match(dokumentId('einladung_adresse', 'Max@Example.test'), /^[0-9a-f]{64}$/);
    assert.equal(dokumentId('a', 'X@y.z'), dokumentId('a', ' x@y.z '));
    assert.ok(!dokumentId('a', 'x@y.z').includes('@'));
  });
});
