"use strict";

const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
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
};

const defaultSettings = Object.fromEntries(Object.values(NotificationTypes).map(key => [key, true]));

const log = {
  info: (...args) => console.log('ℹ️', ...args),
  warn: (...args) => console.warn('⚠️', ...args),
  error: (...args) => console.error('🚨', ...args),
};

async function getListMembers(listId) {
  const doc = await db.collection("lists").doc(listId).get();
  if (!doc.exists) return [];
  return doc.data().allUserIds || [];
}

async function getFilteredMemberTokens(members, exclude = [], notificationType) {
  const filtered = members.filter(id => !exclude.includes(id));
  if (!filtered.length) return [];

  const chunks = [];
  for (let i = 0; i < filtered.length; i += 10) chunks.push(filtered.slice(i, i + 10));

  const tokens = [];
  for (const chunk of chunks) {
    const snap = await db.collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", chunk)
      .get();

    snap.forEach(doc => {
      const data = doc.data();
      const fcmToken = data?.fcmToken;
      const allowed = (data?.notificationSettings?.[notificationType] ?? defaultSettings[notificationType]);
      if (!fcmToken || !allowed) return;
      tokens.push(fcmToken);
    });
  }
  return tokens;
}

async function sendNotification(members, exclude, payload, notificationType) {
  const tokens = await getFilteredMemberTokens(members, exclude, notificationType);
  if (!tokens.length) return;

  const batches = [];
  for (let i = 0; i < tokens.length; i += 500) batches.push(tokens.slice(i, i + 500));

  await Promise.all(batches.map(async (batch) => {
    const message = {
      notification: payload.notification,
      data: payload.data,
      android: {
        notification: { ...payload.notification, sound: 'notification_sound', channelId: 'togetherdo_channel', priority: 'high' },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { alert: payload.notification, sound: 'notification_sound.aiff', badge: 1, "interruption-level": "time-sensitive" } },
      },
      tokens: batch,
    };

    const response = await messaging.sendEachForMulticast(message);
    response.responses.forEach((r, i) => {
      if (r.success) log.info(`✅ an ${batch[i]}`);
      else log.error(`❌ bei ${batch[i]}:`, r.error?.message);
    });
  }));
}

async function handleEvent({members, exclude, title, body, type, data}) {
  const note = { title, body };
  await sendNotification(members, exclude, {notification: note, data}, type);
}

exports.onTodoCreated = onDocumentCreated({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { userId, listId, title, assignedToUserId } = d;
  const members = await getListMembers(listId);
  const targets = assignedToUserId ? [assignedToUserId] : members;
  const exclude = assignedToUserId ? [] : [userId];
  await handleEvent({ members: targets, exclude, title: "Neues Todo", body: `${title} wurde ${assignedToUserId ? 'dir zugewiesen' : 'erstellt'}`, type: NotificationTypes.TODO_CREATED, data: { type: NotificationTypes.TODO_CREATED, todoId: event.params.todoId, listId, createdBy: userId }});
});

exports.onTodoCompleted = onDocumentUpdated({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  if (!before.isCompleted && after.isCompleted) {
    const { listId, title, completedByUserId, userId } = after;
    const members = await getListMembers(listId);
    await handleEvent({ members, exclude: [completedByUserId || userId], title: "Todo erledigt", body: `${title} wurde als erledigt markiert`, type: NotificationTypes.TODO_COMPLETED, data: { type: NotificationTypes.TODO_COMPLETED, todoId: event.params.todoId, listId, completedBy: completedByUserId || userId }});
  }
});

exports.onTodoDeleted = onDocumentDeleted({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { deletedByUserId, userId, listId, title } = d;
  const members = await getListMembers(listId);
  await handleEvent({ members, exclude: [deletedByUserId || userId], title: "Todo gelöscht", body: `${title} wurde gelöscht`, type: NotificationTypes.TODO_DELETED, data: { type: NotificationTypes.TODO_DELETED, todoId: event.params.todoId, listId, deletedBy: deletedByUserId || userId }});
});

exports.onListMemberAdded = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const newMembers = (after.allUserIds || []).filter(m => !(before.allUserIds || []).includes(m));
  if (!newMembers.length) return;
  await handleEvent({ members: before.allUserIds || [], exclude: newMembers, title: "Neuer Member", body: `${newMembers.length} neuer Member ist beigetreten`, type: NotificationTypes.MEMBER_ADDED, data: { type: NotificationTypes.MEMBER_ADDED, listId: event.params.listId, newMembers: newMembers.join(",") }});
});

exports.onListMemberRemoved = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const removed = (before.allUserIds || []).filter(m => !(after.allUserIds || []).includes(m));
  if (!removed.length) return;
  await handleEvent({ members: after.allUserIds || [], exclude: removed, title: "Member entfernt", body: `${removed.length} Member hat die Liste verlassen`, type: NotificationTypes.MEMBER_REMOVED, data: { type: NotificationTypes.MEMBER_REMOVED, listId: event.params.listId, removedMembers: removed.join(",") }});
});

exports.onChatMessageCreated = onDocumentCreated({ region: "europe-west3", document: "todos/{todoId}/chatMessages/{messageId}" }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { userId, userName, message } = d;
  const todoId = event.params.todoId;
  const todo = await db.collection("todos").doc(todoId).get();
  if (!todo.exists) return;
  const listId = todo.data().listId;
  const members = await getListMembers(listId);
  await handleEvent({ members, exclude: [userId], title: `💬 ${userName}`, body: message.length > 50 ? message.slice(0, 50) + '...' : message, type: NotificationTypes.CHAT_MESSAGE, data: { type: NotificationTypes.CHAT_MESSAGE, messageId: event.params.messageId, todoId, listId, senderId: userId, senderName: userName }});
});

exports.onShoppingItemCreated = onDocumentCreated({ region: "europe-west3", document: "shopping_items/{itemId}" }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { userId, listId, name, assignedToUserId } = d;
  const members = await getListMembers(listId);
  const targets = assignedToUserId ? [assignedToUserId] : members;
  const exclude = assignedToUserId ? [] : [userId];
  await handleEvent({ members: targets, exclude, title: "Neues Einkaufsitem", body: `${name} wurde ${assignedToUserId ? 'dir zugewiesen' : 'hinzugefügt'}`, type: NotificationTypes.SHOPPING_ITEM_CREATED, data: { type: NotificationTypes.SHOPPING_ITEM_CREATED, itemId: event.params.itemId, listId, createdBy: userId }});
});

exports.onShoppingItemPurchased = onDocumentUpdated({ region: "europe-west3", document: "shopping_items/{itemId}" }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  if (!before.isPurchased && after.isPurchased) {
    const { listId, name, purchasedByUserId, userId } = after;
    const members = await getListMembers(listId);
    await handleEvent({ members, exclude: [purchasedByUserId || userId], title: "Einkaufsitem erledigt", body: `${name} wurde als erledigt/gekauft markiert`, type: NotificationTypes.SHOPPING_ITEM_PURCHASED, data: { type: NotificationTypes.SHOPPING_ITEM_PURCHASED, itemId: event.params.itemId, listId, purchasedBy: purchasedByUserId || userId }});
  }
});

exports.onShoppingItemDeleted = onDocumentDeleted({ region: "europe-west3", document: "shopping_items/{itemId}" }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  const { deletedByUserId, userId, listId, name } = d;
  const members = await getListMembers(listId);
  await handleEvent({ members, exclude: [deletedByUserId || userId], title: "Einkaufsitem gelöscht", body: `${name} wurde gelöscht`, type: NotificationTypes.SHOPPING_ITEM_DELETED, data: { type: NotificationTypes.SHOPPING_ITEM_DELETED, itemId: event.params.itemId, listId, deletedBy: deletedByUserId || userId }});
});

exports.onShoppingListMemberAdded = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const newMembers = (after.allUserIds || []).filter(m => !(before.allUserIds || []).includes(m));
  if (!newMembers.length) return;
  await handleEvent({ members: before.allUserIds || [], exclude: newMembers, title: "Neuer Member in Einkaufsliste", body: `${newMembers.length} neuer Member ist der Einkaufsliste beigetreten`, type: NotificationTypes.SHOPPING_MEMBER_ADDED, data: { type: NotificationTypes.SHOPPING_MEMBER_ADDED, listId: event.params.listId, newMembers: newMembers.join(",") }});
});

exports.onShoppingListMemberRemoved = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!before || !after) return;
  const removed = (before.allUserIds || []).filter(m => !(after.allUserIds || []).includes(m));
  if (!removed.length) return;
  await handleEvent({ members: after.allUserIds || [], exclude: removed, title: "Member verlässt Einkaufsliste", body: `${removed.length} Member hat die Einkaufsliste verlassen`, type: NotificationTypes.SHOPPING_MEMBER_REMOVED, data: { type: NotificationTypes.SHOPPING_MEMBER_REMOVED, listId: event.params.listId, removedMembers: removed.join(",") }});
});

exports.sendTestNotification = onCall({ region: "europe-west3" }, async (request) => {
  const { fcmToken, title = "Test Nachricht", body = "Das ist eine Test-Benachrichtigung!" } = request.data;
  if (!fcmToken) throw new Error("FCM Token erforderlich");
  const message = {
    token: fcmToken,
    notification: { title, body },
    data: { type: NotificationTypes.TEST, timestamp: Date.now().toString() },
    android: { notification: { title, body, sound: 'notification_sound', channelId: 'togetherdo_channel', priority: 'high' } },
    apns: { headers: { 'apns-priority': '10' }, payload: { aps: { alert: { title, body }, sound: 'notification_sound.aiff', badge: 1, "interruption-level": "time-sensitive" } } },
  };
  const res = await messaging.send(message);
  log.info("✅ Test-Benachrichtigung gesendet:", res);
  return { success: true, messageId: res };
});
