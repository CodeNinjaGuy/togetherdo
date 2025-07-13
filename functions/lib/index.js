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

const defaultSettings = {
  [NotificationTypes.TODO_CREATED]: true,
  [NotificationTypes.TODO_COMPLETED]: true,
  [NotificationTypes.TODO_DELETED]: true,
  [NotificationTypes.MEMBER_ADDED]: true,
  [NotificationTypes.MEMBER_REMOVED]: true,
  [NotificationTypes.CHAT_MESSAGE]: true,
  [NotificationTypes.SHOPPING_ITEM_CREATED]: true,
  [NotificationTypes.SHOPPING_ITEM_PURCHASED]: true,
  [NotificationTypes.SHOPPING_ITEM_DELETED]: true,
  [NotificationTypes.SHOPPING_MEMBER_ADDED]: true,
  [NotificationTypes.SHOPPING_MEMBER_REMOVED]: true,
};

// 📋 Logging Utility
const log = {
  info: (...args) => console.log('ℹ️', ...args),
  warn: (...args) => console.warn('⚠️', ...args),
  error: (...args) => console.error('🚨', ...args),
};

async function getListMembers(listId) {
  const listDoc = await db.collection("lists").doc(listId).get();
  if (!listDoc.exists) {
    log.error(`Liste nicht gefunden: ${listId}`);
    return null;
  }
  return listDoc.data().allUserIds || [];
}

async function getFilteredMemberTokens(members, exclude = [], notificationType) {
  const promises = members
    .filter(memberId => !exclude.includes(memberId))
    .map(async memberId => {
      const userDoc = await db.collection("users").doc(memberId).get();
      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;
      if (!fcmToken) return null;

      const settings = userData?.notificationSettings || {};
      const allowed = settings[notificationType] ?? defaultSettings[notificationType] ?? true;

      if (!allowed) {
        log.info(`🔕 ${notificationType} für ${memberId} deaktiviert`);
        return null;
      }

      log.info(`📨 Token für ${memberId}: ${fcmToken}`);
      return fcmToken;
    });

  const tokens = (await Promise.all(promises)).filter(Boolean);
  return tokens;
}

async function sendNotification(members, exclude, payload, notificationType = NotificationTypes.TEST) {
  const tokens = await getFilteredMemberTokens(members, exclude, notificationType);
  if (tokens.length === 0) {
    log.warn("Keine Empfänger gefunden oder alle Benachrichtigungen deaktiviert.");
    return;
  }

  const notificationWithSound = {
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
      headers: {
        'apns-priority': '10'
      },
      payload: {
        aps: {
          alert: payload.notification,
          sound: 'notification_sound.aiff',
          badge: 1,
          "interruption-level": "time-sensitive"
        },
      },
    },
    tokens,
  };

  const response = await messaging.sendEachForMulticast(notificationWithSound);
  log.info(`📬 Benachrichtigungen gesendet: ${response.successCount}/${tokens.length} (Typ: ${notificationType})`);

  response.responses.forEach((r, i) => {
    if (r.success) log.info(`✅ an ${tokens[i]}`);
    else log.error(`❌ bei ${tokens[i]}:`, r.error?.message);
  });
}

// 🔷 onTodoCreated
exports.onTodoCreated = onDocumentCreated({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const todoData = event.data?.data();
  if (!todoData) return log.error("Ungültige Todo-Daten");

  const { userId, listId, title, assignedToUserId } = todoData;
  if (!userId || !listId) return log.error("userId oder listId fehlt");

  log.info(`✅ Neues Todo: ${title}`);

  const members = await getListMembers(listId);
  if (!members) return;

  let targets = assignedToUserId ? [assignedToUserId] : members;
  let exclude = assignedToUserId ? [] : [userId];
  let note = { title: "Neues Todo", body: `${title} wurde ${assignedToUserId ? 'dir zugewiesen' : 'erstellt'}` };

  await sendNotification(targets, exclude, {
    notification: note,
    data: { type: NotificationTypes.TODO_CREATED, todoId: event.params.todoId, listId, createdBy: userId },
  }, NotificationTypes.TODO_CREATED);
});

// 🔷 onTodoCompleted
exports.onTodoCompleted = onDocumentUpdated({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return log.error("Ungültige Daten");

  if (!before.isCompleted && after.isCompleted) {
    const { listId, title, completedByUserId, userId } = after;
    const members = await getListMembers(listId);
    if (!members) return;

    await sendNotification(members, [completedByUserId || userId], {
      notification: { title: "Todo erledigt", body: `${title} wurde als erledigt markiert` },
      data: { type: NotificationTypes.TODO_COMPLETED, todoId: event.params.todoId, listId, completedBy: completedByUserId || userId },
    }, NotificationTypes.TODO_COMPLETED);
  }
});

// 🔷 onTodoDeleted
exports.onTodoDeleted = onDocumentDeleted({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const todoData = event.data?.data();
  if (!todoData) return log.error("Ungültige Daten");

  const { deletedByUserId, userId, listId, title } = todoData;
  const members = await getListMembers(listId);
  if (!members) return;

  await sendNotification(members, [deletedByUserId || userId], {
    notification: { title: "Todo gelöscht", body: `${title} wurde gelöscht` },
    data: { type: NotificationTypes.TODO_DELETED, todoId: event.params.todoId, listId, deletedBy: deletedByUserId || userId },
  }, NotificationTypes.TODO_DELETED);
});

// 🔷 onListMemberAdded
exports.onListMemberAdded = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return log.error("Ungültige Daten");

  const newMembers = (after.allUserIds || []).filter(m => !(before.allUserIds || []).includes(m));
  if (newMembers.length === 0) return;

  await sendNotification(before.allUserIds || [], newMembers, {
    notification: { title: "Neuer Member", body: `${newMembers.length} neuer Member ist beigetreten` },
    data: { type: NotificationTypes.MEMBER_ADDED, listId: event.params.listId, newMembers: newMembers.join(",") },
  }, NotificationTypes.MEMBER_ADDED);
});

// 🔷 onListMemberRemoved
exports.onListMemberRemoved = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return log.error("Ungültige Daten");

  const removedMembers = (before.allUserIds || []).filter(m => !(after.allUserIds || []).includes(m));
  if (removedMembers.length === 0) return;

  await sendNotification(after.allUserIds || [], removedMembers, {
    notification: { title: "Member entfernt", body: `${removedMembers.length} Member hat die Liste verlassen` },
    data: { type: NotificationTypes.MEMBER_REMOVED, listId: event.params.listId, removedMembers: removedMembers.join(",") },
  }, NotificationTypes.MEMBER_REMOVED);
});

// 🔷 onChatMessageCreated
exports.onChatMessageCreated = onDocumentCreated({ region: "europe-west3", document: "todos/{todoId}/chatMessages/{messageId}" }, async (event) => {
  const messageData = event.data?.data();
  if (!messageData) return log.error("Ungültige Daten");

  const { userId, userName, message } = messageData;
  const { todoId } = event.params;
  if (!todoId || !userId) return log.error("todoId oder userId fehlt");

  const todoDoc = await db.collection("todos").doc(todoId).get();
  if (!todoDoc.exists) return log.error(`Todo ${todoId} nicht gefunden`);

  const listId = todoDoc.data().listId;
  if (!listId) return log.error(`listId für Todo ${todoId} nicht gefunden`);

  const members = await getListMembers(listId);
  if (!members) return;

  await sendNotification(members, [userId], {
    notification: { title: `💬 ${userName}`, body: message.length > 50 ? message.substring(0, 50) + '...' : message },
    data: { type: NotificationTypes.CHAT_MESSAGE, messageId: event.params.messageId, todoId, listId, senderId: userId, senderName: userName },
  }, NotificationTypes.CHAT_MESSAGE);
});

// 🔷 sendTestNotification
exports.sendTestNotification = onCall({ region: "europe-west3" }, async (request) => {
  const { fcmToken, title = "Test Nachricht", body = "Das ist eine Test-Benachrichtigung!" } = request.data;
  if (!fcmToken) throw new Error("FCM Token erforderlich");

  const response = await messaging.send({
    token: fcmToken,
    notification: { title, body },
    data: { type: NotificationTypes.TEST, timestamp: Date.now().toString() },
    android: {
      notification: {
        title,
        body,
        sound: 'notification_sound',
        channelId: 'togetherdo_channel',
        priority: 'high',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10'
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'notification_sound.aiff',
          badge: 1,
          "interruption-level": "time-sensitive"
        },
      },
    },
  });

  log.info("✅ Test-Benachrichtigung gesendet:", response);
  return { success: true, messageId: response, message: "Test-Benachrichtigung gesendet" };
});

// 🔷 onShoppingItemCreated
exports.onShoppingItemCreated = onDocumentCreated({ region: "europe-west3", document: "shopping_items/{itemId}" }, async (event) => {
  const itemData = event.data?.data();
  if (!itemData) return log.error("Ungültige Shopping-Item-Daten");

  const { userId, listId, name, assignedToUserId } = itemData;
  if (!userId || !listId) return log.error("userId oder listId fehlt");

  log.info(`✅ Neues Einkaufsitem: ${name}`);

  const members = await getListMembers(listId);
  if (!members) return;

  let targets = assignedToUserId ? [assignedToUserId] : members;
  let exclude = assignedToUserId ? [] : [userId];
  let note = { title: "Neues Einkaufsitem", body: `${name} wurde ${assignedToUserId ? 'dir zugewiesen' : 'hinzugefügt'}` };

  await sendNotification(targets, exclude, {
    notification: note,
    data: { type: NotificationTypes.SHOPPING_ITEM_CREATED, itemId: event.params.itemId, listId, createdBy: userId },
  }, NotificationTypes.SHOPPING_ITEM_CREATED);
});

// 🔷 onShoppingItemPurchased
exports.onShoppingItemPurchased = onDocumentUpdated({ region: "europe-west3", document: "shopping_items/{itemId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return log.error("Ungültige Daten");

  if (!before.isPurchased && after.isPurchased) {
    const { listId, name, purchasedByUserId, userId } = after;
    const members = await getListMembers(listId);
    if (!members) return;

    await sendNotification(members, [purchasedByUserId || userId], {
      notification: { title: "Einkaufsitem erledigt", body: `${name} wurde als erledigt/gekauft markiert` },
      data: { type: NotificationTypes.SHOPPING_ITEM_PURCHASED, itemId: event.params.itemId, listId, purchasedBy: purchasedByUserId || userId },
    }, NotificationTypes.SHOPPING_ITEM_PURCHASED);
  }
});

// 🔷 onShoppingItemDeleted
exports.onShoppingItemDeleted = onDocumentDeleted({ region: "europe-west3", document: "shopping_items/{itemId}" }, async (event) => {
  const itemData = event.data?.data();
  if (!itemData) return log.error("Ungültige Daten");

  const { deletedByUserId, userId, listId, name } = itemData;
  const members = await getListMembers(listId);
  if (!members) return;

  await sendNotification(members, [deletedByUserId || userId], {
    notification: { title: "Einkaufsitem gelöscht", body: `${name} wurde gelöscht` },
    data: { type: NotificationTypes.SHOPPING_ITEM_DELETED, itemId: event.params.itemId, listId, deletedBy: deletedByUserId || userId },
  }, NotificationTypes.SHOPPING_ITEM_DELETED);
});

// 🔷 onShoppingListMemberAdded
exports.onShoppingListMemberAdded = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return log.error("Ungültige Daten");

  const newMembers = (after.allUserIds || []).filter(m => !(before.allUserIds || []).includes(m));
  if (newMembers.length === 0) return;

  await sendNotification(before.allUserIds || [], newMembers, {
    notification: { title: "Neuer Member in Einkaufsliste", body: `${newMembers.length} neuer Member ist der Einkaufsliste beigetreten` },
    data: { type: NotificationTypes.SHOPPING_MEMBER_ADDED, listId: event.params.listId, newMembers: newMembers.join(",") },
  }, NotificationTypes.SHOPPING_MEMBER_ADDED);
});

// 🔷 onShoppingListMemberRemoved
exports.onShoppingListMemberRemoved = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return log.error("Ungültige Daten");

  const removedMembers = (before.allUserIds || []).filter(m => !(after.allUserIds || []).includes(m));
  if (removedMembers.length === 0) return;

  await sendNotification(after.allUserIds || [], removedMembers, {
    notification: { title: "Member verlässt Einkaufsliste", body: `${removedMembers.length} Member hat die Einkaufsliste verlassen` },
    data: { type: NotificationTypes.SHOPPING_MEMBER_REMOVED, listId: event.params.listId, removedMembers: removedMembers.join(",") },
  }, NotificationTypes.SHOPPING_MEMBER_REMOVED);
});