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
  serverTimestamp,
  setDoc,
  Timestamp,
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
  test('Mitglied ohne allowEdit darf lesen und abhaken, aber nicht bearbeiten', async () => {
    await assertSucceeds(getDoc(doc(db(viewer), 'todos/TRO')));
    await assertFails(updateDoc(doc(db(viewer), 'todos/TRO'), { title: 'anders' }));
    await assertFails(updateDoc(doc(db(viewer), 'todos/TRO'), { effort: 'light' }));
    await assertFails(updateDoc(doc(db(viewer), 'todos/TRO'), { assignedToUserId: viewer }));
    await assertFails(setDoc(doc(db(viewer), 'todos/T5'), todoData('T5', viewer, 'RO')));
    await assertSucceeds(
      updateDoc(doc(db(viewer), 'todos/TRO'), {
        isCompleted: true,
        completedByUserId: viewer,
        completedByUserName: 'Vera',
        completedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(db(viewer), 'todos/TRO'), {
        isCompleted: false,
        completedByUserId: null,
        completedByUserName: null,
        completedAt: null,
      }),
    );
  });
});

describe('todos – fair verteilt', () => {
  test('Aufwand nur leicht/mittel/schwer', async () => {
    for (const effort of ['light', 'medium', 'heavy']) {
      await assertSucceeds(setDoc(doc(db(member), `todos/E-${effort}`), { ...todoData(`E-${effort}`, member), effort }));
    }
    await assertFails(setDoc(doc(db(member), 'todos/E-x'), { ...todoData('E-x', member), effort: 'riesig' }));
    await assertFails(setDoc(doc(db(member), 'todos/E-n'), { ...todoData('E-n', member), effort: 5 }));
    await assertSucceeds(updateDoc(doc(db(member), 'todos/T1'), { effort: 'heavy' }));
    await assertFails(updateDoc(doc(db(member), 'todos/T1'), { effort: 'extrem' }));
  });
  test('ohne Aufwand anlegen bleibt erlaubt (gilt als mittel)', async () => {
    await assertSucceeds(setDoc(doc(db(member), 'todos/E-none'), todoData('E-none', member)));
  });
  test('zuständig nur Mitglieder der Liste', async () => {
    await assertSucceeds(
      setDoc(doc(db(owner), 'todos/A1'), { ...todoData('A1', owner), assignedToUserId: member, assignedToUserName: 'Max' }),
    );
    await assertFails(
      setDoc(doc(db(owner), 'todos/A2'), { ...todoData('A2', owner), assignedToUserId: stranger }),
    );
    await assertSucceeds(updateDoc(doc(db(owner), 'todos/T1'), { assignedToUserId: member, assignedToUserName: 'Max' }));
    await assertFails(updateDoc(doc(db(owner), 'todos/T1'), { assignedToUserId: stranger }));
    await assertSucceeds(updateDoc(doc(db(owner), 'todos/T1'), { assignedToUserId: null, assignedToUserName: null }));
  });
  test('Bearbeiten (Titel, Fälligkeit, Zuständig, Aufwand) mit allowEdit', async () => {
    await assertSucceeds(
      updateDoc(doc(db(member), 'todos/T1'), {
        title: 'Müll und Glas raus',
        description: 'Dienstag',
        dueDate: '2026-10-20T18:00:00.000',
        assignedToUserId: owner,
        assignedToUserName: 'Olga',
        effort: 'light',
      }),
    );
  });
  test('erledigt-von nur die eigene uid', async () => {
    await assertFails(
      updateDoc(doc(db(member), 'todos/T1'), { isCompleted: true, completedByUserId: owner, completedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(doc(db(viewer), 'todos/TRO'), { isCompleted: true, completedByUserId: owner }));
    await assertSucceeds(
      updateDoc(doc(db(member), 'todos/T1'), {
        isCompleted: true,
        completedByUserId: member,
        completedByUserName: 'Max',
        completedAt: serverTimestamp(),
      }),
    );
  });
  test('Erledigt-Zeit nur Serverzeit, kein Zurückdatieren', async () => {
    const past = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
    await assertFails(
      updateDoc(doc(db(member), 'todos/T1'), { isCompleted: true, completedByUserId: member, completedAt: past }),
    );
    await assertFails(
      setDoc(doc(db(member), 'todos/C1'), {
        ...todoData('C1', member),
        isCompleted: true,
        completedByUserId: member,
        completedAt: past,
      }),
    );
    // Serverzeit, aber im Namen eines anderen bzw. ohne erledigt: nein
    await assertFails(
      updateDoc(doc(db(owner), 'todos/T1'), { isCompleted: false, completedByUserId: owner, completedAt: serverTimestamp() }),
    );
  });
  test('Bearbeiten lässt Erledigt-Angaben anderer unverändert stehen', async () => {
    await assertSucceeds(
      updateDoc(doc(db(member), 'todos/T1'), {
        isCompleted: true,
        completedByUserId: member,
        completedByUserName: 'Max',
        completedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(updateDoc(doc(db(owner), 'todos/T1'), { title: 'Neu', effort: 'heavy' }));
    // Besitzer öffnet wieder
    await assertSucceeds(
      updateDoc(doc(db(owner), 'todos/T1'), {
        isCompleted: false,
        completedByUserId: null,
        completedByUserName: null,
        completedAt: null,
      }),
    );
  });
  test('ältere App-Version: Abhaken ohne completedAt bleibt möglich', async () => {
    await assertSucceeds(
      updateDoc(doc(db(member), 'todos/T1'), { isCompleted: true, completedByUserId: member, completedByUserName: 'Max' }),
    );
    // altes Wieder-Öffnen ließ completedByUserId stehen
    await assertSucceeds(updateDoc(doc(db(member), 'todos/T1'), { isCompleted: false }));
  });
  test('Statistik-Abfrage (listId + completedAt) für Mitglieder, nicht für Fremde', async () => {
    const since = Timestamp.fromDate(new Date('2026-10-01T00:00:00Z'));
    await assertSucceeds(
      getDocs(query(collection(db(viewer), 'todos'), where('listId', '==', 'RO'), where('completedAt', '>=', since))),
    );
    await assertFails(
      getDocs(query(collection(db(stranger), 'todos'), where('listId', '==', 'RO'), where('completedAt', '>=', since))),
    );
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

describe('gesperrte Sammlungen', () => {
  test('shares und rateLimits sind für Clients zu', async () => {
    await assertFails(getDoc(doc(db(owner), 'shares/X')));
    await assertFails(getDoc(doc(db(owner), 'rateLimits/owner')));
    await assertFails(setDoc(doc(db(owner), 'rateLimits/owner'), { joinFailures: [] }));
  });
});
