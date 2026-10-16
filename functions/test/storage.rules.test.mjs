/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Regeltests für storage.rules gegen Storage- und Firestore-Emulator
// (nie Produktion). Firestore liefert die Mitgliedschaft (lists/{id}).
//   npm --prefix functions run test:storage
// Ports: Firestore 8091, Storage 9198 (eigene Konfiguration im Scratchpad),
// überschreibbar über FIRESTORE_EMULATOR_HOST / FIREBASE_STORAGE_EMULATOR_HOST.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import {
  deleteObject,
  getBytes,
  getMetadata,
  ref,
  uploadBytes,
} from 'firebase/storage';

const PROJECT_ID = 'demo-togetherdo-storage';
const [fsHost, fsPort] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8091').split(':');
const [stHost, stPort] = (process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9198').split(':');

let env;

const owner = 'owner';
const member = 'member'; // Mitglied von L1 (allowEdit: true)
const viewer = 'viewer'; // Mitglied von RO (allowEdit: false)
const stranger = 'stranger';

const MB = 1024 * 1024;
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

const st = (uid) => env.authenticatedContext(uid).storage();
const anon = () => env.unauthenticatedContext().storage();

/** Datei mit korrekten Metadaten hochladen. */
function upload(storage, path, { uid, size = 16, contentType = 'image/jpeg', metadata } = {}) {
  const meta = {
    contentType,
    customMetadata: metadata === null ? undefined : { hochgeladenVon: uid, name: 'datei', ...(metadata ?? {}) },
  };
  return uploadBytes(ref(storage, path), new Uint8Array(size), meta);
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: fsHost,
      port: Number(fsPort),
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
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
    const s = ctx.storage();
    await upload(s, 'termine/L1/T1/vonOwner', { uid: owner });
    await upload(s, 'termine/L1/T1/vonOwner_vorschau.jpg', { uid: owner });
    await upload(s, 'termine/L1/T1/vonMember', { uid: member, contentType: 'application/pdf' });
    await upload(s, 'termine/RO/TRO/vonOwner', { uid: owner });
  });
});

describe('termine – lesen', () => {
  test('Mitglied liest Datei und Vorschau', async () => {
    await assertSucceeds(getBytes(ref(st(member), 'termine/L1/T1/vonOwner')));
    await assertSucceeds(getMetadata(ref(st(member), 'termine/L1/T1/vonOwner_vorschau.jpg')));
  });
  test('Besitzer liest', async () => {
    await assertSucceeds(getBytes(ref(st(owner), 'termine/L1/T1/vonMember')));
  });
  test('Nur-Lese-Mitglied liest', async () => {
    await assertSucceeds(getBytes(ref(st(viewer), 'termine/RO/TRO/vonOwner')));
  });
  test('Fremder und Unangemeldete lesen nicht', async () => {
    await assertFails(getBytes(ref(st(stranger), 'termine/L1/T1/vonOwner')));
    await assertFails(getBytes(ref(anon(), 'termine/L1/T1/vonOwner')));
  });
  test('Mitglied einer anderen Liste liest nicht', async () => {
    await assertFails(getBytes(ref(st(viewer), 'termine/L1/T1/vonOwner')));
  });
});

describe('termine – hochladen', () => {
  test('Mitglied lädt Bild und PDF hoch', async () => {
    await assertSucceeds(upload(st(member), 'termine/L1/T1/neu1', { uid: member }));
    await assertSucceeds(
      upload(st(member), 'termine/L1/T1/neu2', { uid: member, contentType: 'application/pdf' }),
    );
    await assertSucceeds(
      upload(st(member), 'termine/L1/T1/neu3', { uid: member, contentType: 'image/heic' }),
    );
    await assertSucceeds(
      upload(st(member), 'termine/L1/T1/neu4', { uid: member, contentType: 'text/calendar' }),
    );
  });
  test('Nur-Lese-Mitglied darf anhängen', async () => {
    await assertSucceeds(upload(st(viewer), 'termine/RO/TRO/neu', { uid: viewer }));
  });
  test('Fremder lädt nicht hoch', async () => {
    await assertFails(upload(st(stranger), 'termine/L1/T1/neu', { uid: stranger }));
    await assertFails(upload(anon(), 'termine/L1/T1/neu', { uid: 'x' }));
  });
  test('falscher oder fehlender hochgeladenVon', async () => {
    await assertFails(upload(st(member), 'termine/L1/T1/neu', { uid: owner }));
    await assertFails(upload(st(member), 'termine/L1/T1/neu', { uid: member, metadata: null }));
  });
  test('zu groß: Bild über 10 MB, Dokument über 20 MB', async () => {
    await assertFails(upload(st(member), 'termine/L1/T1/gross1', { uid: member, size: 10 * MB + 1 }));
    await assertSucceeds(
      upload(st(member), 'termine/L1/T1/gross2', {
        uid: member,
        size: 10 * MB + 1,
        contentType: 'application/pdf',
      }),
    );
    await assertFails(
      upload(st(member), 'termine/L1/T1/gross3', {
        uid: member,
        size: 20 * MB + 1,
        contentType: 'application/pdf',
      }),
    );
  });
  test('falscher Typ', async () => {
    await assertFails(upload(st(member), 'termine/L1/T1/zip', { uid: member, contentType: 'application/zip' }));
    await assertFails(upload(st(member), 'termine/L1/T1/html', { uid: member, contentType: 'text/html' }));
    await assertFails(upload(st(member), 'termine/L1/T1/gif', { uid: member, contentType: 'image/gif' }));
  });
  test('Überschreiben verboten', async () => {
    await assertFails(upload(st(owner), 'termine/L1/T1/vonOwner', { uid: owner }));
    await assertFails(upload(st(member), 'termine/L1/T1/vonMember', { uid: member }));
  });
  test('unbekannte Liste', async () => {
    await assertFails(upload(st(member), 'termine/GONE/T1/neu', { uid: member }));
  });
});

describe('termine – löschen', () => {
  test('Hochlader löscht eigenes', async () => {
    await assertSucceeds(deleteObject(ref(st(member), 'termine/L1/T1/vonMember')));
  });
  test('Besitzer löscht fremdes', async () => {
    await assertSucceeds(deleteObject(ref(st(owner), 'termine/L1/T1/vonMember')));
  });
  test('Mitglied mit Bearbeitungsrecht löscht fremdes', async () => {
    await assertSucceeds(deleteObject(ref(st(member), 'termine/L1/T1/vonOwner')));
    await assertSucceeds(deleteObject(ref(st(member), 'termine/L1/T1/vonOwner_vorschau.jpg')));
  });
  test('Nur-Lese-Mitglied löscht fremdes nicht', async () => {
    await assertFails(deleteObject(ref(st(viewer), 'termine/RO/TRO/vonOwner')));
  });
  test('Nur-Lese-Mitglied löscht eigenes', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      upload(ctx.storage(), 'termine/RO/TRO/vonViewer', { uid: viewer }),
    );
    await assertSucceeds(deleteObject(ref(st(viewer), 'termine/RO/TRO/vonViewer')));
  });
  test('Fremder löscht nicht', async () => {
    await assertFails(deleteObject(ref(st(stranger), 'termine/L1/T1/vonOwner')));
    await assertFails(deleteObject(ref(anon(), 'termine/L1/T1/vonOwner')));
  });
});

describe('avatars', () => {
  test('eigenes Profilbild schreiben, lesen, löschen', async () => {
    await assertSucceeds(
      uploadBytes(ref(st(owner), 'avatars/owner.jpg'), new Uint8Array(16), { contentType: 'image/jpeg' }),
    );
    await assertSucceeds(getBytes(ref(st(member), 'avatars/owner.jpg')));
    await assertFails(getBytes(ref(anon(), 'avatars/owner.jpg')));
    await assertSucceeds(deleteObject(ref(st(owner), 'avatars/owner.jpg')));
  });
  test('fremdes Profilbild schreiben verboten', async () => {
    await assertFails(
      uploadBytes(ref(st(stranger), 'avatars/owner.jpg'), new Uint8Array(16), { contentType: 'image/jpeg' }),
    );
  });
});

describe('sonstige Pfade', () => {
  test('bleiben gesperrt', async () => {
    await assertFails(
      uploadBytes(ref(st(owner), 'sonstiges/x.jpg'), new Uint8Array(16), { contentType: 'image/jpeg' }),
    );
    await assertFails(getBytes(ref(st(owner), 'sonstiges/x.jpg')));
  });
});
