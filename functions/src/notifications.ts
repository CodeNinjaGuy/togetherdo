/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Cloud Functions für ToGetherDo (Region europe-west3).
//
// Diese Quelle bildet das Verhalten der zuletzt ausgerollten Fassung
// (`functions/lib/index.js`, Stand 2025-07-13) eins zu eins nach:
// Mitglieder kommen aus `lists/{id}.allUserIds`, Chat-Nachrichten liegen unter
// `todos/{todoId}/chatMessages`, Push nur bei eingeschalteter Einstellung.

import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const NotificationTypes = {
  TODO_CREATED: 'todo_created',
  TODO_COMPLETED: 'todo_completed',
  TODO_DELETED: 'todo_deleted',
  MEMBER_ADDED: 'member_added',
  MEMBER_REMOVED: 'member_removed',
  CHAT_MESSAGE: 'chat_message',
  TEST: 'test',
  SHOPPING_ITEM_CREATED: 'shoppingItemCreated',
  SHOPPING_ITEM_PURCHASED: 'shoppingItemPurchased',
  SHOPPING_ITEM_DELETED: 'shoppingItemDeleted',
  SHOPPING_MEMBER_ADDED: 'shoppingMemberAdded',
  SHOPPING_MEMBER_REMOVED: 'shoppingMemberRemoved',
} as const;

type NotificationType = (typeof NotificationTypes)[keyof typeof NotificationTypes];

const defaultSettings: Record<string, boolean> = Object.fromEntries(
  Object.values(NotificationTypes).map((key) => [key, true]),
);

const log = {
  info: (...args: unknown[]) => console.log('ℹ️', ...args),
  warn: (...args: unknown[]) => console.warn('⚠️', ...args),
  error: (...args: unknown[]) => console.error('🚨', ...args),
};

interface NotificationContent {
  title: string;
  body: string;
}

interface NotificationPayload {
  notification: NotificationContent;
  data: Record<string, string>;
}

async function getListMembers(listId: string): Promise<string[]> {
  const doc = await db.collection('lists').doc(listId).get();
  if (!doc.exists) return [];
  return doc.data()?.allUserIds || [];
}

async function getFilteredMemberTokens(
  members: string[],
  exclude: string[] = [],
  notificationType: NotificationType,
): Promise<string[]> {
  const filtered = members.filter((id) => !exclude.includes(id));
  if (!filtered.length) return [];

  const chunks: string[][] = [];
  for (let i = 0; i < filtered.length; i += 10) chunks.push(filtered.slice(i, i + 10));

  const tokens: string[] = [];
  for (const chunk of chunks) {
    const snap = await db
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();

    snap.forEach((doc) => {
      const data = doc.data();
      const fcmToken = data?.fcmToken;
      const allowed = data?.notificationSettings?.[notificationType] ?? defaultSettings[notificationType];
      if (!fcmToken || !allowed) return;
      tokens.push(fcmToken);
    });
  }
  return tokens;
}

async function sendNotification(
  members: string[],
  exclude: string[],
  payload: NotificationPayload,
  notificationType: NotificationType,
): Promise<void> {
  const tokens = await getFilteredMemberTokens(members, exclude, notificationType);
  if (!tokens.length) return;

  const batches: string[][] = [];
  for (let i = 0; i < tokens.length; i += 500) batches.push(tokens.slice(i, i + 500));

  await Promise.all(
    batches.map(async (batch) => {
      const message: admin.messaging.MulticastMessage = {
        notification: payload.notification,
        data: payload.data,
        android: {
          notification: {
            ...payload.notification,
            sound: 'notification_sound',
            channelId: 'togetherdo_channel',
            priority: 'high',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: {
            aps: {
              alert: payload.notification,
              sound: 'notification_sound.aiff',
              badge: 1,
              'interruption-level': 'time-sensitive',
            },
          },
        },
        tokens: batch,
      };

      const response = await messaging.sendEachForMulticast(message);
      response.responses.forEach((r, i) => {
        if (r.success) log.info(`✅ an ${batch[i]}`);
        else log.error(`❌ bei ${batch[i]}:`, r.error?.message);
      });
    }),
  );
}

interface EventArgs {
  members: string[];
  exclude: string[];
  title: string;
  body: string;
  type: NotificationType;
  data: Record<string, string>;
}

async function handleEvent({ members, exclude, title, body, type, data }: EventArgs): Promise<void> {
  const note = { title, body };
  await sendNotification(members, exclude, { notification: note, data }, type);
}

export const onTodoCreated = onDocumentCreated({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { userId, listId, title, assignedToUserId } = d;
  const members = await getListMembers(listId);
  const targets = assignedToUserId ? [assignedToUserId] : members;
  const exclude = assignedToUserId ? [] : [userId];
  await handleEvent({
    members: targets,
    exclude,
    title: 'Neues Todo',
    body: `${title} wurde ${assignedToUserId ? 'dir zugewiesen' : 'erstellt'}`,
    type: NotificationTypes.TODO_CREATED,
    data: { type: NotificationTypes.TODO_CREATED, todoId: event.params.todoId, listId, createdBy: userId },
  });
});

export const onTodoCompleted = onDocumentUpdated({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  if (!before.isCompleted && after.isCompleted) {
    const { listId, title, completedByUserId, userId } = after;
    const members = await getListMembers(listId);
    await handleEvent({
      members,
      exclude: [completedByUserId || userId],
      title: 'Todo erledigt',
      body: `${title} wurde als erledigt markiert`,
      type: NotificationTypes.TODO_COMPLETED,
      data: { type: NotificationTypes.TODO_COMPLETED, todoId: event.params.todoId, listId, completedBy: completedByUserId || userId },
    });
  }
});

export const onTodoDeleted = onDocumentDeleted({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { deletedByUserId, userId, listId, title } = d;
  const members = await getListMembers(listId);
  await handleEvent({
    members,
    exclude: [deletedByUserId || userId],
    title: 'Todo gelöscht',
    body: `${title} wurde gelöscht`,
    type: NotificationTypes.TODO_DELETED,
    data: { type: NotificationTypes.TODO_DELETED, todoId: event.params.todoId, listId, deletedBy: deletedByUserId || userId },
  });
});

export const onListMemberAdded = onDocumentUpdated({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const newMembers: string[] = (after.allUserIds || []).filter((m: string) => !(before.allUserIds || []).includes(m));
  if (!newMembers.length) return;
  await handleEvent({
    members: before.allUserIds || [],
    exclude: newMembers,
    title: 'Neuer Member',
    body: `${newMembers.length} neuer Member ist beigetreten`,
    type: NotificationTypes.MEMBER_ADDED,
    data: { type: NotificationTypes.MEMBER_ADDED, listId: event.params.listId, newMembers: newMembers.join(',') },
  });
});

export const onListMemberRemoved = onDocumentUpdated({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const removed: string[] = (before.allUserIds || []).filter((m: string) => !(after.allUserIds || []).includes(m));
  if (!removed.length) return;
  await handleEvent({
    members: after.allUserIds || [],
    exclude: removed,
    title: 'Member entfernt',
    body: `${removed.length} Member hat die Liste verlassen`,
    type: NotificationTypes.MEMBER_REMOVED,
    data: { type: NotificationTypes.MEMBER_REMOVED, listId: event.params.listId, removedMembers: removed.join(',') },
  });
});

export const onChatMessageCreated = onDocumentCreated(
  { region: 'europe-west3', document: 'todos/{todoId}/chatMessages/{messageId}' },
  async (event) => {
    const d = event.data?.data();
    if (!d) return;
    const { userId, userName, message } = d;
    const todoId = event.params.todoId;
    const todo = await db.collection('todos').doc(todoId).get();
    if (!todo.exists) return;
    const listId = todo.data()?.listId;
    const members = await getListMembers(listId);
    await handleEvent({
      members,
      exclude: [userId],
      title: `💬 ${userName}`,
      body: message.length > 50 ? message.slice(0, 50) + '...' : message,
      type: NotificationTypes.CHAT_MESSAGE,
      data: {
        type: NotificationTypes.CHAT_MESSAGE,
        messageId: event.params.messageId,
        todoId,
        listId,
        senderId: userId,
        senderName: userName,
      },
    });
  },
);

export const onShoppingItemCreated = onDocumentCreated({ region: 'europe-west3', document: 'shopping_items/{itemId}' }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { userId, listId, name, assignedToUserId } = d;
  const members = await getListMembers(listId);
  const targets = assignedToUserId ? [assignedToUserId] : members;
  const exclude = assignedToUserId ? [] : [userId];
  await handleEvent({
    members: targets,
    exclude,
    title: 'Neues Einkaufsitem',
    body: `${name} wurde ${assignedToUserId ? 'dir zugewiesen' : 'hinzugefügt'}`,
    type: NotificationTypes.SHOPPING_ITEM_CREATED,
    data: { type: NotificationTypes.SHOPPING_ITEM_CREATED, itemId: event.params.itemId, listId, createdBy: userId },
  });
});

export const onShoppingItemPurchased = onDocumentUpdated({ region: 'europe-west3', document: 'shopping_items/{itemId}' }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  if (!before.isPurchased && after.isPurchased) {
    const { listId, name, purchasedByUserId, userId } = after;
    const members = await getListMembers(listId);
    await handleEvent({
      members,
      exclude: [purchasedByUserId || userId],
      title: 'Einkaufsitem erledigt',
      body: `${name} wurde als erledigt/gekauft markiert`,
      type: NotificationTypes.SHOPPING_ITEM_PURCHASED,
      data: { type: NotificationTypes.SHOPPING_ITEM_PURCHASED, itemId: event.params.itemId, listId, purchasedBy: purchasedByUserId || userId },
    });
  }
});

export const onShoppingItemDeleted = onDocumentDeleted({ region: 'europe-west3', document: 'shopping_items/{itemId}' }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { deletedByUserId, userId, listId, name } = d;
  const members = await getListMembers(listId);
  await handleEvent({
    members,
    exclude: [deletedByUserId || userId],
    title: 'Einkaufsitem gelöscht',
    body: `${name} wurde gelöscht`,
    type: NotificationTypes.SHOPPING_ITEM_DELETED,
    data: { type: NotificationTypes.SHOPPING_ITEM_DELETED, itemId: event.params.itemId, listId, deletedBy: deletedByUserId || userId },
  });
});

export const onShoppingListMemberAdded = onDocumentUpdated({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const newMembers: string[] = (after.allUserIds || []).filter((m: string) => !(before.allUserIds || []).includes(m));
  if (!newMembers.length) return;
  await handleEvent({
    members: before.allUserIds || [],
    exclude: newMembers,
    title: 'Neuer Member in Einkaufsliste',
    body: `${newMembers.length} neuer Member ist der Einkaufsliste beigetreten`,
    type: NotificationTypes.SHOPPING_MEMBER_ADDED,
    data: { type: NotificationTypes.SHOPPING_MEMBER_ADDED, listId: event.params.listId, newMembers: newMembers.join(',') },
  });
});

export const onShoppingListMemberRemoved = onDocumentUpdated({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const removed: string[] = (before.allUserIds || []).filter((m: string) => !(after.allUserIds || []).includes(m));
  if (!removed.length) return;
  await handleEvent({
    members: after.allUserIds || [],
    exclude: removed,
    title: 'Member verlässt Einkaufsliste',
    body: `${removed.length} Member hat die Einkaufsliste verlassen`,
    type: NotificationTypes.SHOPPING_MEMBER_REMOVED,
    data: { type: NotificationTypes.SHOPPING_MEMBER_REMOVED, listId: event.params.listId, removedMembers: removed.join(',') },
  });
});

export const sendTestNotification = onCall({ region: 'europe-west3' }, async (request) => {
  const { fcmToken, title = 'Test Nachricht', body = 'Das ist eine Test-Benachrichtigung!' } = request.data;
  if (!fcmToken) throw new Error('FCM Token erforderlich');
  const message: admin.messaging.Message = {
    token: fcmToken,
    notification: { title, body },
    data: { type: NotificationTypes.TEST, timestamp: Date.now().toString() },
    android: { notification: { title, body, sound: 'notification_sound', channelId: 'togetherdo_channel', priority: 'high' } },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { alert: { title, body }, sound: 'notification_sound.aiff', badge: 1, 'interruption-level': 'time-sensitive' } },
    },
  };
  const res = await messaging.send(message);
  log.info('✅ Test-Benachrichtigung gesendet:', res);
  return { success: true, messageId: res };
});
