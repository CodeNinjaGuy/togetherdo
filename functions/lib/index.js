"use strict";

const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

async function getMemberTokens(members, exclude = []) {
  const tokens = [];
  for (const memberId of members) {
    if (exclude.includes(memberId)) continue;

    const userDoc = await db.collection("users").doc(memberId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) tokens.push(fcmToken);
  }
  return tokens;
}

async function getListMembers(listId) {
  const listDoc = await db.collection("lists").doc(listId).get();
  if (!listDoc.exists) return null;
  return listDoc.data().allUserIds || [];
}

// Neue Funktion: Benachrichtigungseinstellungen abrufen
async function getUserNotificationSettings(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    
    // Standardeinstellungen (alle aktiviert)
    const defaultSettings = {
      todoCreated: true,
      todoCompleted: true,
      todoDeleted: true,
      memberAdded: true,
      memberRemoved: true,
    };
    
    // Benutzer-Einstellungen aus Firestore (falls vorhanden)
    const userSettings = userData?.notificationSettings || {};
    
    return {
      todoCreated: userSettings.todoCreated ?? defaultSettings.todoCreated,
      todoCompleted: userSettings.todoCompleted ?? defaultSettings.todoCompleted,
      todoDeleted: userSettings.todoDeleted ?? defaultSettings.todoDeleted,
      memberAdded: userSettings.memberAdded ?? defaultSettings.memberAdded,
      memberRemoved: userSettings.memberRemoved ?? defaultSettings.memberRemoved,
    };
  } catch (error) {
    console.log(`Fehler beim Abrufen der Benachrichtigungseinstellungen für ${userId}:`, error);
    // Bei Fehler alle Benachrichtigungen erlauben
    return {
      todoCreated: true,
      todoCompleted: true,
      todoDeleted: true,
      memberAdded: true,
      memberRemoved: true,
    };
  }
}

// Neue Funktion: Gefilterte Member-Tokens basierend auf Benachrichtigungseinstellungen
async function getFilteredMemberTokens(members, exclude = [], notificationType) {
  const tokens = [];
  for (const memberId of members) {
    if (exclude.includes(memberId)) continue;

    const userDoc = await db.collection("users").doc(memberId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      // Benachrichtigungseinstellungen prüfen
      const settings = await getUserNotificationSettings(memberId);
      let shouldSend = false;

      switch (notificationType) {
        case 'todo_created':
          shouldSend = settings.todoCreated;
          break;
        case 'todo_completed':
          shouldSend = settings.todoCompleted;
          break;
        case 'todo_deleted':
          shouldSend = settings.todoDeleted;
          break;
        case 'member_added':
          shouldSend = settings.memberAdded;
          break;
        case 'member_removed':
          shouldSend = settings.memberRemoved;
          break;
        default:
          shouldSend = true; // Fallback
      }

      if (shouldSend) {
        tokens.push(fcmToken);
      } else {
        console.log(`Benachrichtigung ${notificationType} für Benutzer ${memberId} deaktiviert`);
      }
    }
  }
  return tokens;
}

function logInvalidData(context, data) {
  console.log(`🚨 [${context}] Ungültige Daten:`, JSON.stringify(data));
}

async function sendNotification(members, exclude, payload, notificationType = 'general') {
  const tokens = await getFilteredMemberTokens(members, exclude, notificationType);
  if (tokens.length === 0) {
    console.log("🚨 Keine Empfänger gefunden oder alle Benachrichtigungen deaktiviert.");
    return;
  }

  const response = await messaging.sendEachForMulticast({ ...payload, tokens });
  console.log(`📬 Benachrichtigungen gesendet: ${response.successCount}/${tokens.length} (Typ: ${notificationType})`);

  response.responses.forEach((r, i) => {
    if (r.success) console.log(`✅ Erfolgreich an ${tokens[i]}`);
    else console.log(`❌ Fehler bei ${tokens[i]}: ${r.error?.message}`);
  });
}

// 🔷 onTodoCreated
exports.onTodoCreated = onDocumentCreated({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const todoData = event.data?.data();
  if (!todoData) return logInvalidData("onTodoCreated", { reason: "todoData fehlt" });

  const { userId, listId, title, assignedToUserId } = todoData;
  if (!userId || !listId) return logInvalidData("onTodoCreated", { userId, listId });

  console.log(`✅ Neues Todo: ${title}`);

  const members = await getListMembers(listId);
  if (!members) return;

  let targets = [];
  let exclude = [userId];
  let note = { title: "Neues Todo", body: `${title} wurde erstellt` };

  if (assignedToUserId) {
    targets = [assignedToUserId];
    exclude = []; // nur der Assigned bekommt es
    note.body = `${title} wurde dir zugewiesen`;
  } else {
    targets = members;
  }

  await sendNotification(targets, exclude, {
    notification: note,
    data: { type: "todo_created", todoId: event.params.todoId, listId, createdBy: userId },
  }, 'todo_created');
});

// 🔷 onTodoCompleted
exports.onTodoCompleted = onDocumentUpdated({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return logInvalidData("onTodoCompleted", {});

  if (!before.isCompleted && after.isCompleted) {
    const { listId, title, completedByUserId, userId } = after;
    const members = await getListMembers(listId);
    if (!members) return;

    const exclude = [completedByUserId || userId];

    await sendNotification(members, exclude, {
      notification: { title: "Todo erledigt", body: `${title} wurde als erledigt markiert` },
      data: { type: "todo_completed", todoId: event.params.todoId, listId, completedBy: completedByUserId || userId },
    }, 'todo_completed');
  }
});

// 🔷 onTodoDeleted
exports.onTodoDeleted = onDocumentDeleted({ region: "europe-west3", document: "todos/{todoId}" }, async (event) => {
  const todoData = event.data?.data();
  if (!todoData) return logInvalidData("onTodoDeleted", {});

  const { deletedByUserId, userId, listId, title } = todoData;
  const members = await getListMembers(listId);
  if (!members) return;

  const exclude = [deletedByUserId || userId];

  await sendNotification(members, exclude, {
    notification: { title: "Todo gelöscht", body: `${title} wurde gelöscht` },
    data: { type: "todo_deleted", todoId: event.params.todoId, listId, deletedBy: deletedByUserId || userId },
  }, 'todo_deleted');
});

// 🔷 onListMemberAdded
exports.onListMemberAdded = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return logInvalidData("onListMemberAdded", {});

  const newMembers = (after.allUserIds || []).filter(m => !(before.allUserIds || []).includes(m));
  if (newMembers.length === 0) return;

  await sendNotification(before.allUserIds || [], newMembers, {
    notification: { title: "Neuer Member", body: `${newMembers.length} neuer Member ist der Liste beigetreten` },
    data: { type: "member_added", listId: event.params.listId, newMembers: newMembers.join(",") },
  }, 'member_added');
});

// 🔷 onListMemberRemoved
exports.onListMemberRemoved = onDocumentUpdated({ region: "europe-west3", document: "lists/{listId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return logInvalidData("onListMemberRemoved", {});

  const removedMembers = (before.allUserIds || []).filter(m => !(after.allUserIds || []).includes(m));
  if (removedMembers.length === 0) return;

  await sendNotification(after.allUserIds || [], removedMembers, {
    notification: { title: "Member entfernt", body: `${removedMembers.length} Member hat die Liste verlassen` },
    data: { type: "member_removed", listId: event.params.listId, removedMembers: removedMembers.join(",") },
  }, 'member_removed');
});

// 🔷 sendTestNotification
exports.sendTestNotification = onCall({ region: "europe-west3" }, async (request) => {
  const { fcmToken, title = "Test Nachricht", body = "Das ist eine Test-Benachrichtigung!" } = request.data;
  if (!fcmToken) throw new Error("FCM Token erforderlich");

  const response = await messaging.send({
    token: fcmToken,
    notification: { title, body },
    data: { type: "test", timestamp: Date.now().toString() },
  });

  console.log("✅ Test-Benachrichtigung gesendet:", response);
  return { success: true, messageId: response, message: "Test-Benachrichtigung gesendet" };
});