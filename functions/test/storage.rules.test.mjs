/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Storage-Regeltests (Anhänge an Aufgaben, Bilder im Chat) gegen den
// Storage- und Firestore-Emulator (Mitgliedschaft per firestore.get):
//   firebase emulators:exec --only firestore,storage --project demo-togetherdo \
//     "npm --prefix functions run test:storage"

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

const PROJECT_ID = 'demo-togetherdo';
const BUCKET = `${PROJECT_ID}.firebasestorage.app`;
const [fsHost, fsPort] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
const [stHost, stPort] = (process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199').split(':');

const owner = 'owner';
const member = 'member';
const viewer = 'viewer'; // Mitglied der Liste RO ohne allowEdit
const stranger = 'stranger';

let env;
const storage = (uid) => env.authenticatedContext(uid).storage(`gs://${BUCKET}`);
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const pdf = new TextEncoder().encode('%PDF-1.4\n%%EOF');
const meta = (uid, contentType) => ({ contentType, customMetadata: { uploadedBy: uid } });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: fsHost, port: Number(fsPort) },
    storage: {
      host: stHost,
      port: Number(stPort),
      rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'lists/L1'), {
      id: 'L1', ownerId: owner, memberIds: [member], allUserIds: [owner, member], allowEdit: true,
    });
    await setDoc(doc(f, 'lists/RO'), {
      id: 'RO', ownerId: owner, memberIds: [viewer], allUserIds: [owner, viewer], allowEdit: false,
    });
  });
});

describe('todos/{listId}/{todoId}/{datei}', () => {
  test('Mitglied lädt Bild und PDF hoch und liest', async () => {
    const r = ref(storage(member), 'todos/L1/T1/a.jpg');
    await assertSucceeds(uploadBytes(r, jpeg, meta(member, 'image/jpeg')));
    await assertSucceeds(uploadBytes(ref(storage(member), 'todos/L1/T1/b.pdf'), pdf, meta(member, 'application/pdf')));
    await assertSucceeds(getBytes(ref(storage(owner), 'todos/L1/T1/a.jpg')));
  });
  test('Mitglied ohne allowEdit darf anhängen (Liste RO)', async () => {
    await assertSucceeds(uploadBytes(ref(storage(viewer), 'todos/RO/T9/a.jpg'), jpeg, meta(viewer, 'image/jpeg')));
  });
  test('Fremder weder lesen noch hochladen', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(`gs://${BUCKET}`), 'todos/L1/T1/x.jpg'), jpeg, meta(owner, 'image/jpeg'));
    });
    await assertFails(getBytes(ref(storage(stranger), 'todos/L1/T1/x.jpg')));
    await assertFails(uploadBytes(ref(storage(stranger), 'todos/L1/T1/y.jpg'), jpeg, meta(stranger, 'image/jpeg')));
    await assertFails(uploadBytes(ref(storage(member), 'todos/RO/T1/y.jpg'), jpeg, meta(member, 'image/jpeg')));
  });
  test('falscher Typ, fremdes uploadedBy, fehlendes Metadatum', async () => {
    await assertFails(uploadBytes(ref(storage(member), 'todos/L1/T1/z.zip'), jpeg, meta(member, 'application/zip')));
    await assertFails(uploadBytes(ref(storage(member), 'todos/L1/T1/z.jpg'), jpeg, meta(owner, 'image/jpeg')));
    await assertFails(uploadBytes(ref(storage(member), 'todos/L1/T1/z2.jpg'), jpeg, { contentType: 'image/jpeg' }));
  });
  test('zu groß: Bild > 10 MB, PDF > 20 MB', async () => {
    const big = new Uint8Array(10 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(storage(member), 'todos/L1/T1/big.jpg'), big, meta(member, 'image/jpeg')));
    await assertSucceeds(uploadBytes(ref(storage(member), 'todos/L1/T1/big.pdf'), big, meta(member, 'application/pdf')));
    const huge = new Uint8Array(20 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(storage(member), 'todos/L1/T1/huge.pdf'), huge, meta(member, 'application/pdf')));
  });
  test('löschen: Urheber ja, Besitzer ja, anderes Mitglied ohne allowEdit nein', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const s = ctx.storage(`gs://${BUCKET}`);
      await uploadBytes(ref(s, 'todos/L1/T1/d1.jpg'), jpeg, meta(member, 'image/jpeg'));
      await uploadBytes(ref(s, 'todos/L1/T1/d2.jpg'), jpeg, meta(member, 'image/jpeg'));
      await uploadBytes(ref(s, 'todos/RO/T2/d3.jpg'), jpeg, meta(owner, 'image/jpeg'));
    });
    await assertSucceeds(deleteObject(ref(storage(member), 'todos/L1/T1/d1.jpg')));
    await assertSucceeds(deleteObject(ref(storage(owner), 'todos/L1/T1/d2.jpg')));
    await assertFails(deleteObject(ref(storage(viewer), 'todos/RO/T2/d3.jpg')));
    await assertFails(deleteObject(ref(storage(stranger), 'todos/RO/T2/d3.jpg')));
  });
  test('überschreiben verboten', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(`gs://${BUCKET}`), 'todos/L1/T1/o.jpg'), jpeg, meta(member, 'image/jpeg'));
    });
    await assertFails(uploadBytes(ref(storage(member), 'todos/L1/T1/o.jpg'), jpeg, meta(member, 'image/jpeg')));
  });
});

describe('chats/{listId}/{todoId}/{datei}', () => {
  test('Mitglied schickt Bild, kein PDF', async () => {
    await assertSucceeds(uploadBytes(ref(storage(member), 'chats/L1/T1/c.jpg'), jpeg, meta(member, 'image/jpeg')));
    await assertFails(uploadBytes(ref(storage(member), 'chats/L1/T1/c.pdf'), pdf, meta(member, 'application/pdf')));
  });
  test('Fremder nicht', async () => {
    await assertFails(uploadBytes(ref(storage(stranger), 'chats/L1/T1/s.jpg'), jpeg, meta(stranger, 'image/jpeg')));
  });
});

describe('übrige Pfade', () => {
  test('bleiben gesperrt', async () => {
    await assertFails(uploadBytes(ref(storage(owner), 'sonstiges/x.jpg'), jpeg, meta(owner, 'image/jpeg')));
  });
});
