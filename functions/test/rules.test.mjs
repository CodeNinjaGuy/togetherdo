/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Regeltests gegen den Firestore-Emulator (nie Produktion).
//   firebase emulators:exec --only firestore --project demo-togetherdo \
//     "npm --prefix functions run test:rules"

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-togetherdo';
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');

let env;

const owner = 'owner';
const member = 'member';
const viewer = 'viewer'; // Mitglied einer Liste ohne allowEdit
const stranger = 'stranger';

const now = '2026-10-16T10:00:00.000Z';

function listData(id, extra = {}) {
  return {
    id,
    name: 'Haushalt',
    ownerId: owner,
    ownerName: 'Olga',
    type: 'todo',
    createdAt: now,
    updatedAt: now,
    isShared: true,
    shareCode: '123456',
    memberIds: [member],
    memberNames: ['Max'],
    allUserIds: [owner, member],
    allowEdit: true,
    ...extra,
  };
}

function todoData(id, userId, listId = 'L1') {
  return {
    id,
    title: 'Müll raus',
    description: '',
    isCompleted: false,
    createdAt: now,
    priority: 'medium',
    userId,
    listId,
  };
}

function itemData(id, userId, listId = 'S1') {
  return {
    id,
    name: 'Milch',
    quantity: 1,
    unit: 'l',
    isPurchased: false,
    createdAt: now,
    userId,
    listId,
  };
}

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'lists/L1'), listData('L1'));
    await setDoc(
      doc(f, 'lists/RO'),
      listData('RO', {
        memberIds: [viewer],
        memberNames: ['Vera'],
        allUserIds: [owner, viewer],
        allowEdit: false,
        shareCode: '654321',
      }),
    );
    await setDoc(
      doc(f, 'lists/S1'),
      listData('S1', {
        type: 'shopping',
        memberIds: [viewer],
        memberNames: ['Vera'],
        allUserIds: [owner, viewer],
        allowEdit: false,
        shareCode: '111111',
      }),
    );
    await setDoc(doc(f, 'todos/T1'), todoData('T1', owner));
    await setDoc(doc(f, 'todos/TRO'), todoData('TRO', owner, 'RO'));
    await setDoc(doc(f, 'todos/T1/chatMessages/M1'), {
      id: 'M1',
      todoId: 'T1',
      userId: owner,
      userName: 'Olga',
      message: 'Hallo',
      timestamp: now,
      isRead: false,
    });
    await setDoc(doc(f, 'shopping_items/I1'), itemData('I1', owner));
    await setDoc(doc(f, 'users/owner'), { id: owner, email: 'o@example.test', displayName: 'Olga' });
    await setDoc(doc(f, 'rateLimits/owner'), { joinFailures: [] });
    await setDoc(doc(f, 'shares/X'), { code: '123456' });
  });
});

describe('users', () => {
  test('eigenes Profil anlegen und ändern', async () => {
    await assertSucceeds(setDoc(doc(db(member), 'users/member'), { id: member, email: 'm@example.test' }));
    await assertSucceeds(updateDoc(doc(db(member), 'users/member'), { fcmToken: 't' }));
  });
  test('fremdes Profil schreiben verboten', async () => {
    await assertFails(setDoc(doc(db(stranger), 'users/owner'), { id: owner }));
    await assertFails(updateDoc(doc(db(stranger), 'users/owner'), { displayName: 'x' }));
    await assertFails(deleteDoc(doc(db(stranger), 'users/owner')));
  });
  test('einzelnes Profil lesen ja, auflisten nein, ohne Anmeldung nein', async () => {
    await assertSucceeds(getDoc(doc(db(member), 'users/owner')));
    await assertFails(getDocs(collection(db(member), 'users')));
    await assertFails(getDoc(doc(anon(), 'users/owner')));
  });
});

describe('lists', () => {
  test('Mitglieder lesen ihre Listen per allUserIds-Abfrage', async () => {
    const q = query(collection(db(member), 'lists'), where('allUserIds', 'array-contains', member));
    await assertSucceeds(getDocs(q));
    await assertSucceeds(getDoc(doc(db(member), 'lists/L1')));
  });
  test('Fremde lesen keine Liste und können nicht nach Code suchen', async () => {
    await assertFails(getDoc(doc(db(stranger), 'lists/L1')));
    const q = query(collection(db(stranger), 'lists'), where('shareCode', '==', '123456'));
    await assertFails(getDocs(q));
  });
  test('gelöschte Liste lesen ergibt „nicht vorhanden“ statt Fehler', async () => {
    const snap = await assertSucceeds(getDoc(doc(db(member), 'lists/GONE')));
    if (snap.exists()) throw new Error('sollte nicht existieren');
  });
  test('Anlegen am Client verboten (nur Function createList)', async () => {
    await assertFails(
      setDoc(doc(db(stranger), 'lists/NEW'), listData('NEW', { ownerId: stranger, memberIds: [], memberNames: [], allUserIds: [stranger] })),
    );
  });
  test('sich selbst per Update hinzufügen verboten', async () => {
    await assertFails(
      updateDoc(doc(db(stranger), 'lists/L1'), {
        memberIds: [member, stranger],
        memberNames: ['Max', 'Sam'],
        allUserIds: [owner, member, stranger],
      }),
    );
  });
  test('Mitglied verlässt Liste', async () => {
    await assertSucceeds(
      updateDoc(doc(db(member), 'lists/L1'), { memberIds: [], memberNames: [], allUserIds: [owner] }),
    );
  });
  test('Mitglied darf andere nicht entfernen oder umbenennen', async () => {
    await assertFails(updateDoc(doc(db(member), 'lists/L1'), { name: 'Neu' }));
    await assertFails(
      updateDoc(doc(db(viewer), 'lists/RO'), { memberIds: [viewer], memberNames: ['Vera'], allUserIds: [viewer] }),
    );
  });
  test('Besitzer ändert Name und entfernt Mitglied', async () => {
    await assertSucceeds(updateDoc(doc(db(owner), 'lists/L1'), { name: 'Neu' }));
    await assertSucceeds(
      updateDoc(doc(db(owner), 'lists/L1'), { memberIds: [], memberNames: [], allUserIds: [owner] }),
    );
  });
  test('Besitzer darf niemanden hinzufügen, Code/Besitz nicht ändern', async () => {
    await assertFails(
      updateDoc(doc(db(owner), 'lists/L1'), {
        memberIds: [member, stranger],
        memberNames: ['Max', 'Sam'],
        allUserIds: [owner, member, stranger],
      }),
    );
    await assertFails(updateDoc(doc(db(owner), 'lists/L1'), { shareCode: '000000' }));
    await assertFails(updateDoc(doc(db(owner), 'lists/L1'), { ownerId: member }));
  });
  test('nur Besitzer löscht', async () => {
    await assertFails(deleteDoc(doc(db(member), 'lists/L1')));
    await assertSucceeds(deleteDoc(doc(db(owner), 'lists/L1')));
  });
});

describe('todos', () => {
  test('Mitglied liest per listId-Abfrage, Fremder nicht', async () => {
    await assertSucceeds(getDocs(query(collection(db(member), 'todos'), where('listId', '==', 'L1'))));
    await assertFails(getDocs(query(collection(db(stranger), 'todos'), where('listId', '==', 'L1'))));
    await assertFails(getDoc(doc(db(stranger), 'todos/T1')));
  });
  test('eigene Todos per userId-Abfrage', async () => {
    await assertSucceeds(getDocs(query(collection(db(owner), 'todos'), where('userId', '==', owner))));
    await assertFails(getDocs(query(collection(db(stranger), 'todos'), where('userId', '==', owner))));
  });
  test('Mitglied mit allowEdit legt an, ändert, löscht', async () => {
    await assertSucceeds(setDoc(doc(db(member), 'todos/T2'), todoData('T2', member)));
    await assertSucceeds(updateDoc(doc(db(member), 'todos/T1'), { isCompleted: true, completedByUserId: member }));
    await assertSucceeds(deleteDoc(doc(db(member), 'todos/T1')));
  });
  test('Anlegen im Namen anderer oder in fremder Liste verboten', async () => {
    await assertFails(setDoc(doc(db(member), 'todos/T3'), todoData('T3', owner)));
    await assertFails(setDoc(doc(db(stranger), 'todos/T4'), todoData('T4', stranger)));
  });
  test('Todo in andere Liste verschieben verboten', async () => {
    await assertFails(updateDoc(doc(db(owner), 'todos/T1'), { listId: 'RO' }));
  });
  test('Mitglied ohne allowEdit darf lesen, aber nicht schreiben', async () => {
    await assertSucceeds(getDoc(doc(db(viewer), 'todos/TRO')));
    await assertFails(updateDoc(doc(db(viewer), 'todos/TRO'), { isCompleted: true }));
    await assertFails(setDoc(doc(db(viewer), 'todos/T5'), todoData('T5', viewer, 'RO')));
  });
});

describe('chatMessages', () => {
  const msg = (id, userId) => ({
    id,
    todoId: 'T1',
    userId,
    userName: 'Max',
    message: 'Hi',
    timestamp: now,
    isRead: false,
  });
  test('Mitglied liest und schreibt eigene Nachrichten', async () => {
    await assertSucceeds(getDocs(collection(db(member), 'todos/T1/chatMessages')));
    await assertSucceeds(setDoc(doc(db(member), 'todos/T1/chatMessages/M2'), msg('M2', member)));
  });
  test('Fremder liest nicht, niemand schreibt unter fremdem Namen', async () => {
    await assertFails(getDocs(collection(db(stranger), 'todos/T1/chatMessages')));
    await assertFails(setDoc(doc(db(stranger), 'todos/T1/chatMessages/M3'), msg('M3', stranger)));
    await assertFails(setDoc(doc(db(member), 'todos/T1/chatMessages/M4'), msg('M4', owner)));
  });
  test('gelesen markieren ja, Text ändern nein', async () => {
    await assertSucceeds(updateDoc(doc(db(member), 'todos/T1/chatMessages/M1'), { isRead: true }));
    await assertFails(updateDoc(doc(db(member), 'todos/T1/chatMessages/M1'), { message: 'gefälscht' }));
  });
});

describe('shopping_items', () => {
  test('Mitglied ohne allowEdit darf abhaken, aber nicht umbenennen oder löschen', async () => {
    await assertSucceeds(
      updateDoc(doc(db(viewer), 'shopping_items/I1'), { isPurchased: true, purchasedBy: 'Vera', purchasedAt: now }),
    );
    await assertFails(updateDoc(doc(db(viewer), 'shopping_items/I1'), { name: 'Bier' }));
    await assertFails(deleteDoc(doc(db(viewer), 'shopping_items/I1')));
    await assertFails(setDoc(doc(db(viewer), 'shopping_items/I2'), itemData('I2', viewer)));
  });
  test('Besitzer legt an und löscht, Fremder nichts', async () => {
    await assertSucceeds(setDoc(doc(db(owner), 'shopping_items/I3'), itemData('I3', owner)));
    await assertSucceeds(deleteDoc(doc(db(owner), 'shopping_items/I3')));
    await assertFails(getDoc(doc(db(stranger), 'shopping_items/I1')));
    await assertFails(getDocs(query(collection(db(stranger), 'shopping_items'), where('listId', '==', 'S1'))));
  });
});

describe('shopping_items bearbeiten (Scanner)', () => {
  test('Besitzer bearbeitet Name, Menge, Einheit, Notiz und Produktfelder', async () => {
    await assertSucceeds(
      updateDoc(doc(db(owner), 'shopping_items/I1'), {
        name: 'Hafermilch',
        quantity: 2,
        unit: 'Stück',
        notes: 'Bio',
        ean: '4008400202020',
        imageUrl: 'https://images.openfoodfacts.org/x.jpg',
      }),
    );
    // Produkt wieder lösen (Felder auf null).
    await assertSucceeds(updateDoc(doc(db(owner), 'shopping_items/I1'), { ean: null, imageUrl: null }));
  });
  test('Anlegen mit Strichcode und Bild erlaubt, Schlüsselfelder bleiben fest', async () => {
    await assertSucceeds(
      setDoc(doc(db(owner), 'shopping_items/I4'), {
        ...itemData('I4', owner),
        ean: '3017620422003',
        imageUrl: 'https://images.openfoodfacts.org/n.jpg',
      }),
    );
    await assertFails(updateDoc(doc(db(owner), 'shopping_items/I4'), { listId: 'L1' }));
    await assertFails(updateDoc(doc(db(owner), 'shopping_items/I4'), { userId: viewer }));
  });
  test('Mitglied ohne allowEdit darf Produktfelder nicht ändern', async () => {
    await assertFails(updateDoc(doc(db(viewer), 'shopping_items/I1'), { ean: '3017620422003' }));
    await assertFails(updateDoc(doc(db(viewer), 'shopping_items/I1'), { quantity: 5 }));
  });
});

const EAN = '3017620422003';
function produktData(extra = {}) {
  return {
    ean: EAN,
    name: 'Nutella',
    marke: 'Ferrero',
    menge: '400 g',
    bildUrl: 'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_de.jpg',
    quelle: 'off',
    aktualisiertAm: now,
    ...extra,
  };
}

describe('produkte (Strichcode-Zwischenspeicher)', () => {
  test('Angemeldete lesen und legen Open-Facts-Daten an, Fremde ohne Anmeldung nicht', async () => {
    await assertSucceeds(setDoc(doc(db(member), `produkte/${EAN}`), produktData()));
    await assertSucceeds(getDoc(doc(db(stranger), `produkte/${EAN}`)));
    await assertFails(getDoc(doc(anon(), `produkte/${EAN}`)));
    await assertFails(setDoc(doc(anon(), 'produkte/4008400202020'), produktData({ ean: '4008400202020' })));
  });
  test('Nutzer-Eintrag braucht Urheber; nur gültige Felder und Längen', async () => {
    await assertSucceeds(
      setDoc(doc(db(member), 'produkte/40084002'), {
        ean: '40084002', name: 'Hausmarke Müsli', marke: null, menge: null, bildUrl: null,
        quelle: 'nutzer', aktualisiertAm: now, erstelltVon: member,
      }),
    );
    // Urheber fehlt oder ist jemand anderes
    await assertFails(setDoc(doc(db(member), 'produkte/40084003'), produktData({ ean: '40084003', quelle: 'nutzer' })));
    await assertFails(setDoc(doc(db(member), 'produkte/40084004'), produktData({ ean: '40084004', quelle: 'nutzer', erstelltVon: owner })));
    // Dokument-ID muss zum Code passen und ein Strichcode sein
    await assertFails(setDoc(doc(db(member), 'produkte/abc'), produktData({ ean: 'abc' })));
    await assertFails(setDoc(doc(db(member), 'produkte/4008400202020'), produktData()));
    // Name leer / zu lang, unbekannte Quelle, Bild nicht https, Fremdfeld
    await assertFails(setDoc(doc(db(member), `produkte/${EAN}`), produktData({ name: '' })));
    await assertFails(setDoc(doc(db(member), `produkte/${EAN}`), produktData({ name: 'x'.repeat(121) })));
    await assertFails(setDoc(doc(db(member), `produkte/${EAN}`), produktData({ quelle: 'wiki' })));
    await assertFails(setDoc(doc(db(member), `produkte/${EAN}`), produktData({ bildUrl: 'http://x.test/a.jpg' })));
    await assertFails(setDoc(doc(db(member), `produkte/${EAN}`), produktData({ preis: 3.49 })));
  });
  test('Open-Facts-Daten werden nicht überschrieben, Nutzer-Einträge schon; Löschen nie', async () => {
    await assertSucceeds(setDoc(doc(db(member), `produkte/${EAN}`), produktData()));
    await assertFails(setDoc(doc(db(owner), `produkte/${EAN}`), produktData({ name: 'Quatsch' })));
    await assertFails(updateDoc(doc(db(owner), `produkte/${EAN}`), { name: 'Quatsch' }));
    await assertFails(deleteDoc(doc(db(owner), `produkte/${EAN}`)));

    await assertSucceeds(
      setDoc(doc(db(member), 'produkte/40084002'), {
        ean: '40084002', name: 'Müsli', marke: null, menge: null, bildUrl: null,
        quelle: 'nutzer', aktualisiertAm: now, erstelltVon: member,
      }),
    );
    // Korrektur durch anderen Nutzer (als eigener Nutzer-Eintrag) …
    await assertSucceeds(
      setDoc(doc(db(owner), 'produkte/40084002'), {
        ean: '40084002', name: 'Hausmarke Müsli', marke: null, menge: null, bildUrl: null,
        quelle: 'nutzer', aktualisiertAm: now, erstelltVon: owner,
      }),
    );
    // … oder Ersatz durch echte Open-Facts-Daten.
    await assertSucceeds(setDoc(doc(db(owner), 'produkte/40084002'), produktData({ ean: '40084002' })));
    await assertFails(deleteDoc(doc(db(member), 'produkte/40084002')));
  });
});

describe('gesperrte Sammlungen', () => {
  test('shares und rateLimits sind für Clients zu', async () => {
    await assertFails(getDoc(doc(db(owner), 'shares/X')));
    await assertFails(getDoc(doc(db(owner), 'rateLimits/owner')));
    await assertFails(setDoc(doc(db(owner), 'rateLimits/owner'), { joinFailures: [] }));
  });
});
