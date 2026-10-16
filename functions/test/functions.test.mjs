/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Ende-zu-Ende-Tests der Functions gegen die Emulator Suite (nie Produktion):
//   cd functions && npm run build && npm run test:emulator

import assert from 'node:assert/strict';
import { before, after, describe, test } from 'node:test';
import { initializeApp as initClient, deleteApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';
import admin from 'firebase-admin';

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'demo-togetherdo';
const REGION = 'europe-west3';

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const clients = [];

/** Neuer Testnutzer mit eigenem Client (Auth + Functions am Emulator). */
async function newUser(name) {
  const app = initClient({ apiKey: 'demo-key', projectId: PROJECT_ID }, `app-${name}-${Date.now()}-${Math.random()}`);
  clients.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const functions = getFunctions(app, REGION);
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  const email = `${name.toLowerCase()}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.test`;
  const cred = await createUserWithEmailAndPassword(auth, email, 'geheim123');
  const uid = cred.user.uid;
  await db.doc(`users/${uid}`).set({ id: uid, email, displayName: name, fcmToken: `token-${uid}` });
  const call = (fn, data) => httpsCallable(functions, fn)(data).then((r) => r.data);
  return { uid, name, email, auth, call };
}

async function expectCode(promise, code) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, `functions/${code}`, `erwartet ${code}, bekommen ${e.code}: ${e.message}`);
    return true;
  });
}

async function eventually(check, timeoutMs = 15000) {
  const end = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < end) {
    try {
      await check();
      return;
    } catch (e) {
      lastError = e;
      await new Promise((r) => setTimeout(r, 300));
    }
  }
  throw lastError;
}

const exists = async (path) => (await db.doc(path).get()).exists;

before(async () => {
  // Emulator-Daten leeren (nur Emulator!).
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'nur gegen den Emulator ausführen');
});

after(async () => {
  await Promise.all(clients.map((a) => deleteApp(a)));
  await admin.app().delete();
});

describe('Listen und Beitritt per Code', () => {
  test('createList vergibt eindeutigen 6-stelligen Code', async () => {
    const olga = await newUser('Olga');
    const list = await olga.call('createList', { name: 'Haushalt', type: 'todo', allowEdit: true });
    assert.match(list.shareCode, /^\d{6}$/);
    assert.equal(list.ownerId, olga.uid);
    assert.equal(list.ownerName, 'Olga');
    assert.deepEqual(list.allUserIds, [olga.uid]);
    const stored = (await db.doc(`lists/${list.id}`).get()).data();
    assert.equal(stored.shareCode, list.shareCode);
    await expectCode(olga.call('createList', { name: '', type: 'todo' }), 'invalid-argument');
    await expectCode(olga.call('createList', { name: 'X', type: 'kaputt' }), 'invalid-argument');
  });

  test('Vorschau und Beitritt; doppelt beitreten wird abgelehnt', async () => {
    const olga = await newUser('Olga');
    const max = await newUser('Max');
    const list = await olga.call('createList', { name: 'Einkauf', type: 'shopping' });

    const preview = await max.call('previewListByCode', { code: list.shareCode });
    assert.equal(preview.name, 'Einkauf');
    assert.equal(preview.type, 'shopping');
    assert.equal(preview.ownerName, 'Olga');
    assert.equal(preview.memberCount, 1);
    assert.equal(preview.isMember, false);
    assert.equal(preview.memberIds, undefined, 'keine Mitglieder-IDs in der Vorschau');

    const joined = await max.call('joinListByCode', { code: list.shareCode });
    assert.deepEqual(joined.memberIds, [max.uid]);
    assert.deepEqual(joined.memberNames, ['Max']);
    const stored = (await db.doc(`lists/${list.id}`).get()).data();
    assert.deepEqual(stored.allUserIds.sort(), [olga.uid, max.uid].sort());

    await expectCode(max.call('joinListByCode', { code: list.shareCode }), 'already-exists');
    await expectCode(olga.call('joinListByCode', { code: list.shareCode }), 'already-exists');
  });

  test('Drosselung nach 10 Fehlversuchen, auch für richtige Codes', async () => {
    const olga = await newUser('Olga');
    const eve = await newUser('Eve');
    const list = await olga.call('createList', { name: 'Geheim', type: 'todo' });
    const wrong = list.shareCode === '000000' ? '000001' : '000000';
    // Falls zufällig ein anderer Testcode existiert: eigener, sicher freier Code.
    await db.doc(`lists/${list.id}`).update({ shareCode: '999999' });
    for (let i = 0; i < 10; i++) {
      await expectCode(eve.call('previewListByCode', { code: wrong === '999999' ? '000002' : wrong }), 'not-found');
    }
    await expectCode(eve.call('joinListByCode', { code: '999999' }), 'resource-exhausted');
    await expectCode(eve.call('previewListByCode', { code: '999999' }), 'resource-exhausted');
    // Andere Nutzer sind nicht betroffen.
    const max = await newUser('Max');
    const preview = await max.call('previewListByCode', { code: '999999' });
    assert.equal(preview.name, 'Geheim');
  });

  test('ungültige Eingaben und fehlende Anmeldung', async () => {
    const max = await newUser('Max');
    await expectCode(max.call('joinListByCode', { code: '12ab56' }), 'invalid-argument');
    await expectCode(max.call('joinListByCode', {}), 'invalid-argument');
    await max.auth.signOut();
    await expectCode(max.call('joinListByCode', { code: '123456' }), 'unauthenticated');
    await expectCode(max.call('createList', { name: 'X', type: 'todo' }), 'unauthenticated');
  });

  test('gelöschte Liste nimmt Todos, Chats und Artikel mit (onListDeleted)', async () => {
    const olga = await newUser('Olga');
    const list = await olga.call('createList', { name: 'Weg', type: 'todo' });
    await db.doc('todos/LD-T1').set({ id: 'LD-T1', listId: list.id, userId: olga.uid, title: 'x' });
    await db.doc('todos/LD-T1/chatMessages/m1').set({ id: 'm1', todoId: 'LD-T1', userId: olga.uid, message: 'hi' });
    await db.doc('shopping_items/LD-I1').set({ id: 'LD-I1', listId: list.id, userId: olga.uid, name: 'Milch' });
    await db.doc(`lists/${list.id}`).delete();
    await eventually(async () => {
      assert.equal(await exists('todos/LD-T1'), false);
      assert.equal(await exists('todos/LD-T1/chatMessages/m1'), false);
      assert.equal(await exists('shopping_items/LD-I1'), false);
    });
  });
});

describe('Kontolöschung', () => {
  test('deleteAccount räumt alles auf und löscht das Konto zuletzt', async () => {
    const anna = await newUser('Anna'); // wird gelöscht
    const ben = await newUser('Ben');
    const cleo = await newUser('Cleo');

    // Annas geteilte Liste (Ben + Cleo Mitglieder) → Besitz geht an Ben.
    const shared = await anna.call('createList', { name: 'WG', type: 'todo' });
    await ben.call('joinListByCode', { code: shared.shareCode });
    await cleo.call('joinListByCode', { code: shared.shareCode });
    // Annas private Liste → wird gelöscht.
    const solo = await anna.call('createList', { name: 'Privat', type: 'shopping' });
    // Bens Liste, Anna ist Mitglied.
    const bens = await ben.call('createList', { name: 'Bens', type: 'todo' });
    await anna.call('joinListByCode', { code: bens.shareCode });

    await db.doc('todos/A-own').set({ id: 'A-own', listId: bens.id, userId: anna.uid, title: 'Annas Todo' });
    await db.doc('todos/A-own/chatMessages/c1').set({ id: 'c1', todoId: 'A-own', userId: ben.uid, message: 'zu Annas Todo' });
    await db.doc('todos/B-todo').set({
      id: 'B-todo', listId: bens.id, userId: ben.uid, title: 'Bens Todo',
      assignedToUserId: anna.uid, assignedToUserName: 'Anna',
      isCompleted: true, completedByUserId: anna.uid, completedByUserName: 'Anna',
    });
    await db.doc('todos/B-todo/chatMessages/a1').set({ id: 'a1', todoId: 'B-todo', userId: anna.uid, message: 'von Anna' });
    await db.doc('todos/B-todo/chatMessages/b1').set({ id: 'b1', todoId: 'B-todo', userId: ben.uid, message: 'von Ben' });
    await db.doc('shopping_items/A-item').set({ id: 'A-item', listId: solo.id, userId: anna.uid, name: 'Brot' });
    await db.doc('shopping_items/A-item2').set({ id: 'A-item2', listId: bens.id, userId: anna.uid, name: 'Käse' });
    await db.doc('todos/S-todo').set({ id: 'S-todo', listId: solo.id, userId: anna.uid, title: 'privat' });
    await db.doc(`rateLimits/${anna.uid}`).set({ joinFailures: [Date.now()] });
    const avatar = admin.storage().bucket(`${PROJECT_ID}.firebasestorage.app`).file(`avatars/${anna.uid}.jpg`);
    await avatar.save(Buffer.from([0xff, 0xd8, 0xff, 0xd9]), { contentType: 'image/jpeg' });

    // Frisch anmelden (wie die App vor dem Löschen) und löschen.
    await signInWithEmailAndPassword(anna.auth, anna.email, 'geheim123');
    const res = await anna.call('deleteAccount', {});
    assert.deepEqual(res, { deleted: true });

    // Auth-Konto weg.
    await assert.rejects(admin.auth().getUser(anna.uid), (e) => e.code === 'auth/user-not-found');
    // Profilbild weg.
    assert.equal((await avatar.exists())[0], false);
    // Profil (inkl. FCM-Token) und Drosselung weg.
    assert.equal(await exists(`users/${anna.uid}`), false);
    assert.equal(await exists(`rateLimits/${anna.uid}`), false);
    // Private Liste samt Inhalt weg.
    assert.equal(await exists(`lists/${solo.id}`), false);
    assert.equal(await exists('shopping_items/A-item'), false);
    assert.equal(await exists('todos/S-todo'), false);
    // Geteilte Liste gehört jetzt Ben, Cleo bleibt Mitglied.
    const wg = (await db.doc(`lists/${shared.id}`).get()).data();
    assert.equal(wg.ownerId, ben.uid);
    assert.equal(wg.ownerName, 'Ben');
    assert.deepEqual(wg.memberIds, [cleo.uid]);
    assert.deepEqual(wg.memberNames, ['Cleo']);
    assert.deepEqual(wg.allUserIds, [ben.uid, cleo.uid]);
    // Aus Bens Liste ausgetreten (Name per Index entfernt).
    const bl = (await db.doc(`lists/${bens.id}`).get()).data();
    assert.deepEqual(bl.memberIds, []);
    assert.deepEqual(bl.memberNames, []);
    assert.deepEqual(bl.allUserIds, [ben.uid]);
    // Eigene Inhalte in fremden Listen weg, fremde bleiben.
    assert.equal(await exists('todos/A-own'), false);
    assert.equal(await exists('todos/A-own/chatMessages/c1'), false);
    assert.equal(await exists('shopping_items/A-item2'), false);
    assert.equal(await exists('todos/B-todo/chatMessages/a1'), false);
    assert.equal(await exists('todos/B-todo/chatMessages/b1'), true);
    const bt = (await db.doc('todos/B-todo').get()).data();
    assert.equal(bt.assignedToUserId, null);
    assert.equal(bt.assignedToUserName, null);
    assert.equal(bt.completedByUserName, null);
    assert.equal(bt.isCompleted, true);
  });

  test('ohne Anmeldung kein Löschen', async () => {
    const max = await newUser('Max');
    await max.auth.signOut();
    await expectCode(max.call('deleteAccount', {}), 'unauthenticated');
    assert.ok(await admin.auth().getUser(max.uid));
  });

  test('Konto anders gelöscht → onUserDeleted räumt nach (wiederholbar)', async () => {
    const zoe = await newUser('Zoe');
    const list = await zoe.call('createList', { name: 'Zoes', type: 'todo' });
    await db.doc('todos/Z-1').set({ id: 'Z-1', listId: list.id, userId: zoe.uid, title: 'x' });
    await admin.auth().deleteUser(zoe.uid);
    await eventually(async () => {
      assert.equal(await exists(`users/${zoe.uid}`), false);
      assert.equal(await exists(`lists/${list.id}`), false);
      assert.equal(await exists('todos/Z-1'), false);
    }, 30000);
  });
});

describe('Test-Push', () => {
  test('nur angemeldet und nur an das eigene Gerät', async () => {
    const max = await newUser('Max');
    const olga = await newUser('Olga');
    await expectCode(max.call('sendTestNotification', { fcmToken: `token-${olga.uid}` }), 'permission-denied');
    await max.auth.signOut();
    await expectCode(max.call('sendTestNotification', { fcmToken: `token-${max.uid}` }), 'unauthenticated');
  });
});
