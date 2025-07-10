const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Test-Function für Push-Benachrichtigungen
exports.sendTestNotification = functions
  .region('europe-west3')
  .runWith({
    timeoutSeconds: 60,
    memory: '256MiB',
  })
  .v2()
  .https.onCall(async (data, context) => {
    try {
      const { fcmToken, title = 'Test Nachricht', body = 'Das ist eine Test-Benachrichtigung!' } = data;
      
      if (!fcmToken) {
        throw new functions.https.HttpsError('invalid-argument', 'FCM Token ist erforderlich');
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

      const response = await admin.messaging().send(message);
      
      console.log('Test-Benachrichtigung erfolgreich gesendet:', response);
      
      return {
        success: true,
        messageId: response,
        message: 'Test-Benachrichtigung erfolgreich gesendet'
      };
      
    } catch (error) {
      console.error('Fehler beim Senden der Test-Benachrichtigung:', error);
      throw new functions.https.HttpsError('internal', 'Fehler beim Senden der Benachrichtigung', error);
    }
  }); 