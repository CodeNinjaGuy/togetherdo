"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendTestNotification = exports.onListMemberRemoved = exports.onListMemberAdded = exports.onTodoDeleted = exports.onTodoCompleted = exports.onTodoCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// Cloud Function für neue Todo-Items
exports.onTodoCreated = (0, firestore_1.onDocumentCreated)({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
    var _a;
    try {
        const todoData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
        const todoId = event.params.todoId;
        const createdBy = todoData === null || todoData === void 0 ? void 0 : todoData.createdBy;
        const listId = todoData === null || todoData === void 0 ? void 0 : todoData.listId;
        if (!todoData || !createdBy || !listId) {
            console.log('Ungültige Todo-Daten');
            return;
        }
        console.log(`Neues Todo erstellt: ${todoId} in Liste: ${listId}`);
        // Liste abrufen um Members zu bekommen
        const listDoc = await db.collection('lists').doc(listId).get();
        if (!listDoc.exists) {
            console.log('Liste nicht gefunden');
            return;
        }
        const listData = listDoc.data();
        const members = (listData === null || listData === void 0 ? void 0 : listData.members) || [];
        // FCM Tokens für alle Members außer dem Ersteller abrufen
        const memberTokens = [];
        for (const memberId of members) {
            if (memberId !== createdBy) {
                const userDoc = await db.collection('users').doc(memberId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                    if (fcmToken) {
                        memberTokens.push(fcmToken);
                    }
                }
            }
        }
        if (memberTokens.length === 0) {
            console.log('Keine FCM Tokens für Benachrichtigungen gefunden');
            return;
        }
        // Benachrichtigung senden
        const response = await messaging.sendEachForMulticast({
            tokens: memberTokens,
            notification: {
                title: 'Neues Todo erstellt',
                body: `${todoData.title} wurde zur Liste hinzugefügt`,
            },
            data: {
                type: 'todo_created',
                todoId: todoId,
                listId: listId,
                createdBy: createdBy,
            },
        });
        console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
    }
    catch (error) {
        console.error('Fehler beim Senden der Benachrichtigung:', error);
    }
});
// Cloud Function für erledigte Todo-Items
exports.onTodoCompleted = (0, firestore_1.onDocumentUpdated)({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
    var _a, _b;
    try {
        const beforeData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
        const afterData = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
        const todoId = event.params.todoId;
        if (!beforeData || !afterData) {
            console.log('Ungültige Todo-Daten');
            return;
        }
        // Prüfen ob Todo von unerledigt zu erledigt geändert wurde
        if (!beforeData.completed && afterData.completed) {
            const listId = afterData.listId;
            const completedBy = afterData.completedBy || afterData.createdBy;
            console.log(`Todo erledigt: ${todoId} in Liste: ${listId}`);
            // Liste abrufen
            const listDoc = await db.collection('lists').doc(listId).get();
            if (!listDoc.exists) {
                console.log('Liste nicht gefunden');
                return;
            }
            const listData = listDoc.data();
            const members = (listData === null || listData === void 0 ? void 0 : listData.members) || [];
            // FCM Tokens für alle Members außer dem, der es erledigt hat
            const memberTokens = [];
            for (const memberId of members) {
                if (memberId !== completedBy) {
                    const userDoc = await db.collection('users').doc(memberId).get();
                    if (userDoc.exists) {
                        const userData = userDoc.data();
                        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                        if (fcmToken) {
                            memberTokens.push(fcmToken);
                        }
                    }
                }
            }
            if (memberTokens.length === 0) {
                console.log('Keine FCM Tokens für Benachrichtigungen gefunden');
                return;
            }
            // Benachrichtigung senden
            const response = await messaging.sendEachForMulticast({
                tokens: memberTokens,
                notification: {
                    title: 'Todo erledigt',
                    body: `${afterData.title} wurde als erledigt markiert`,
                },
                data: {
                    type: 'todo_completed',
                    todoId: todoId,
                    listId: listId,
                    completedBy: completedBy,
                },
            });
            console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
        }
    }
    catch (error) {
        console.error('Fehler beim Senden der Benachrichtigung:', error);
    }
});
// Cloud Function für gelöschte Todo-Items
exports.onTodoDeleted = (0, firestore_1.onDocumentDeleted)({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
    var _a;
    try {
        const todoData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
        const todoId = event.params.todoId;
        const deletedBy = (todoData === null || todoData === void 0 ? void 0 : todoData.deletedBy) || (todoData === null || todoData === void 0 ? void 0 : todoData.createdBy);
        const listId = todoData === null || todoData === void 0 ? void 0 : todoData.listId;
        if (!todoData || !deletedBy || !listId) {
            console.log('Ungültige Todo-Daten');
            return;
        }
        console.log(`Todo gelöscht: ${todoId} in Liste: ${listId}`);
        // Liste abrufen
        const listDoc = await db.collection('lists').doc(listId).get();
        if (!listDoc.exists) {
            console.log('Liste nicht gefunden');
            return;
        }
        const listData = listDoc.data();
        const members = (listData === null || listData === void 0 ? void 0 : listData.members) || [];
        // FCM Tokens für alle Members außer dem, der es gelöscht hat
        const memberTokens = [];
        for (const memberId of members) {
            if (memberId !== deletedBy) {
                const userDoc = await db.collection('users').doc(memberId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                    if (fcmToken) {
                        memberTokens.push(fcmToken);
                    }
                }
            }
        }
        if (memberTokens.length === 0) {
            console.log('Keine FCM Tokens für Benachrichtigungen gefunden');
            return;
        }
        // Benachrichtigung senden
        const response = await messaging.sendEachForMulticast({
            tokens: memberTokens,
            notification: {
                title: 'Todo gelöscht',
                body: `${todoData.title} wurde aus der Liste entfernt`,
            },
            data: {
                type: 'todo_deleted',
                todoId: todoId,
                listId: listId,
                deletedBy: deletedBy,
            },
        });
        console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
    }
    catch (error) {
        console.error('Fehler beim Senden der Benachrichtigung:', error);
    }
});
// Cloud Function für neue List-Members
exports.onListMemberAdded = (0, firestore_1.onDocumentUpdated)({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
    var _a, _b;
    try {
        const beforeData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
        const afterData = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
        const listId = event.params.listId;
        if (!beforeData || !afterData) {
            console.log('Ungültige Listen-Daten');
            return;
        }
        const beforeMembers = beforeData.members || [];
        const afterMembers = afterData.members || [];
        // Prüfen ob ein neuer Member hinzugefügt wurde
        const newMembers = afterMembers.filter((member) => !beforeMembers.includes(member));
        if (newMembers.length > 0) {
            console.log(`Neue Members in Liste ${listId}: ${newMembers.join(', ')}`);
            // FCM Tokens für alle bestehenden Members abrufen
            const memberTokens = [];
            for (const memberId of beforeMembers) {
                const userDoc = await db.collection('users').doc(memberId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                    if (fcmToken) {
                        memberTokens.push(fcmToken);
                    }
                }
            }
            if (memberTokens.length === 0) {
                console.log('Keine FCM Tokens für Benachrichtigungen gefunden');
                return;
            }
            // Benachrichtigung senden
            const response = await messaging.sendEachForMulticast({
                tokens: memberTokens,
                notification: {
                    title: 'Neuer Member',
                    body: `${newMembers.length} neuer Member ist der Liste beigetreten`,
                },
                data: {
                    type: 'member_added',
                    listId: listId,
                    newMembers: newMembers.join(','),
                },
            });
            console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
        }
    }
    catch (error) {
        console.error('Fehler beim Senden der Benachrichtigung:', error);
    }
});
// Cloud Function für entfernte List-Members
exports.onListMemberRemoved = (0, firestore_1.onDocumentUpdated)({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
    var _a, _b;
    try {
        const beforeData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
        const afterData = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
        const listId = event.params.listId;
        if (!beforeData || !afterData) {
            console.log('Ungültige Listen-Daten');
            return;
        }
        const beforeMembers = beforeData.members || [];
        const afterMembers = afterData.members || [];
        // Prüfen ob ein Member entfernt wurde
        const removedMembers = beforeMembers.filter((member) => !afterMembers.includes(member));
        if (removedMembers.length > 0) {
            console.log(`Members aus Liste ${listId} entfernt: ${removedMembers.join(', ')}`);
            // FCM Tokens für alle verbleibenden Members abrufen
            const memberTokens = [];
            for (const memberId of afterMembers) {
                const userDoc = await db.collection('users').doc(memberId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                    if (fcmToken) {
                        memberTokens.push(fcmToken);
                    }
                }
            }
            if (memberTokens.length === 0) {
                console.log('Keine FCM Tokens für Benachrichtigungen gefunden');
                return;
            }
            // Benachrichtigung senden
            const response = await messaging.sendEachForMulticast({
                tokens: memberTokens,
                notification: {
                    title: 'Member verlassen',
                    body: `${removedMembers.length} Member hat die Liste verlassen`,
                },
                data: {
                    type: 'member_removed',
                    listId: listId,
                    removedMembers: removedMembers.join(','),
                },
            });
            console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
        }
    }
    catch (error) {
        console.error('Fehler beim Senden der Benachrichtigung:', error);
    }
});
// Test-Function für Push-Benachrichtigungen
exports.sendTestNotification = (0, https_1.onCall)({
    region: 'europe-west3',
    maxInstances: 10,
}, async (request) => {
    try {
        const { fcmToken, title = 'Test Nachricht', body = 'Das ist eine Test-Benachrichtigung!' } = request.data;
        if (!fcmToken) {
            throw new Error('FCM Token ist erforderlich');
        }
        const message = {
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: 'test',
                timestamp: Date.now().toString(),
            },
            token: fcmToken,
        };
        const response = await messaging.send(message);
        console.log('Test-Benachrichtigung erfolgreich gesendet:', response);
        return {
            success: true,
            messageId: response,
            message: 'Test-Benachrichtigung erfolgreich gesendet'
        };
    }
    catch (error) {
        console.error('Fehler beim Senden der Test-Benachrichtigung:', error);
        throw new Error(`Fehler beim Senden der Benachrichtigung: ${error}`);
    }
});
//# sourceMappingURL=index.js.map