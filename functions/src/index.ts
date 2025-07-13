import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Cloud Function für neue Todo-Items
export const onTodoCreated = onDocumentCreated({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
  try {
    const todoData = event.data?.data();
    const todoId = event.params.todoId;
    const createdBy = todoData?.createdBy;
    const listId = todoData?.listId;

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
    const members = listData?.members || [];

    // FCM Tokens für alle Members außer dem Ersteller abrufen
    const memberTokens: string[] = [];
    
    for (const memberId of members) {
      if (memberId !== createdBy) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
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
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    });
    console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
});

// Cloud Function für erledigte Todo-Items
export const onTodoCompleted = onDocumentUpdated({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
  try {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
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
      const members = listData?.members || [];

      // FCM Tokens für alle Members außer dem, der es erledigt hat
      const memberTokens: string[] = [];
      
      for (const memberId of members) {
        if (memberId !== completedBy) {
          const userDoc = await db.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            const fcmToken = userData?.fcmToken;
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
        android: {
          notification: {
            sound: 'notification_sound',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notification_sound.caf',
            },
          },
          headers: {
            'apns-priority': '10',
          },
        },
      });
      console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
    }
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
});

// Cloud Function für gelöschte Todo-Items
export const onTodoDeleted = onDocumentDeleted({ region: 'europe-west3', document: 'todos/{todoId}' }, async (event) => {
  try {
    const todoData = event.data?.data();
    const todoId = event.params.todoId;
    const deletedBy = todoData?.deletedBy || todoData?.createdBy;
    const listId = todoData?.listId;

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
    const members = listData?.members || [];

    // FCM Tokens für alle Members außer dem, der es gelöscht hat
    const memberTokens: string[] = [];
    
    for (const memberId of members) {
      if (memberId !== deletedBy) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
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
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    });
    console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
});

// Cloud Function für neue List-Members
export const onListMemberAdded = onDocumentUpdated({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
  try {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const listId = event.params.listId;

    if (!beforeData || !afterData) {
      console.log('Ungültige Listen-Daten');
      return;
    }

    const beforeMembers = beforeData.members || [];
    const afterMembers = afterData.members || [];

    // Prüfen ob ein neuer Member hinzugefügt wurde
    const newMembers = afterMembers.filter((member: string) => !beforeMembers.includes(member));

    if (newMembers.length > 0) {
      console.log(`Neue Members in Liste ${listId}: ${newMembers.join(', ')}`);

      // FCM Tokens für alle bestehenden Members abrufen
      const memberTokens: string[] = [];
      
      for (const memberId of beforeMembers) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
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
        android: {
          notification: {
            sound: 'notification_sound',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notification_sound.caf',
            },
          },
          headers: {
            'apns-priority': '10',
          },
        },
      });
      console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
    }
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
});

// Cloud Function für entfernte List-Members
export const onListMemberRemoved = onDocumentUpdated({ region: 'europe-west3', document: 'lists/{listId}' }, async (event) => {
  try {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const listId = event.params.listId;

    if (!beforeData || !afterData) {
      console.log('Ungültige Listen-Daten');
      return;
    }

    const beforeMembers = beforeData.members || [];
    const afterMembers = afterData.members || [];

    // Prüfen ob ein Member entfernt wurde
    const removedMembers = beforeMembers.filter((member: string) => !afterMembers.includes(member));

    if (removedMembers.length > 0) {
      console.log(`Members aus Liste ${listId} entfernt: ${removedMembers.join(', ')}`);

      // FCM Tokens für alle verbleibenden Members abrufen
      const memberTokens: string[] = [];
      
      for (const memberId of afterMembers) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
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
        android: {
          notification: {
            sound: 'notification_sound',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notification_sound.caf',
            },
          },
          headers: {
            'apns-priority': '10',
          },
        },
      });
      console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
    }
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
}); 

// Test-Function für Push-Benachrichtigungen
export const sendTestNotification = onCall({ 
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
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
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
    
  } catch (error) {
    console.error('Fehler beim Senden der Test-Benachrichtigung:', error);
    throw new Error(`Fehler beim Senden der Benachrichtigung: ${error}`);
  }
});

// Test-Function für Chat-Push-Benachrichtigungen
export const sendTestChatNotification = onCall({ 
  region: 'europe-west3',
  maxInstances: 10,
}, async (request) => {
  try {
    const { fcmToken } = request.data;
    
    if (!fcmToken) {
      throw new Error('FCM Token ist erforderlich');
    }

    const message = {
      notification: {
        title: 'Test User hat eine Nachricht geschrieben',
        body: 'Das ist eine Test-Chat-Nachricht!',
      },
      data: {
        type: 'chat_message',
        messageId: 'test_message_id',
        todoId: 'test_todo_id',
        listId: 'test_list_id',
        todoTitle: 'Test Todo',
        userId: 'test_user_id',
        userName: 'Test User',
        message: 'Das ist eine Test-Chat-Nachricht!',
      },
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
      token: fcmToken,
    };

    const response = await messaging.send(message);
    
    console.log('Test-Chat-Benachrichtigung erfolgreich gesendet:', response);
    
    return {
      success: true,
      messageId: response,
      message: 'Test-Chat-Benachrichtigung erfolgreich gesendet'
    };
    
  } catch (error) {
    console.error('Fehler beim Senden der Test-Chat-Benachrichtigung:', error);
    throw new Error(`Fehler beim Senden der Chat-Benachrichtigung: ${error}`);
  }
}); 

// Cloud Function für neue Chat-Nachrichten
export const onChatMessageCreated = onDocumentCreated({ region: 'europe-west3', document: 'chatMessages/{messageId}' }, async (event) => {
  try {
    const messageData = event.data?.data();
    const messageId = event.params.messageId;
    const todoId = messageData?.todoId;
    
    // Unterstütze verschiedene Feldnamen
    const userId = messageData?.userId || messageData?.senderId;
    const userName = messageData?.userName || messageData?.senderName;
    const message = messageData?.message;

    console.log('Chat-Nachrichten-Daten:', messageData);

    if (!messageData || !todoId || !userId || !userName || !message) {
      console.log('Ungültige Chat-Nachrichten-Daten');
      console.log('  messageData:', messageData);
      console.log('  todoId:', todoId);
      console.log('  userId:', userId);
      console.log('  userName:', userName);
      console.log('  message:', message);
      return;
    }

    console.log(`Neue Chat-Nachricht erstellt: ${messageId} für Todo: ${todoId}`);

    // Todo abrufen um List-ID zu bekommen
    const todoDoc = await db.collection('todos').doc(todoId).get();
    if (!todoDoc.exists) {
      console.log('Todo nicht gefunden');
      return;
    }

    const todoData = todoDoc.data();
    const listId = todoData?.listId;
    const todoTitle = todoData?.title;

    if (!listId || !todoTitle) {
      console.log('Todo-Daten unvollständig');
      return;
    }

    // Liste abrufen um Members zu bekommen
    const listDoc = await db.collection('lists').doc(listId).get();
    if (!listDoc.exists) {
      console.log('Liste nicht gefunden');
      return;
    }

    const listData = listDoc.data();
    const members = listData?.members || [];

    // FCM Tokens für alle Members außer dem Sender abrufen
    const memberTokens: string[] = [];
    
    for (const memberId of members) {
      if (memberId !== userId) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
          if (fcmToken) {
            memberTokens.push(fcmToken);
          }
        }
      }
    }

    if (memberTokens.length === 0) {
      console.log('Keine FCM Tokens für Chat-Benachrichtigungen gefunden');
      return;
    }

    // Benachrichtigung senden
    const notificationData = {
      type: 'chat_message',
      messageId: messageId,
      todoId: todoId,
      listId: listId,
      todoTitle: todoTitle,
      userId: userId,
      userName: userName,
      message: message,
    };

    console.log('Sende Chat-Benachrichtigung mit Daten:', notificationData);

    const response = await messaging.sendEachForMulticast({
      tokens: memberTokens,
      notification: {
        title: `${userName} hat eine Nachricht geschrieben`,
        body: message.length > 50 ? `${message.substring(0, 50)}...` : message,
      },
      data: notificationData,
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    });
    console.log(`Chat-Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
  } catch (error) {
    console.error('Fehler beim Senden der Chat-Benachrichtigung:', error);
  }
}); 

// Cloud Function für neue Shopping-Items
export const onShoppingItemCreated = onDocumentCreated({ region: 'europe-west3', document: 'shoppingItems/{itemId}' }, async (event) => {
  try {
    const itemData = event.data?.data();
    const itemId = event.params.itemId;
    const createdBy = itemData?.createdBy;
    const listId = itemData?.listId;

    if (!itemData || !createdBy || !listId) {
      console.log('Ungültige Shopping-Item-Daten');
      return;
    }

    console.log(`Neues Shopping-Item erstellt: ${itemId} in Liste: ${listId}`);

    // Liste abrufen um Members zu bekommen
    const listDoc = await db.collection('lists').doc(listId).get();
    if (!listDoc.exists) {
      console.log('Liste nicht gefunden');
      return;
    }

    const listData = listDoc.data();
    const members = listData?.members || [];

    // FCM Tokens für alle Members außer dem Ersteller abrufen
    const memberTokens: string[] = [];
    
    for (const memberId of members) {
      if (memberId !== createdBy) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
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
        title: 'Neues Einkaufsitem',
        body: `${itemData.name} wurde zur Einkaufsliste hinzugefügt`,
      },
      data: {
        type: 'shopping_item_created',
        itemId: itemId,
        listId: listId,
        createdBy: createdBy,
      },
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    });
    console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
});

// Cloud Function für gekaufte Shopping-Items
export const onShoppingItemPurchased = onDocumentUpdated({ region: 'europe-west3', document: 'shoppingItems/{itemId}' }, async (event) => {
  try {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const itemId = event.params.itemId;

    if (!beforeData || !afterData) {
      console.log('Ungültige Shopping-Item-Daten');
      return;
    }

    // Prüfen ob Item von nicht gekauft zu gekauft geändert wurde
    if (!beforeData.purchased && afterData.purchased) {
      const listId = afterData.listId;
      const purchasedBy = afterData.purchasedBy || afterData.createdBy;

      console.log(`Shopping-Item gekauft: ${itemId} in Liste: ${listId}`);

      // Liste abrufen
      const listDoc = await db.collection('lists').doc(listId).get();
      if (!listDoc.exists) {
        console.log('Liste nicht gefunden');
        return;
      }

      const listData = listDoc.data();
      const members = listData?.members || [];

      // FCM Tokens für alle Members außer dem, der es gekauft hat
      const memberTokens: string[] = [];
      
      for (const memberId of members) {
        if (memberId !== purchasedBy) {
          const userDoc = await db.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            const fcmToken = userData?.fcmToken;
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
          title: 'Item gekauft',
          body: `${afterData.name} wurde als gekauft markiert`,
        },
        data: {
          type: 'shopping_item_purchased',
          itemId: itemId,
          listId: listId,
          purchasedBy: purchasedBy,
        },
        android: {
          notification: {
            sound: 'notification_sound',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notification_sound.caf',
            },
          },
          headers: {
            'apns-priority': '10',
          },
        },
      });
      console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
    }
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
});

// Cloud Function für gelöschte Shopping-Items
export const onShoppingItemDeleted = onDocumentDeleted({ region: 'europe-west3', document: 'shoppingItems/{itemId}' }, async (event) => {
  try {
    const itemData = event.data?.data();
    const itemId = event.params.itemId;
    const deletedBy = itemData?.deletedBy || itemData?.createdBy;
    const listId = itemData?.listId;

    if (!itemData || !deletedBy || !listId) {
      console.log('Ungültige Shopping-Item-Daten');
      return;
    }

    console.log(`Shopping-Item gelöscht: ${itemId} in Liste: ${listId}`);

    // Liste abrufen
    const listDoc = await db.collection('lists').doc(listId).get();
    if (!listDoc.exists) {
      console.log('Liste nicht gefunden');
      return;
    }

    const listData = listDoc.data();
    const members = listData?.members || [];

    // FCM Tokens für alle Members außer dem, der es gelöscht hat
    const memberTokens: string[] = [];
    
    for (const memberId of members) {
      if (memberId !== deletedBy) {
        const userDoc = await db.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
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
        title: 'Einkaufsitem gelöscht',
        body: `${itemData.name} wurde aus der Einkaufsliste entfernt`,
      },
      data: {
        type: 'shopping_item_deleted',
        itemId: itemId,
        listId: listId,
        deletedBy: deletedBy,
      },
      android: {
        notification: {
          sound: 'notification_sound',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'notification_sound.caf',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    });
    console.log(`Benachrichtigungen gesendet: ${response.successCount}/${memberTokens.length}`);
  } catch (error) {
    console.error('Fehler beim Senden der Benachrichtigung:', error);
  }
}); 