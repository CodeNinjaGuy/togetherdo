/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Regeltests für `termine` (Familienkalender) gegen den Firestore-Emulator,
// Kalender-Port 8090 (nie Produktion):
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8090 node --test functions/test/termine.rules.test.mjs
// oder: npm --prefix functions run test:termine-regeln

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-togetherdo-kal';
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8090').split(':');

let env;
const owner = 'owner';
const member = 'member';
const viewer = 'viewer'; // Mitglied ohne allowEdit
const stranger = 'stranger';
const now = '2026-10-16T10:00:00.000Z';

function listData(id, extra = {}) {
  return {
    id, name: 'Familie', ownerId: owner, ownerName: 'Olga', type: 'todo',
    createdAt: now, updatedAt: now, isShared: true, shareCode: '123456',
    memberIds: [member], memberNames: ['Max'], allUserIds: [owner, member], allowEdit: true,
    ...extra,
  };
}

const ts = (iso) => Timestamp.fromDate(new Date(iso));

function terminData(id, erstelltVon, extra = {}) {
  return {
    id,
    listId: 'L1',
    titel: 'Zahnarzt',
    art: 'arzt',
    personen: [member],
    start: ts('2026-10-20T13:00:00Z'),
    ende: ts('2026-10-20T14:00:00Z'),
    ganztaegig: false,
    ort: null,
    notiz: null,
    zeitzone: 'Europe/Vienna',
    wiederholung: null,
    erinnerungen: [30],
    anhaenge: [],
    erstelltVon,
    erstelltAm: serverTimestamp(),
    aktualisiertAm: serverTimestamp(),
    sichtbarBis: ts('2026-10-20T14:00:00Z'),
    naechsteErinnerungAm: ts('2026-10-20T12:30:00Z'),
    letzteErinnerungSchluessel: null,
    ...extra,
  };
}

function anhang(id, von) {
  return {
    id, name: `${id}.jpg`, typ: 'image/jpeg', groesse: 1234, pfad: `termine/L1/T1/${id}`,
    vorschauPfad: `termine/L1/T1/${id}_vorschau.jpg`, hochgeladenVon: von, hochgeladenAm: ts(now),
  };
}

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host, port: Number(port),
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => { await env?.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'lists/L1'), listData('L1'));
    await setDoc(doc(f, 'lists/RO'), listData('RO', {
      memberIds: [viewer], memberNames: ['Vera'], allUserIds: [owner, viewer], allowEdit: false, shareCode: '654321',
    }));
    // Bestehender Termin von `member` mit einem Anhang des Besitzers.
    await setDoc(doc(f, 'termine/T1'), {
      ...terminData('T1', member),
      erstelltAm: ts(now), aktualisiertAm: ts(now),
      anhaenge: [anhang('A1', owner)],
    });
    await setDoc(doc(f, 'termine/TRO'), {
      ...terminData('TRO', owner, { listId: 'RO', personen: [] }),
      erstelltAm: ts(now), aktualisiertAm: ts(now),
    });
  });
});

describe('termine lesen', () => {
  test('Mitglied liest, Fremder und Anonym nicht', async () => {
    await assertSucceeds(getDoc(doc(db(member), 'termine/T1')));
    await assertSucceeds(getDoc(doc(db(owner), 'termine/T1')));
    await assertFails(getDoc(doc(db(stranger), 'termine/T1')));
    await assertFails(getDoc(doc(anon(), 'termine/T1')));
  });

  test('Abfrage nach listId + sichtbarBis wie die App', async () => {
    const q = query(collection(db(member), 'termine'), where('listId', 'in', ['L1']), where('sichtbarBis', '>=', ts('2026-01-01T00:00:00Z')));
    await assertSucceeds(getDocs(q));
    const qFremd = query(collection(db(stranger), 'termine'), where('listId', 'in', ['L1']));
    await assertFails(getDocs(qFremd));
  });
});

describe('termine anlegen', () => {
  test('Mitglied legt gültigen Termin an (auch Nur-Lese-Mitglied)', async () => {
    await assertSucceeds(setDoc(doc(db(member), 'termine/N1'), terminData('N1', member)));
    await assertSucceeds(setDoc(doc(db(viewer), 'termine/N2'), terminData('N2', viewer, { listId: 'RO', personen: [viewer] })));
  });

  test('Fremder, falscher Ersteller, falsche ID, fremde Person, Ende vor Start', async () => {
    await assertFails(setDoc(doc(db(stranger), 'termine/N1'), terminData('N1', stranger)));
    await assertFails(setDoc(doc(db(member), 'termine/N1'), terminData('N1', owner)));
    await assertFails(setDoc(doc(db(member), 'termine/N1'), terminData('ANDERS', member)));
    await assertFails(setDoc(doc(db(member), 'termine/N1'), terminData('N1', member, { personen: [stranger] })));
    await assertFails(setDoc(doc(db(member), 'termine/N1'), terminData('N1', member, { ende: ts('2026-10-20T12:00:00Z') })));
  });

  test('Feldprüfung: Art, Titel, Wiederholung, Erinnerungen, Schlüssel, Serverzeit', async () => {
    const m = db(member);
    await assertFails(setDoc(doc(m, 'termine/N1'), terminData('N1', member, { art: 'party' })));
    await assertFails(setDoc(doc(m, 'termine/N1'), terminData('N1', member, { titel: '' })));
    await assertFails(setDoc(doc(m, 'termine/N1'), terminData('N1', member, { titel: 'x'.repeat(201) })));
    await assertFails(setDoc(doc(m, 'termine/N1'), terminData('N1', member, { wiederholung: { typ: 'stuendlich', intervall: 1 } })));
    await assertFails(setDoc(doc(m, 'termine/N1'), terminData('N1', member, { wiederholung: { typ: 'taeglich', intervall: 0 } })));
    await assertSucceeds(setDoc(doc(m, 'termine/N1'), terminData('N1', member, {
      wiederholung: { typ: 'woechentlich', intervall: 1, wochentage: [1, 2, 3, 4, 5], bisDatum: null, anzahl: null, ausnahmen: ['2026-10-26'] },
      sichtbarBis: ts('2200-01-01T00:00:00Z'),
    })));
    await assertFails(setDoc(doc(m, 'termine/N2'), terminData('N2', member, { erinnerungen: [1, 2, 3, 4, 5, 6] })));
    await assertFails(setDoc(doc(m, 'termine/N2'), terminData('N2', member, { letzteErinnerungSchluessel: 'x' })));
    await assertFails(setDoc(doc(m, 'termine/N2'), terminData('N2', member, { erstelltAm: ts(now) })));
    await assertFails(setDoc(doc(m, 'termine/N2'), terminData('N2', member, { unbekannt: 1 })));
    await assertFails(setDoc(doc(m, 'termine/N2'), terminData('N2', member, { sichtbarBis: ts('2026-10-20T13:00:00Z') })));
  });
});

describe('termine ändern und löschen', () => {
  test('Ersteller ändert, Besitzer ändert, Nur-Lese-Mitglied ändert fremden nicht', async () => {
    await assertSucceeds(updateDoc(doc(db(member), 'termine/T1'), { titel: 'Zahnarzt neu', aktualisiertAm: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db(owner), 'termine/T1'), { ort: 'Praxis', aktualisiertAm: serverTimestamp() }));
    await assertFails(updateDoc(doc(db(viewer), 'termine/TRO'), { titel: 'Nein', aktualisiertAm: serverTimestamp() }));
    await assertFails(updateDoc(doc(db(stranger), 'termine/T1'), { titel: 'Nein' }));
  });

  test('Feste Felder bleiben: listId, erstelltVon, erstelltAm, letzteErinnerungSchluessel', async () => {
    const m = db(member);
    await assertFails(updateDoc(doc(m, 'termine/T1'), { listId: 'RO' }));
    await assertFails(updateDoc(doc(m, 'termine/T1'), { erstelltVon: owner }));
    await assertFails(updateDoc(doc(m, 'termine/T1'), { erstelltAm: ts('2020-01-01T00:00:00Z') }));
    await assertFails(updateDoc(doc(m, 'termine/T1'), { letzteErinnerungSchluessel: 'x|30' }));
    await assertFails(updateDoc(doc(m, 'termine/T1'), { ende: ts('2026-10-20T12:00:00Z') }));
  });

  test('Anhänge: Mitglied fügt eigenen hinzu, nicht fremden; entfernt eigenen, nicht fremden', async () => {
    const vorher = [anhang('A1', owner)];
    // viewer ist in L1 kein Mitglied – Mitglied `member` (= Ersteller) wird nicht gebraucht,
    // darum testen wir mit `owner` (Besitzer, aber Anhang-Regel greift zuerst nicht) und einem
    // zusätzlichen Mitglied in RO. Hier: `member` als Nicht-Ersteller eines fremden Termins TRO
    // ist kein Mitglied von RO – also eigenes Szenario in L1 mit Termin des Besitzers:
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'termine/TO'), {
        ...terminData('TO', owner), erstelltAm: ts(now), aktualisiertAm: ts(now), anhaenge: vorher,
      });
      await setDoc(doc(ctx.firestore(), 'lists/L1'), listData('L1', { allowEdit: false }));
    });
    const m = db(member); // Mitglied ohne allowEdit, nicht Ersteller von TO
    await assertFails(updateDoc(doc(m, 'termine/TO'), { titel: 'Nein', aktualisiertAm: serverTimestamp() }));
    // eigenen Anhang hinzufügen: erlaubt
    await assertSucceeds(updateDoc(doc(m, 'termine/TO'), { anhaenge: [...vorher, anhang('A2', member)], aktualisiertAm: serverTimestamp() }));
    // fremden Anhang hinzufügen: verboten
    await assertFails(updateDoc(doc(m, 'termine/TO'), { anhaenge: [...vorher, anhang('A2', member), anhang('A3', owner)], aktualisiertAm: serverTimestamp() }));
    // zwei auf einmal: verboten
    await assertFails(updateDoc(doc(m, 'termine/TO'), { anhaenge: [...vorher, anhang('A2', member), anhang('A3', member), anhang('A4', member)] }));
    // fremden entfernen: verboten
    await assertFails(updateDoc(doc(m, 'termine/TO'), { anhaenge: [anhang('A2', member)], aktualisiertAm: serverTimestamp() }));
    // eigenen entfernen: erlaubt
    await assertSucceeds(updateDoc(doc(m, 'termine/TO'), { anhaenge: vorher, aktualisiertAm: serverTimestamp() }));
    // Besitzer entfernt beliebige (über die Bearbeiten-Regel)
    await assertSucceeds(updateDoc(doc(db(owner), 'termine/TO'), { anhaenge: [], aktualisiertAm: serverTimestamp() }));
  });

  test('Löschen: Ersteller und Besitzer ja, Nur-Lese-Mitglied und Fremder nein', async () => {
    await assertFails(deleteDoc(doc(db(stranger), 'termine/T1')));
    await assertFails(deleteDoc(doc(db(viewer), 'termine/TRO')));
    await assertSucceeds(deleteDoc(doc(db(member), 'termine/T1')));
    await assertSucceeds(deleteDoc(doc(db(owner), 'termine/TRO')));
  });
});
