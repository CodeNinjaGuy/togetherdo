/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Monatsüberblick gegen den Firestore-Emulator (Port 8090, nie Produktion) mit
// Fake-Mail-Transport:
//   cd functions && npm run build && npm run test:monatsueberblick

import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? 'demo-togetherdo-kal';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'nur gegen den Emulator ausführen (FIRESTORE_EMULATOR_HOST)');
assert.ok(!process.env.GCLOUD_PROJECT.includes('c9179'), 'nie gegen das echte Projekt');

const admin = (await import('firebase-admin')).default;
const { Timestamp } = await import('firebase-admin/firestore');
const { monatsueberblickVerarbeiten } = await import('../lib/monatsueberblick.js');
const { mailEinstellungenAnwenden } = await import('../lib/mail_einstellungen.js');
const { nutzerAus } = await import('../lib/empfaenger.js');
const { ausWandMs } = await import('../lib/termine_logik.js');
const { db } = await import('../lib/common.js');

const STD = 60 * 60 * 1000;
const TAG = 24 * STD;
const TZ = 'Europe/Vienna';
const wien = (j, m, t, h = 0) => ausWandMs(Date.UTC(j, m - 1, t, h), TZ);

let lauf = 0;
const id = (p) => `${p}-${Date.now()}-${++lauf}`;

function fakeDeps() {
  const mails = [];
  return {
    deps: {
      db,
      pushSenden: async () => {},
      mailSenden: async (mail) => {
        mails.push(mail);
      },
      einstellungenUrl: (uid, token, aktion) => `https://test.local/mailEinstellungen?uid=${uid}&token=${token}&aktion=${aktion}`,
    },
    mails,
  };
}

async function nutzer(name, extra = {}) {
  const uid = id(`u-${name}`);
  await db.doc(`users/${uid}`).set({ id: uid, email: `${name.toLowerCase()}-${uid}@example.test`, displayName: name, languageCode: 'de', ...extra });
  return uid;
}

async function liste(name, ownerId, ownerName, mitglieder = []) {
  const listId = id('l');
  await db.doc(`lists/${listId}`).set({
    id: listId,
    name,
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

async function termin(listId, erstelltVon, felder) {
  const terminId = id('t');
  const roh = {
    id: terminId,
    listId,
    titel: 'Termin',
    art: 'termin',
    personen: [],
    ganztaegig: false,
    ort: null,
    notiz: null,
    zeitzone: TZ,
    wiederholung: null,
    erinnerungen: [],
    anhaenge: [],
    erstelltVon,
    erstelltAm: Timestamp.now(),
    aktualisiertAm: Timestamp.now(),
    naechsteErinnerungAm: null,
    letzteErinnerungSchluessel: null,
    ...felder,
  };
  const endlos = roh.wiederholung && !roh.wiederholung.bisDatum && !roh.wiederholung.anzahl;
  await db.doc(`termine/${terminId}`).set({
    ...roh,
    start: Timestamp.fromDate(roh.start),
    ende: Timestamp.fromDate(roh.ende),
    sichtbarBis: Timestamp.fromDate(endlos ? new Date(Date.UTC(2200, 0, 1)) : roh.ende),
  });
  return terminId;
}

const lies = async (pfad) => (await db.doc(pfad).get()).data();

before(async () => {
  for (const s of ['termine', 'users', 'lists']) {
    const snap = await db.collection(s).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
});

after(async () => {
  await admin.app().delete();
});

describe('Monatsüberblick (1. des Monats 07:00)', () => {
  test('Feld mailEinstellungen.monatsueberblick: Standard aus, nur true zählt', async () => {
    const ref = db.doc('users/x');
    assert.equal(nutzerAus('x', ref, {}).monatsueberblick, false);
    assert.equal(nutzerAus('x', ref, { mailEinstellungen: { wochenueberblick: true } }).monatsueberblick, false);
    assert.equal(nutzerAus('x', ref, { mailEinstellungen: { monatsueberblick: 'ja' } }).monatsueberblick, false);
    assert.equal(nutzerAus('x', ref, { mailEinstellungen: { monatsueberblick: true } }).monatsueberblick, true);
  });

  test('genau eine Mail je Abonnent mit Terminen; ohne Einstellung oder ohne Termine keine', async () => {
    const ersterJuni = wien(2026, 6, 1, 7);
    const anna = await nutzer('Anna', { mailEinstellungen: { monatsueberblick: true, wochenueberblick: true } });
    const ben = await nutzer('Ben', { mailEinstellungen: { monatsueberblick: true }, languageCode: 'en' }); // Abo, aber leerer Monat
    const cleo = await nutzer('Cleo'); // keine Einstellung
    const dora = await nutzer('Dora', { mailEinstellungen: { monatsueberblick: false } });
    const familie = await liste('Familie', anna, 'Anna', [{ uid: cleo, name: 'Cleo' }, { uid: dora, name: 'Dora' }]);
    await liste('WG', ben, 'Ben');

    await termin(familie, anna, { titel: 'Strand', art: 'urlaub', ganztaegig: true, personen: [anna], start: wien(2026, 6, 8), ende: wien(2026, 6, 13) });
    await termin(familie, anna, { titel: 'Oma 80', art: 'geburtstag', ganztaegig: true, start: wien(2026, 6, 15), ende: wien(2026, 6, 16) });
    await termin(familie, cleo, { titel: 'Zahnarzt', art: 'arzt', personen: [cleo], start: wien(2026, 6, 3, 10), ende: wien(2026, 6, 3, 11) });
    await termin(familie, anna, { titel: 'Alle weg', art: 'urlaub', ganztaegig: true, start: wien(2026, 6, 26), ende: wien(2026, 6, 29) });
    // Arbeitsserie Mo–Fr seit Jänner für Dora.
    await termin(familie, dora, {
      titel: 'Arbeit',
      art: 'arbeit',
      personen: [dora],
      start: wien(2026, 1, 5, 8),
      ende: wien(2026, 1, 5, 16),
      wiederholung: { typ: 'woechentlich', intervall: 1, wochentage: [1, 2, 3, 4, 5], bisDatum: null, anzahl: null, ausnahmen: [] },
    });
    // Vergangener Termin: wird von der Abfrage (sichtbarBis) gar nicht geladen.
    await termin(familie, anna, { titel: 'Vergangen', start: wien(2026, 5, 20, 10), ende: wien(2026, 5, 20, 11) });

    const { deps, mails } = fakeDeps();
    const e = await monatsueberblickVerarbeiten(ersterJuni, deps);
    assert.deepEqual(e, { nutzer: 2, gesendet: 1, leer: 1 });
    assert.equal(mails.length, 1);
    const mail = mails[0];
    assert.ok(mail.an.startsWith('anna-'));
    assert.equal(mail.art, 'monatsueberblick');
    assert.equal(mail.betreff, 'Euer Monat: Juni 2026');
    assert.ok(mail.html.includes('Hallo Anna,'));
    assert.ok(mail.text.includes('Strand') && mail.text.includes('Oma 80') && mail.text.includes('Zahnarzt') && mail.text.includes('Alle weg'));
    assert.ok(!mail.text.includes('Vergangen'));
    assert.ok(mail.html.includes('Urlaub · Anna · Familie'), 'Name aus der Liste');
    assert.ok(mail.html.includes('Arzt · Cleo · Familie'));
    assert.ok(mail.html.includes('Fr., 26. Juni – So., 28. Juni'), 'Alle frei');
    assert.ok(mail.html.includes('22 Arbeitstage (176 Std.)'), 'Dora unterwegs');
    assert.ok(mail.html.includes('Sa., 6. Juni – So., 7. Juni'), 'freies Wochenende');
    assert.ok(!mail.html.includes('Sa., 27. Juni'), '27./28. durch Urlaub belegt');
    assert.ok(mail.html.includes('Monatsüberblick abbestellen'));
    assert.ok(mail.html.includes('aktion=monatsueberblick-aus'));
    assert.ok(!mail.html.includes('@example.test') && !mail.text.includes('@example.test'), 'keine Adressen im Inhalt');

    const annaDoc = await lies(`users/${anna}`);
    assert.ok(typeof annaDoc.mailAbmeldeToken === 'string' && annaDoc.mailAbmeldeToken.length >= 32);
    assert.ok(mail.html.includes(annaDoc.mailAbmeldeToken));
    assert.equal((await lies(`users/${cleo}`)).mailAbmeldeToken, undefined);

    // Abmelde-Aktion wirkt: Einstellung aus, andere unberührt, kein weiterer Versand.
    const falsch = await mailEinstellungenAnwenden({ uid: anna, token: 'x'.repeat(43), aktion: 'monatsueberblick-aus' }, db);
    assert.equal(falsch.status, 400);
    assert.equal((await lies(`users/${anna}`)).mailEinstellungen.monatsueberblick, true);
    const ok = await mailEinstellungenAnwenden({ uid: anna, token: annaDoc.mailAbmeldeToken, aktion: 'monatsueberblick-aus' }, db);
    assert.equal(ok.status, 200);
    assert.ok(ok.html.includes('Der Monatsüberblick ist abbestellt.'));
    const danach = await lies(`users/${anna}`);
    assert.equal(danach.mailEinstellungen.monatsueberblick, false);
    assert.equal(danach.mailEinstellungen.wochenueberblick, true);

    const e2 = await monatsueberblickVerarbeiten(ersterJuni, deps);
    assert.deepEqual(e2, { nutzer: 1, gesendet: 0, leer: 1 });
    assert.equal(mails.length, 1);
  });

  test('englischer Abonnent bekommt englische Mail', async () => {
    const ben = await nutzer('Ben', { mailEinstellungen: { monatsueberblick: true }, languageCode: 'en' });
    const wg = await liste('Flat', ben, 'Ben');
    await termin(wg, ben, { titel: 'Dentist', art: 'arzt', start: wien(2026, 6, 3, 10), ende: wien(2026, 6, 3, 11) });
    const { deps, mails } = fakeDeps();
    const e = await monatsueberblickVerarbeiten(wien(2026, 6, 1, 7), deps);
    assert.equal(e.gesendet, 1);
    const mail = mails.find((m) => m.an.startsWith('ben-'));
    assert.ok(mail);
    assert.equal(mail.betreff, 'Your month: June 2026');
    assert.ok(mail.html.includes('Unsubscribe from monthly overview'));
    assert.ok(mail.html.includes('Doctor · Everyone in the list · Flat'));
  });
});
