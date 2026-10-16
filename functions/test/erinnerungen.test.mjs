/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Tests der Kalender-Functions gegen den Firestore-Emulator (Port 8090, nie
// Produktion) mit Fake-Push und Fake-Mail:
//   cd functions && npm run build && npm run test:erinnerungen

import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? 'demo-togetherdo-kal';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'nur gegen den Emulator ausführen (FIRESTORE_EMULATOR_HOST)');
assert.ok(!process.env.GCLOUD_PROJECT.includes('c9179'), 'nie gegen das echte Projekt');

const admin = (await import('firebase-admin')).default;
const { Timestamp } = await import('firebase-admin/firestore');
const { erinnerungenVerarbeiten, wochenueberblickVerarbeiten } = await import('../lib/erinnerungen.js');
const { einladungVersenden, EINLADUNGEN_JE_STUNDE } = await import('../lib/einladungen.js');
const { mailEinstellungenAnwenden } = await import('../lib/mail_einstellungen.js');
const { neuerTerminPush, loescheTermineDerListe } = await import('../lib/termine.js');
const { naechsteErinnerung, terminAusDaten, ausWandMs } = await import('../lib/termine_logik.js');
const { sendeMail, setzeTransportFuerTests } = await import('../lib/mail/sesVersand.js');
const { db } = await import('../lib/common.js');

const MIN = 60_000;
const STD = 60 * MIN;
const TAG = 24 * STD;

let lauf = 0;
const id = (p) => `${p}-${Date.now()}-${++lauf}`;

function fakeDeps() {
  const pushes = [];
  const mails = [];
  return {
    deps: {
      db,
      pushSenden: async (tokens, inhalt) => {
        pushes.push({ tokens, inhalt });
      },
      mailSenden: async (mail) => {
        mails.push(mail);
      },
      einstellungenUrl: (uid, token, aktion) => `https://test.local/mailEinstellungen?uid=${uid}&token=${token}&aktion=${aktion}`,
    },
    pushes,
    mails,
  };
}

async function nutzer(name, extra = {}) {
  const uid = id(`u-${name}`);
  await db.doc(`users/${uid}`).set({
    id: uid,
    email: `${name.toLowerCase()}-${uid}@example.test`,
    displayName: name,
    fcmToken: `token-${uid}`,
    languageCode: 'de',
    ...extra,
  });
  return uid;
}

async function liste(ownerId, ownerName, mitglieder = []) {
  const listId = id('l');
  await db.doc(`lists/${listId}`).set({
    id: listId,
    name: 'Familie',
    ownerId,
    ownerName,
    type: 'todo',
    shareCode: '424242',
    memberIds: mitglieder.map((m) => m.uid),
    memberNames: mitglieder.map((m) => m.name),
    allUserIds: [ownerId, ...mitglieder.map((m) => m.uid)],
    isShared: true,
    allowEdit: true,
  });
  return listId;
}

/** Schreibt einen Termin wie die App (inkl. naechsteErinnerungAm ab `ab`). */
async function termin(listId, erstelltVon, felder, ab) {
  const terminId = id('t');
  const roh = {
    id: terminId,
    listId,
    titel: 'Zahnarzt',
    art: 'arzt',
    personen: [],
    ganztaegig: false,
    ort: 'Praxis',
    notiz: null,
    zeitzone: 'Europe/Vienna',
    wiederholung: null,
    erinnerungen: [15],
    erstelltVon,
    erstelltAm: Timestamp.now(),
    aktualisiertAm: Timestamp.now(),
    letzteErinnerungSchluessel: null,
    ...felder,
  };
  const t = terminAusDaten(terminId, { ...roh, start: roh.start, ende: roh.ende });
  const naechste = ab ? naechsteErinnerung(t, ab) : null;
  const sichtbar = roh.wiederholung && !roh.wiederholung.bisDatum && !roh.wiederholung.anzahl ? new Date(Date.UTC(2200, 0, 1)) : roh.ende;
  await db.doc(`termine/${terminId}`).set({
    ...roh,
    start: Timestamp.fromDate(roh.start),
    ende: Timestamp.fromDate(roh.ende),
    sichtbarBis: Timestamp.fromDate(sichtbar),
    naechsteErinnerungAm: naechste ? Timestamp.fromDate(naechste.zeitpunkt) : null,
  });
  return terminId;
}

const lies = async (pfad) => (await db.doc(pfad).get()).data();

before(async () => {
  // Alte Testdaten weg, damit die Zähler stimmen (nur Emulator).
  for (const s of ['termine', 'users', 'lists', 'rateLimits']) {
    const snap = await db.collection(s).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
});

after(async () => {
  await admin.app().delete();
});

describe('Erinnerungen (alle 5 Minuten)', () => {
  test('fällige Erinnerung geht genau einmal raus; zweiter Lauf ist idempotent', async () => {
    const jetzt = new Date('2026-05-04T06:00:00Z');
    const anna = await nutzer('Anna'); // Standard: push
    const ben = await nutzer('Ben', { mailEinstellungen: { erinnerungen: 'mail' }, languageCode: 'en' });
    const listId = await liste(anna, 'Anna', [{ uid: ben, name: 'Ben' }]);
    const start = new Date(jetzt.getTime() + 15 * MIN);
    const terminId = await termin(listId, anna, { start, ende: new Date(start.getTime() + STD) }, new Date(jetzt.getTime() - STD));
    assert.equal((await lies(`termine/${terminId}`)).naechsteErinnerungAm.toMillis(), jetzt.getTime());

    const { deps, pushes, mails } = fakeDeps();
    const e1 = await erinnerungenVerarbeiten(jetzt, deps);
    assert.equal(e1.geprueft, 1);
    assert.equal(e1.gesendet, 2, 'ein Push und eine Mail');
    assert.equal(e1.fehler, 0);
    assert.equal(pushes.length, 1);
    assert.deepEqual(pushes[0].tokens, [`token-${anna}`]);
    assert.equal(pushes[0].inhalt.title, 'Zahnarzt');
    assert.equal(pushes[0].inhalt.data.type, 'termin_erinnerung');
    assert.equal(pushes[0].inhalt.data.terminId, terminId);
    assert.equal(mails.length, 1);
    assert.ok(mails[0].an.startsWith('ben-'));
    assert.equal(mails[0].art, 'erinnerung');
    assert.match(mails[0].betreff, /^Reminder: Zahnarzt/);
    assert.ok(mails[0].html.includes('Hi Ben,'));
    assert.ok(mails[0].html.includes('Anna, Ben') === false, 'Termin für alle → keine Namensliste');
    assert.ok(mails[0].html.includes('Everyone in the list'));
    assert.equal(mails[0].anhaenge.length, 1);
    assert.equal(mails[0].anhaenge[0].dateiname, 'termin.ics');
    assert.ok(mails[0].anhaenge[0].inhalt.includes('DTSTART:20260504T061500Z'));

    const nachher = await lies(`termine/${terminId}`);
    assert.equal(nachher.letzteErinnerungSchluessel, `${start.toISOString()}|15`);
    assert.equal(nachher.naechsteErinnerungAm, null, 'keine weitere Erinnerung');
    // Abmelde-Token wurde für den Mail-Empfänger angelegt und steckt im Link.
    const benDoc = await lies(`users/${ben}`);
    assert.ok(typeof benDoc.mailAbmeldeToken === 'string' && benDoc.mailAbmeldeToken.length >= 32);
    assert.ok(mails[0].html.includes(benDoc.mailAbmeldeToken));
    assert.equal((await lies(`users/${anna}`)).mailAbmeldeToken, undefined, 'Push-Empfänger braucht kein Token');

    // Zweiter Lauf: nichts mehr fällig.
    const e2 = await erinnerungenVerarbeiten(new Date(jetzt.getTime() + 5 * MIN), deps);
    assert.equal(e2.geprueft, 0);
    // App schreibt denselben Fälligkeitspunkt noch einmal → gleicher Schlüssel → nur fortschreiben.
    await db.doc(`termine/${terminId}`).update({ naechsteErinnerungAm: Timestamp.fromDate(jetzt) });
    const e3 = await erinnerungenVerarbeiten(new Date(jetzt.getTime() + 5 * MIN), deps);
    assert.equal(e3.geprueft, 1);
    assert.equal(e3.gesendet, 0);
    assert.equal(e3.fortgeschrieben, 1);
    assert.equal(pushes.length, 1);
    assert.equal(mails.length, 1);
    assert.equal((await lies(`termine/${terminId}`)).naechsteErinnerungAm, null);
  });

  test('Wiederholung schreibt naechsteErinnerungAm auf das nächste Vorkommen fort', async () => {
    const jetzt = ausWandMs(Date.UTC(2026, 2, 28, 6, 0), 'Europe/Vienna'); // 28.3. 06:00 Wien, vor der Umstellung
    const anna = await nutzer('Anna');
    const listId = await liste(anna, 'Anna');
    const terminId = await termin(
      listId,
      anna,
      {
        titel: 'Joggen',
        start: jetzt,
        ende: new Date(jetzt.getTime() + 30 * MIN),
        erinnerungen: [0],
        wiederholung: { typ: 'taeglich', intervall: 1, wochentage: [], bisDatum: null, anzahl: null, ausnahmen: [] },
      },
      new Date(jetzt.getTime() - 1),
    );
    const { deps, pushes } = fakeDeps();
    const e = await erinnerungenVerarbeiten(jetzt, deps);
    assert.equal(e.gesendet, 1);
    assert.equal(pushes[0].inhalt.body, '28. März, 06:00 · Praxis');
    const d = await lies(`termine/${terminId}`);
    assert.equal(d.letzteErinnerungSchluessel, `${jetzt.toISOString()}|0`);
    // Nächster Tag 6:00 Ortszeit = 04:00Z (Sommerzeit ab 29.3.).
    assert.equal(new Date(d.naechsteErinnerungAm.toMillis()).toISOString(), '2026-03-29T04:00:00.000Z');
    // Nächster Lauf einen Tag später sendet erneut (anderer Schlüssel).
    const e2 = await erinnerungenVerarbeiten(new Date('2026-03-29T04:02:00Z'), deps);
    assert.equal(e2.gesendet, 1);
    assert.equal(pushes.length, 2);
    assert.equal((await lies(`termine/${terminId}`)).letzteErinnerungSchluessel, '2026-03-29T04:00:00.000Z|0');
    // Endlose Serie wegräumen, sonst ist sie in späteren Tests ständig „überfällig“.
    await db.doc(`termine/${terminId}`).delete();
  });

  test('Einstellung push/mail/beide/keine und Personen-Auswahl', async () => {
    const jetzt = new Date('2026-06-01T10:00:00Z');
    const p = await nutzer('Push', { mailEinstellungen: { erinnerungen: 'push' } });
    const m = await nutzer('Mail', { mailEinstellungen: { erinnerungen: 'mail' } });
    const b = await nutzer('Beide', { mailEinstellungen: { erinnerungen: 'beide' } });
    const k = await nutzer('Keine', { mailEinstellungen: { erinnerungen: 'keine' } });
    const x = await nutzer('Nicht'); // nicht in `personen`
    const listId = await liste(p, 'Push', [
      { uid: m, name: 'Mail' },
      { uid: b, name: 'Beide' },
      { uid: k, name: 'Keine' },
      { uid: x, name: 'Nicht' },
    ]);
    const start = new Date(jetzt.getTime() + 15 * MIN);
    await termin(listId, p, { start, ende: new Date(start.getTime() + STD), personen: [p, m, b, k] }, new Date(jetzt.getTime() - 1));
    const { deps, pushes, mails } = fakeDeps();
    const e = await erinnerungenVerarbeiten(jetzt, deps);
    assert.equal(e.gesendet, 4);
    const tokens = pushes.flatMap((x) => x.tokens).sort();
    assert.deepEqual(tokens, [`token-${b}`, `token-${p}`].sort());
    assert.deepEqual(mails.map((x) => x.an.split('-')[0]).sort(), ['beide', 'mail']);
    assert.ok(mails[0].html.includes('Push, Mail, Beide, Keine'), 'Namen aus der Liste');
  });

  test('mehr als 2 Stunden verspätet: nur fortschreiben, nicht senden', async () => {
    const jetzt = new Date('2026-06-02T10:00:00Z');
    const anna = await nutzer('Anna');
    const listId = await liste(anna, 'Anna');
    const start = new Date(jetzt.getTime() - 3 * STD + 15 * MIN);
    const terminId = await termin(listId, anna, { start, ende: new Date(start.getTime() + STD) }, new Date(start.getTime() - TAG));
    const { deps, pushes } = fakeDeps();
    const e = await erinnerungenVerarbeiten(jetzt, deps);
    assert.equal(e.geprueft, 1);
    assert.equal(e.fortgeschrieben, 1);
    assert.equal(e.gesendet, 0);
    assert.equal(pushes.length, 0);
    const d = await lies(`termine/${terminId}`);
    assert.equal(d.naechsteErinnerungAm, null);
    assert.equal(d.letzteErinnerungSchluessel, null);
  });

  test('Termin verschoben: noch nicht fällig → Zeiger wird gerichtet', async () => {
    const jetzt = new Date('2026-06-03T10:00:00Z');
    const anna = await nutzer('Anna');
    const listId = await liste(anna, 'Anna');
    const start = new Date(jetzt.getTime() + 5 * STD);
    const terminId = await termin(listId, anna, { start, ende: new Date(start.getTime() + STD) }, null);
    // App hat einen veralteten (zu frühen) Fälligkeitspunkt stehen lassen.
    await db.doc(`termine/${terminId}`).update({ naechsteErinnerungAm: Timestamp.fromDate(jetzt) });
    const { deps, pushes } = fakeDeps();
    const e = await erinnerungenVerarbeiten(jetzt, deps);
    assert.equal(e.gesendet, 0);
    assert.equal(pushes.length, 0);
    assert.equal((await lies(`termine/${terminId}`)).naechsteErinnerungAm.toMillis(), start.getTime() - 15 * MIN);
  });
});

describe('Abmelde-Link (mailEinstellungen)', () => {
  test('richtiges Token setzt Einstellungen, falsches nicht', async () => {
    const uid = await nutzer('Link', {
      mailEinstellungen: { erinnerungen: 'beide', wochenueberblick: true },
      mailAbmeldeToken: 'a'.repeat(43),
      languageCode: 'en',
    });
    const falsch = await mailEinstellungenAnwenden({ uid, token: 'b'.repeat(43), aktion: 'abmelden' }, db);
    assert.equal(falsch.status, 400);
    assert.ok(falsch.html.includes('invalid or has expired'));
    assert.equal((await lies(`users/${uid}`)).mailEinstellungen.erinnerungen, 'beide');

    const ok = await mailEinstellungenAnwenden({ uid, token: 'a'.repeat(43), aktion: 'abmelden' }, db);
    assert.equal(ok.status, 200);
    assert.ok(ok.html.includes('only as push notifications'));
    let d = await lies(`users/${uid}`);
    assert.equal(d.mailEinstellungen.erinnerungen, 'push');
    assert.equal(d.mailEinstellungen.wochenueberblick, true, 'andere Einstellung unberührt');

    const woche = await mailEinstellungenAnwenden({ uid, token: 'a'.repeat(43), aktion: 'wochenueberblick-aus' }, db);
    assert.equal(woche.status, 200);
    d = await lies(`users/${uid}`);
    assert.equal(d.mailEinstellungen.wochenueberblick, false);

    assert.equal((await mailEinstellungenAnwenden({ uid, token: 'a'.repeat(43), aktion: 'kaputt' }, db)).status, 400);
    assert.equal((await mailEinstellungenAnwenden({ uid: 'gibtsnicht', token: 'a'.repeat(43), aktion: 'abmelden' }, db, 'de')).status, 400);
    assert.equal((await mailEinstellungenAnwenden({}, db)).status, 400);
  });
});

describe('Wochenüberblick (Sonntag 18:00)', () => {
  test('eine Mail je Abonnent mit den Terminen der kommenden Woche, leer = keine Mail', async () => {
    const sonntag = ausWandMs(Date.UTC(2026, 5, 7, 18, 0), 'Europe/Vienna'); // So 7.6.2026 18:00
    const anna = await nutzer('Anna', { mailEinstellungen: { wochenueberblick: true } });
    const ben = await nutzer('Ben', { mailEinstellungen: { wochenueberblick: true }, languageCode: 'en' });
    const cleo = await nutzer('Cleo'); // kein Abo
    const familie = await liste(anna, 'Anna', [{ uid: cleo, name: 'Cleo' }]);
    const wg = await liste(ben, 'Ben');
    const di = ausWandMs(Date.UTC(2026, 5, 9, 8, 0), 'Europe/Vienna');
    await termin(familie, anna, { titel: 'Schularzt', start: di, ende: new Date(di.getTime() + STD), personen: [cleo] }, null); // nur Cleo → nicht für Anna
    await termin(familie, anna, { titel: 'Elternabend', start: new Date(di.getTime() + 10 * STD), ende: new Date(di.getTime() + 12 * STD) }, null);
    const sa = ausWandMs(Date.UTC(2026, 5, 13, 0, 0), 'Europe/Vienna');
    await termin(familie, anna, { titel: 'Oma', ganztaegig: true, start: sa, ende: new Date(sa.getTime() + TAG) }, null);
    // Serie aus der Vergangenheit, wöchentlich → ein Vorkommen in der Woche.
    const serieStart = ausWandMs(Date.UTC(2026, 0, 5, 19, 0), 'Europe/Vienna'); // Mo 5.1.
    await termin(
      familie,
      anna,
      {
        titel: 'Chor',
        start: serieStart,
        ende: new Date(serieStart.getTime() + 2 * STD),
        wiederholung: { typ: 'woechentlich', intervall: 1, wochentage: [1], bisDatum: null, anzahl: null, ausnahmen: [] },
      },
      null,
    );
    // Außerhalb der Woche.
    await termin(familie, anna, { titel: 'Später', start: new Date(sa.getTime() + 10 * TAG), ende: new Date(sa.getTime() + 10 * TAG + STD) }, null);
    // Ben hat in der Woche nichts.
    void wg;

    const { deps, mails } = fakeDeps();
    const e = await wochenueberblickVerarbeiten(sonntag, deps);
    assert.equal(e.nutzer, 2);
    assert.equal(e.gesendet, 1);
    assert.equal(e.leer, 1);
    assert.equal(mails.length, 1);
    assert.ok(mails[0].an.startsWith('anna-'));
    assert.equal(mails[0].art, 'wochenueberblick');
    assert.equal(mails[0].betreff, 'Eure Woche: 8. Juni – 14. Juni');
    assert.ok(mails[0].text.includes('Chor'));
    assert.ok(mails[0].text.includes('Elternabend'));
    assert.ok(mails[0].text.includes('Oma'));
    assert.ok(!mails[0].text.includes('Schularzt'));
    assert.ok(!mails[0].text.includes('Später'));
    assert.ok(mails[0].text.indexOf('Chor') < mails[0].text.indexOf('Elternabend'), 'Montag vor Dienstag');
    assert.ok(mails[0].html.includes('Wochenüberblick abbestellen'));
    assert.ok(mails[0].html.includes('aktion=wochenueberblick-aus'));
  });
});

describe('inviteByEmail', () => {
  test('nur Besitzer, Adresse geprüft, Ratenbegrenzung, Antwort immer gleich', async () => {
    const olga = await nutzer('Olga');
    const max = await nutzer('Max');
    const listId = await liste(olga, 'Olga', [{ uid: max, name: 'Max' }]);
    const { deps, mails } = fakeDeps();
    const jetzt = Date.now();

    const r = await einladungVersenden({ uid: olga, listId, email: 'Tante@Example.test' }, deps, jetzt);
    assert.deepEqual(r, { gesendet: true });
    assert.equal(mails.length, 1);
    assert.equal(mails[0].an, 'Tante@Example.test');
    assert.equal(mails[0].art, 'einladung');
    assert.ok(mails[0].html.includes('424242'));
    assert.ok(mails[0].html.includes('Olga'));
    assert.ok(mails[0].betreff.includes('Familie'));

    const code = async (p, erwartet) => {
      await assert.rejects(p, (e) => {
        assert.equal(e.code, erwartet, `${e.code}: ${e.message}`);
        return true;
      });
    };
    await code(einladungVersenden({ uid: max, listId, email: 'x@example.test' }, deps, jetzt), 'permission-denied');
    await code(einladungVersenden({ uid: olga, listId, email: 'keine-adresse' }, deps, jetzt), 'invalid-argument');
    await code(einladungVersenden({ uid: olga, listId: 'gibtsnicht', email: 'x@example.test' }, deps, jetzt), 'not-found');
    assert.equal(mails.length, 1);

    // Konto mit abgestellten Einladungen → still keine Mail, Antwort gleich.
    const still = await nutzer('Still', { mailEinstellungen: { einladungen: false } });
    const stillMail = (await lies(`users/${still}`)).email;
    assert.deepEqual(await einladungVersenden({ uid: olga, listId, email: stillMail }, deps, jetzt), { gesendet: true });
    assert.equal(mails.length, 1);
    // Konto, das schon Mitglied ist → ebenfalls still.
    assert.deepEqual(await einladungVersenden({ uid: olga, listId, email: (await lies(`users/${max}`)).email }, deps, jetzt), { gesendet: true });
    assert.equal(mails.length, 1);
    // Englischer Empfänger bekommt englische Mail.
    const eng = await nutzer('Eng', { languageCode: 'en' });
    await einladungVersenden({ uid: olga, listId, email: (await lies(`users/${eng}`)).email }, deps, jetzt);
    assert.match(mails.at(-1).betreff, /invited you/);

    // Ratenbegrenzung je Nutzer: bisher 4 gezählt (Tante, Still, Max, Eng) – Fehler
    // vor der Zählung (Rechte, Adresse, Liste) zählen nicht. Weiter bis zur Grenze.
    const gezaehlt = 4;
    for (let i = gezaehlt; i < EINLADUNGEN_JE_STUNDE; i++) {
      await einladungVersenden({ uid: olga, listId, email: `p${i}@example.test` }, deps, jetzt);
    }
    await code(einladungVersenden({ uid: olga, listId, email: 'zuviel@example.test' }, deps, jetzt), 'resource-exhausted');
    // Nach einer Stunde wieder frei.
    await einladungVersenden({ uid: olga, listId, email: 'spaeter@example.test' }, deps, jetzt + STD + 1);
    // Keine Klartext-Adresse in rateLimits.
    const grenzen = await db.collection('rateLimits').get();
    assert.ok(grenzen.size >= 2);
    grenzen.forEach((d) => {
      assert.ok(!d.id.includes('@'));
      assert.ok(!JSON.stringify(d.data()).includes('@'));
    });
  });

  test('dieselbe Adresse höchstens 3× am Tag (still)', async () => {
    const olga = await nutzer('Olga');
    const listId = await liste(olga, 'Olga');
    const { deps, mails } = fakeDeps();
    const jetzt = Date.now();
    for (let i = 0; i < 5; i++) await einladungVersenden({ uid: olga, listId, email: 'oft@example.test' }, deps, jetzt + i);
    assert.equal(mails.length, 3);
  });
});

describe('Termin-Auslöser', () => {
  test('neuer Termin: Push an Betroffene außer Ersteller, Einstellung termin_created', async () => {
    const anna = await nutzer('Anna');
    const ben = await nutzer('Ben');
    const cleo = await nutzer('Cleo', { notificationSettings: { termin_created: false } });
    const dora = await nutzer('Dora');
    const listId = await liste(anna, 'Anna', [{ uid: ben, name: 'Ben' }, { uid: cleo, name: 'Cleo' }, { uid: dora, name: 'Dora' }]);
    const { deps, pushes } = fakeDeps();
    const start = new Date();
    const n = await neuerTerminPush('neu1', {
      listId,
      titel: 'Picknick',
      start: Timestamp.fromDate(start),
      ende: Timestamp.fromDate(new Date(start.getTime() + STD)),
      erstelltVon: anna,
      personen: [],
    }, deps);
    assert.equal(n, 2);
    assert.deepEqual(pushes[0].tokens.sort(), [`token-${ben}`, `token-${dora}`].sort());
    assert.equal(pushes[0].inhalt.body, 'Neuer Termin: Picknick');
    assert.equal(pushes[0].inhalt.data.type, 'termin_created');
    // Nur bestimmte Personen.
    const n2 = await neuerTerminPush('neu2', {
      listId, titel: 'Nur Dora', start: Timestamp.fromDate(start), ende: Timestamp.fromDate(start), erstelltVon: anna, personen: [dora, anna],
    }, deps);
    assert.equal(n2, 1);
    assert.deepEqual(pushes[1].tokens, [`token-${dora}`]);
  });

  test('gelöschte Liste nimmt ihre Termine mit (still markiert)', async () => {
    const anna = await nutzer('Anna');
    const listId = await liste(anna, 'Anna');
    const andere = await liste(anna, 'Anna');
    const s = new Date();
    const t1 = await termin(listId, anna, { start: s, ende: s }, null);
    const t2 = await termin(listId, anna, { start: s, ende: s }, null);
    const t3 = await termin(andere, anna, { start: s, ende: s }, null);
    await db.doc(`termine/${t1}/anhaenge/A1`).set({ id: 'A1', pfad: `termine/${listId}/${t1}/A1` });
    const n = await loescheTermineDerListe(listId);
    assert.equal(n, 2);
    assert.equal((await db.doc(`termine/${t1}`).get()).exists, false);
    // Anhang-Beschreibungen (Untersammlung) gehen mit.
    assert.equal((await db.doc(`termine/${t1}/anhaenge/A1`).get()).exists, false);
    assert.equal((await db.doc(`termine/${t2}`).get()).exists, false);
    assert.equal((await db.doc(`termine/${t3}`).get()).exists, true);
  });
});

describe('SES-Versand', () => {
  test('Test-Transport bekommt Absender, Anhang und Kopfzeile; kein Reply-To', async () => {
    const gesendet = [];
    setzeTransportFuerTests({ sendMail: async (o) => (gesendet.push(o), { messageId: 'fake' }) });
    try {
      await sendeMail({ an: 'x@example.test', betreff: 'B', html: '<p>h</p>', text: 't', art: 'erinnerung', anhaenge: [{ dateiname: 'termin.ics', inhalt: 'BEGIN:VCALENDAR', typ: 'text/calendar' }] });
    } finally {
      setzeTransportFuerTests(null);
    }
    assert.equal(gesendet.length, 1);
    assert.equal(gesendet[0].from, 'ToGetherDo <noreply@seebubble.me>');
    assert.equal(gesendet[0].replyTo, undefined);
    assert.equal(gesendet[0].attachments[0].filename, 'termin.ics');
    assert.equal(gesendet[0].headers['X-ToGetherDo-Mail'], 'erinnerung');
  });
});
