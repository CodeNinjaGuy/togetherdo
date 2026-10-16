/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Listen anlegen, per Code ansehen/beitreten und beim Löschen aufräumen.
//
// Die Firestore-Regeln erlauben Nicht-Mitgliedern keinen Lesezugriff auf
// Listen. Darum laufen Codesuche und Beitritt hier auf dem Server, mit einer
// Drosselung je Nutzer gegen das Durchprobieren der 6-stelligen Codes.

import { randomInt } from 'crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { FieldValue } from 'firebase-admin/firestore';
import { db, REGION, requireAuth, deleteListContent } from './common';

/** Fehlversuche je Nutzer im Zeitfenster, danach `resource-exhausted`. */
export const JOIN_MAX_FAILURES = 10;
export const JOIN_WINDOW_MS = 60 * 60 * 1000;

const CODE_PATTERN = /^\d{6}$/;
const LIST_TYPES = ['todo', 'shopping'];

function generateCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function readCode(data: unknown): string {
  const code = String((data as { code?: unknown })?.code ?? '').trim();
  if (!CODE_PATTERN.test(code)) {
    throw new HttpsError('invalid-argument', 'Der Code muss 6 Ziffern haben');
  }
  return code;
}

/** Bricht ab, wenn der Nutzer im Zeitfenster zu viele Fehlversuche hatte. */
async function assertNotThrottled(uid: string): Promise<void> {
  const doc = await db.collection('rateLimits').doc(uid).get();
  const since = Date.now() - JOIN_WINDOW_MS;
  const failures = ((doc.data()?.joinFailures as number[] | undefined) ?? []).filter((t) => t > since);
  if (failures.length >= JOIN_MAX_FAILURES) {
    throw new HttpsError('resource-exhausted', 'Zu viele Versuche. Bitte später erneut probieren.');
  }
}

async function recordFailure(uid: string): Promise<void> {
  const ref = db.collection('rateLimits').doc(uid);
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const since = Date.now() - JOIN_WINDOW_MS;
    const failures = ((doc.data()?.joinFailures as number[] | undefined) ?? []).filter((t) => t > since);
    failures.push(Date.now());
    tx.set(ref, { joinFailures: failures.slice(-JOIN_MAX_FAILURES * 2) }, { merge: true });
  });
}

async function findListByCode(uid: string, code: string) {
  await assertNotThrottled(uid);
  const snap = await db.collection('lists').where('shareCode', '==', code).limit(1).get();
  if (snap.empty) {
    await recordFailure(uid);
    throw new HttpsError('not-found', 'Code nicht gefunden');
  }
  return snap.docs[0];
}

async function displayNameOf(uid: string, fallback: unknown): Promise<string> {
  const user = await db.collection('users').doc(uid).get();
  const name = user.data()?.displayName;
  if (typeof name === 'string' && name.trim()) return name.trim();
  if (typeof fallback === 'string' && fallback.trim()) return fallback.trim().slice(0, 100);
  return 'Unbekannt';
}

/** Legt eine Liste mit eindeutigem 6-stelligem Code an. */
export const createList = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  const data = (request.data ?? {}) as { name?: unknown; type?: unknown; allowEdit?: unknown; ownerName?: unknown };
  const name = typeof data.name === 'string' ? data.name.trim() : '';
  if (!name || name.length > 100) throw new HttpsError('invalid-argument', 'Ungültiger Name');
  const type = String(data.type ?? '');
  if (!LIST_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Ungültiger Listentyp');
  const allowEdit = data.allowEdit !== false;

  let code = '';
  for (let attempt = 0; attempt < 20 && !code; attempt++) {
    const candidate = generateCode();
    const existing = await db.collection('lists').where('shareCode', '==', candidate).limit(1).get();
    if (existing.empty) code = candidate;
  }
  if (!code) throw new HttpsError('unavailable', 'Kein freier Code gefunden');

  const ref = db.collection('lists').doc();
  const now = new Date().toISOString();
  const list = {
    id: ref.id,
    name,
    ownerId: uid,
    ownerName: await displayNameOf(uid, data.ownerName),
    type,
    createdAt: now,
    updatedAt: now,
    isShared: true,
    shareCode: code,
    memberIds: [] as string[],
    memberNames: [] as string[],
    allowEdit,
    allUserIds: [uid],
  };
  await ref.set(list);
  return list;
});

/** Zeigt zu einem Code nur das Nötigste (Name, Typ, Besitzer, Mitgliederzahl). */
export const previewListByCode = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  const code = readCode(request.data);
  const doc = await findListByCode(uid, code);
  const d = doc.data();
  const memberIds: string[] = d.memberIds ?? [];
  return {
    name: d.name,
    type: d.type,
    ownerName: d.ownerName ?? 'Unbekannt',
    memberCount: memberIds.length + 1,
    shareCode: code,
    isMember: d.ownerId === uid || memberIds.includes(uid),
  };
});

/** Tritt der Liste zum Code bei und liefert die vollständige Liste zurück. */
export const joinListByCode = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  const code = readCode(request.data);
  const found = await findListByCode(uid, code);
  const userName = await displayNameOf(uid, (request.data as { userName?: unknown })?.userName);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(found.ref);
    const d = snap.data();
    if (!snap.exists || !d || d.shareCode !== code) {
      throw new HttpsError('not-found', 'Code nicht gefunden');
    }
    const memberIds: string[] = d.memberIds ?? [];
    if (d.ownerId === uid || memberIds.includes(uid)) {
      throw new HttpsError('already-exists', 'Du bist bereits Mitglied');
    }
    const updated = {
      memberIds: [...memberIds, uid],
      memberNames: [...(d.memberNames ?? []), userName],
      allUserIds: FieldValue.arrayUnion(uid),
      updatedAt: new Date().toISOString(),
    };
    tx.update(found.ref, updated);
    return {
      ...d,
      ...updated,
      allUserIds: [...new Set([...(d.allUserIds ?? []), uid])],
    };
  });
});

/** Gelöschte Liste: Todos, Chats und Einkaufsartikel mitlöschen (keine Waisen). */
export const onListDeleted = onDocumentDeleted({ region: REGION, document: 'lists/{listId}' }, async (event) => {
  await deleteListContent(event.params.listId);
});
