/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Unit-Tests des Monatsüberblicks (reine Logik und Vorlage, kein Emulator):
//   cd functions && npm run build && node --test test/monatsueberblick.test.mjs

import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { ausWandMs } from '../lib/termine_logik.js';
import {
  monatsFenster,
  tageDesVorkommens,
  tageImFenster,
  zeitraeumeAus,
  monatsueberblickBerechnen,
} from '../lib/monatsueberblick_logik.js';
import { monatsueberblickMail } from '../lib/mail/vorlagen.js';
import { TEXTE, t, monatText, tagText } from '../lib/mail/texte.js';

const TZ = 'Europe/Vienna';
const STD = 60 * 60 * 1000;
const TAG = 24 * STD;

/** Wanduhrzeit in Wien → UTC-Date. */
function wien(j, m, t, h = 0, mi = 0) {
  return ausWandMs(Date.UTC(j, m - 1, t, h, mi), TZ);
}

let zaehler = 0;
function termin(extra = {}) {
  return {
    id: `T${++zaehler}`,
    listId: 'L1',
    titel: 'Termin',
    art: 'termin',
    personen: [],
    start: wien(2026, 6, 4, 10, 0),
    ende: wien(2026, 6, 4, 11, 0),
    ganztaegig: false,
    ort: null,
    notiz: null,
    zeitzone: TZ,
    wiederholung: null,
    erinnerungen: [],
    erstelltVon: 'anna',
    erstelltAm: null,
    aktualisiertAm: null,
    sichtbarBis: null,
    naechsteErinnerungAm: null,
    letzteErinnerungSchluessel: null,
    ...extra,
  };
}

/** Ganztägiger Termin vom ersten bis zum letzten Tag (einschließlich). */
function ganztag(vonTag, bisTag, extra = {}) {
  const [j1, m1, t1] = vonTag.split('-').map(Number);
  const [j2, m2, t2] = bisTag.split('-').map(Number);
  return termin({ ganztaegig: true, start: wien(j1, m1, t1), ende: new Date(wien(j2, m2, t2).getTime() + TAG), ...extra });
}

const NAMEN = { anna: 'Anna', ben: 'Ben', cleo: 'Cleo' };
const optionen = { zeitzone: TZ, nameVon: (uid) => NAMEN[uid] ?? '' };
const juni = monatsFenster(wien(2026, 6, 1, 7, 0), TZ);

/** Arbeitsserie Mo–Fr 08:00–16:00 seit Jänner, nur Ben. */
const arbeitBen = termin({
  titel: 'Arbeit',
  art: 'arbeit',
  personen: ['ben'],
  start: wien(2026, 1, 5, 8, 0),
  ende: wien(2026, 1, 5, 16, 0),
  wiederholung: { typ: 'woechentlich', intervall: 1, wochentage: [1, 2, 3, 4, 5], bisDatum: null, anzahl: null, ausnahmen: [] },
});

describe('Zeitfenster und Tage', () => {
  test('monatsFenster: 1. 0:00 bis 1. des Folgemonats 0:00 (Wien)', () => {
    assert.equal(juni.start.toISOString(), '2026-05-31T22:00:00.000Z');
    assert.equal(juni.ende.toISOString(), '2026-06-30T22:00:00.000Z');
    const dez = monatsFenster(wien(2026, 12, 1, 7, 0), TZ);
    assert.equal(dez.start.toISOString(), '2026-11-30T23:00:00.000Z');
    assert.equal(dez.ende.toISOString(), '2026-12-31T23:00:00.000Z');
    assert.equal(tageImFenster(juni, TZ).length, 30);
    assert.equal(tageImFenster(juni, TZ)[0], '2026-06-01');
    assert.equal(tageImFenster(juni, TZ)[29], '2026-06-30');
  });

  test('tageDesVorkommens: Mitternacht, Dauer 0, ganztägig, Beschnitt am Monatsrand', () => {
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 6, 4, 23, 30), ende: wien(2026, 6, 5, 0, 30) }, TZ, juni), ['2026-06-04', '2026-06-05']);
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 6, 4, 10), ende: wien(2026, 6, 4, 10) }, TZ, juni), ['2026-06-04']);
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 6, 4), ende: wien(2026, 6, 5) }, TZ, juni), ['2026-06-04']);
    // Endet genau um Mitternacht → der Folgetag zählt nicht.
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 6, 4, 22), ende: wien(2026, 6, 5, 0) }, TZ, juni), ['2026-06-04']);
    // Über die Monatsgrenze: nur Juni-Tage.
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 5, 30), ende: wien(2026, 6, 3) }, TZ, juni), ['2026-06-01', '2026-06-02']);
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 6, 29), ende: wien(2026, 7, 3) }, TZ, juni), ['2026-06-29', '2026-06-30']);
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 5, 1), ende: wien(2026, 5, 31) }, TZ, juni), []);
    assert.deepEqual(tageDesVorkommens({ start: wien(2026, 7, 1), ende: wien(2026, 7, 2) }, TZ, juni), []);
    // Zeitzone des Termins: 23:00–23:45 in Lissabon (UTC+1) ist in Wien schon der 5. – zählt aber als 4.
    const lissabon = { start: new Date('2026-06-04T22:00:00Z'), ende: new Date('2026-06-04T22:45:00Z') };
    assert.deepEqual(tageDesVorkommens(lissabon, 'Europe/Lisbon', juni), ['2026-06-04']);
    assert.deepEqual(tageDesVorkommens(lissabon, TZ, juni), ['2026-06-05']);
  });

  test('zeitraeumeAus fasst zusammenhängende Tage zusammen', () => {
    assert.deepEqual(zeitraeumeAus(['2026-06-03', '2026-06-01', '2026-06-02', '2026-06-05', '2026-06-05']), [
      { vonTag: '2026-06-01', bisTag: '2026-06-03' },
      { vonTag: '2026-06-05', bisTag: '2026-06-05' },
    ]);
    assert.deepEqual(zeitraeumeAus(['2026-05-31', '2026-06-01']), [{ vonTag: '2026-05-31', bisTag: '2026-06-01' }]);
    assert.deepEqual(zeitraeumeAus([]), []);
  });
});

describe('Monatsüberblick berechnen', () => {
  const familie = {
    id: 'L1',
    name: 'Familie',
    allUserIds: ['anna', 'ben'],
    termine: [
      termin({ titel: 'Zahnarzt', art: 'arzt', personen: ['anna'], start: wien(2026, 6, 3, 10), ende: wien(2026, 6, 3, 11) }),
      termin({ titel: 'Elternabend', start: wien(2026, 6, 4, 19), ende: wien(2026, 6, 4, 21) }),
      ganztag('2026-06-08', '2026-06-12', { titel: 'Strand', art: 'urlaub', personen: ['anna'] }),
      ganztag('2026-06-15', '2026-06-15', { titel: 'Ben 40', art: 'geburtstag' }),
      termin({ titel: 'Seminar', start: wien(2026, 6, 22, 9), ende: wien(2026, 6, 23, 17), personen: ['ben'] }),
      ganztag('2026-06-13', '2026-06-13', { titel: 'Fest' }),
      ganztag('2026-06-20', '2026-06-21', { titel: 'Berge', art: 'urlaub', personen: ['ben'] }),
      ganztag('2026-06-25', '2026-06-27', { titel: 'Gemeinsam', art: 'urlaub' }), // personen leer = alle
      arbeitBen,
      // Ausserhalb des Monats: zählt nirgends.
      ganztag('2026-07-04', '2026-07-05', { titel: 'Juli', art: 'urlaub' }),
    ],
  };

  test('Highlights: Urlaub, Geburtstag, Arzt, mehrtägig – nach Datum sortiert, mit Namen', () => {
    const u = monatsueberblickBerechnen([familie], juni, optionen);
    assert.deepEqual(
      u.highlights.map((h) => [h.art, h.termin.titel, h.vonTag, h.bisTag, h.personenNamen.join(',')]),
      [
        ['arzt', 'Zahnarzt', '2026-06-03', '2026-06-03', 'Anna'],
        ['urlaub', 'Strand', '2026-06-08', '2026-06-12', 'Anna'],
        ['geburtstag', 'Ben 40', '2026-06-15', '2026-06-15', ''],
        ['urlaub', 'Berge', '2026-06-20', '2026-06-21', 'Ben'],
        ['mehrtaegig', 'Seminar', '2026-06-22', '2026-06-23', 'Ben'],
        ['urlaub', 'Gemeinsam', '2026-06-25', '2026-06-27', ''],
      ],
    );
    assert.equal(u.highlights[0].listenName, 'Familie');
  });

  test('Freie Wochenenden: Arbeitsserie Mo–Fr blockt nichts, Fest und Urlaub blocken ihr Wochenende', () => {
    const u = monatsueberblickBerechnen([familie], juni, optionen);
    // Juni 2026: Sa 6., 13., 20., 27. – 13. (Fest), 20./21. (Berge), 27. (Gemeinsam) belegt.
    assert.deepEqual(u.freieWochenenden, [{ samstag: '2026-06-06', sonntag: '2026-06-07' }]);
    // Ohne die Wochenend-Einträge sind alle vier frei (Arbeit Mo–Fr stört nicht).
    const nurArbeit = { ...familie, termine: [arbeitBen] };
    assert.deepEqual(
      monatsueberblickBerechnen([nurArbeit], juni, optionen).freieWochenenden.map((w) => w.samstag),
      ['2026-06-06', '2026-06-13', '2026-06-20', '2026-06-27'],
    );
  });

  test('Freie Wochenenden: Sonntag im Folgemonat zählt mit (Oktober 2026 endet am Samstag)', () => {
    const okt = monatsFenster(wien(2026, 10, 1, 7, 0), TZ);
    const liste = { id: 'L', name: 'L', allUserIds: ['anna'], termine: [ganztag('2026-11-01', '2026-11-01', { titel: 'Allerheiligen' })] };
    const frei = monatsueberblickBerechnen([liste], okt, optionen).freieWochenenden.map((w) => w.samstag);
    assert.ok(!frei.includes('2026-10-31'), 'So 1.11. belegt → Wochenende 31.10. nicht frei');
    assert.deepEqual(frei, ['2026-10-03', '2026-10-10', '2026-10-17', '2026-10-24']);
  });

  test('Unterwegs: Urlaubstage, Arbeitstage/-stunden, Termine je Mitglied', () => {
    const u = monatsueberblickBerechnen([familie], juni, optionen);
    const anna = u.unterwegs.find((p) => p.uid === 'anna');
    const ben = u.unterwegs.find((p) => p.uid === 'ben');
    // Anna: Strand 5 Tage + Gemeinsam 3 Tage; Termine: Zahnarzt, Elternabend, Ben 40, Fest.
    assert.deepEqual(anna, { uid: 'anna', name: 'Anna', urlaubstage: 8, arbeitstage: 0, arbeitsstunden: 0, termine: 4 });
    // Ben: Berge 2 + Gemeinsam 3; Arbeit: 22 Werktage × 8 Std.; Termine: Elternabend, Ben 40, Seminar, Fest.
    assert.deepEqual(ben, { uid: 'ben', name: 'Ben', urlaubstage: 5, arbeitstage: 22, arbeitsstunden: 176, termine: 4 });
    assert.equal(u.anzahlVorkommen, 8 + 22, '8 Einzeltermine + 22 Arbeitstage im Juni');
  });

  test('Arbeitsstunden werden am Monatsrand beschnitten, ganztägige Arbeit zählt nur Tage', () => {
    const liste = {
      id: 'L',
      name: 'L',
      allUserIds: ['ben'],
      termine: [
        termin({ art: 'arbeit', start: wien(2026, 5, 31, 22), ende: wien(2026, 6, 1, 4) }), // 6 Std., davon 4 im Juni
        ganztag('2026-06-02', '2026-06-03', { art: 'arbeit' }),
      ],
    };
    const [ben] = monatsueberblickBerechnen([liste], juni, optionen).unterwegs;
    assert.equal(ben.arbeitstage, 3);
    assert.equal(ben.arbeitsstunden, 4);
  });

  test('Alle frei: nur wenn jedes Mitglied Urlaub hat, über die Monatsgrenze beschnitten', () => {
    const wg = {
      id: 'L2',
      name: 'WG',
      allUserIds: ['anna', 'ben', 'cleo'],
      termine: [
        ganztag('2026-05-28', '2026-06-03', { art: 'urlaub', personen: ['anna'] }),
        ganztag('2026-05-30', '2026-06-05', { art: 'urlaub', personen: ['ben'] }),
        ganztag('2026-05-25', '2026-06-02', { art: 'urlaub', personen: ['cleo'] }),
        ganztag('2026-06-02', '2026-06-02', { art: 'urlaub', personen: ['cleo'] }), // doppelt eingetragen
        ganztag('2026-06-28', '2026-07-10', { art: 'urlaub' }), // alle, über das Monatsende hinaus
      ],
    };
    const allein = { id: 'L3', name: 'Allein', allUserIds: ['anna'], termine: [ganztag('2026-06-10', '2026-06-11', { art: 'urlaub' })] };
    const u = monatsueberblickBerechnen([familie, wg, allein], juni, optionen);
    assert.deepEqual(u.alleFrei, [
      { listenId: 'L2', listenName: 'WG', vonTag: '2026-06-01', bisTag: '2026-06-02' },
      { listenId: 'L1', listenName: 'Familie', vonTag: '2026-06-25', bisTag: '2026-06-27' },
      { listenId: 'L2', listenName: 'WG', vonTag: '2026-06-28', bisTag: '2026-06-30' },
    ]);
    // Mitglieder über Listen hinweg nur einmal, Urlaubstage je Person zusammengeführt.
    assert.deepEqual(u.unterwegs.map((p) => p.uid), ['anna', 'ben', 'cleo']);
    // Strand 8.–12. (5), Gemeinsam 25.–27. (3), WG 1.–3. (3), WG 28.–30. (3); Allein 10.–11. liegt im Strand-Urlaub → kein doppelter Tag.
    assert.equal(u.unterwegs.find((p) => p.uid === 'anna').urlaubstage, 14);
  });

  test('leerer Monat', () => {
    const u = monatsueberblickBerechnen([{ ...familie, termine: [] }], juni, optionen);
    assert.equal(u.anzahlVorkommen, 0);
    assert.deepEqual(u.highlights, []);
    assert.equal(u.freieWochenenden.length, 4);
    assert.deepEqual(u.alleFrei, []);
  });
});

describe('Monatsüberblick-Mail (de/en)', () => {
  const familie = {
    id: 'L1',
    name: 'Familie',
    allUserIds: ['anna', 'ben'],
    termine: [
      ganztag('2026-06-08', '2026-06-12', { titel: 'Strand', art: 'urlaub', personen: ['anna'] }),
      ganztag('2026-06-25', '2026-06-27', { titel: 'Gemeinsam', art: 'urlaub' }),
      termin({ titel: 'Zahnarzt', art: 'arzt', start: wien(2026, 6, 3, 10), ende: wien(2026, 6, 3, 11) }),
      arbeitBen,
    ],
  };
  const fuss = { einstellungen: 'https://x.test/e', abmelden: { url: 'https://x.test/e?aktion=monatsueberblick-aus', schluessel: 'fuss.monatsueberblick.abmelden' } };
  const ueberblick = monatsueberblickBerechnen([familie], juni, optionen);

  test('deutsch', () => {
    const m = monatsueberblickMail({ sprache: 'de', empfaengerName: 'Anna', zeitzone: TZ, monatsStart: juni.start, ueberblick, fuss });
    assert.equal(m.betreff, 'Euer Monat: Juni 2026');
    assert.ok(m.html.includes('Hallo Anna,'));
    assert.ok(m.html.includes('Was kommt im Monat'));
    assert.ok(m.html.includes('Highlights') && m.html.includes('Freie Wochenenden') && m.html.includes('Alle frei') && m.html.includes('Wer ist wie viel unterwegs'));
    assert.ok(m.html.includes('Strand') && m.html.includes('Urlaub · Anna · Familie'));
    assert.ok(m.html.includes('Mo., 8. Juni – Fr., 12. Juni'));
    assert.ok(m.html.includes('Do., 25. Juni – Sa., 27. Juni'));
    assert.ok(m.html.includes('8 Urlaubstage'));
    assert.ok(m.html.includes('22 Arbeitstage (176 Std.)'));
    assert.ok(m.html.includes('1 Termin'));
    assert.ok(m.html.includes('Monatsüberblick abbestellen'));
    assert.ok(m.html.includes('aktion=monatsueberblick-aus'));
    assert.ok(m.html.includes('#5B4BD6'));
    assert.ok(m.text.includes('HIGHLIGHTS') && m.text.includes('Zahnarzt') && m.text.includes('Monatsüberblick abbestellen: https://x.test/e?aktion=monatsueberblick-aus'));
    assert.ok(!m.html.includes('@') && !m.text.includes('@'), 'keine Adressen in der Mail');
  });

  test('englisch', () => {
    const m = monatsueberblickMail({ sprache: 'en', empfaengerName: 'Ben', zeitzone: TZ, monatsStart: juni.start, ueberblick, fuss });
    assert.equal(m.betreff, 'Your month: June 2026');
    assert.ok(m.html.includes('Hi Ben,'));
    assert.ok(m.html.includes('What’s coming this month'));
    assert.ok(m.html.includes('Free weekends') && m.html.includes('Everyone off') && m.html.includes('Who is out and about'));
    assert.ok(m.html.includes('Vacation · Anna · Familie'));
    assert.ok(m.html.includes('Mon 8 June – Fri 12 June'));
    assert.ok(m.html.includes('22 work days (176 h)'));
    assert.ok(m.html.includes('Unsubscribe from monthly overview'));
  });

  test('leerer Monat: Hinweis statt Abschnitte', () => {
    const leer = monatsueberblickBerechnen([{ ...familie, termine: [] }], juni, optionen);
    const m = monatsueberblickMail({ sprache: 'de', empfaengerName: '', zeitzone: TZ, monatsStart: juni.start, ueberblick: leer, fuss });
    assert.ok(m.html.includes('Keine Termine in diesem Monat.'));
    assert.ok(!m.html.includes('Freie Wochenenden'));
  });

  test('Texte: alle Monats-Schlüssel in de und en, Platzhalter gleich', () => {
    const schluessel = Object.keys(TEXTE).filter((k) => k.startsWith('monat.') || k.startsWith('art.') || k.includes('monatsueberblick'));
    assert.ok(schluessel.length >= 25, `nur ${schluessel.length} Schlüssel`);
    for (const k of schluessel) {
      assert.ok(TEXTE[k].de && TEXTE[k].en, k);
      const ph = (s) => [...s.matchAll(/\{([a-z]+)\}/g)].map((m) => m[1]).sort();
      assert.deepEqual(ph(TEXTE[k].de), ph(TEXTE[k].en), `Platzhalter ${k}`);
    }
    assert.equal(t('de', 'monat.unterwegs.urlaubstage', { n: 3 }), '3 Urlaubstage');
    assert.equal(monatText('en', juni.start, TZ), 'June 2026');
    assert.equal(tagText('de', '2026-06-06'), 'Sa., 6. Juni');
    assert.equal(tagText('en', '2026-06-06'), 'Sat 6 June');
  });
});
