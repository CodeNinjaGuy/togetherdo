# ToGetherDo

Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
Written by Martin Bundschuh.

Gemeinsame Todo- und Einkaufslisten für Paare, Familien und WGs – Flutter-App
(iOS, macOS, Android, Web) mit Firebase.

## Was die App kann

- **Listen**: Todo- und Einkaufslisten anlegen, per 6-stelligem Code teilen
  und beitreten. Besitzer bestimmen, ob Mitglieder bearbeiten dürfen
  (`allowEdit`), können Mitglieder entfernen und die Liste löschen;
  Mitglieder können austreten.
- **Todos**: Titel, Beschreibung, Fälligkeit mit Uhrzeit, Priorität, Kategorie,
  Zuweisung an ein Mitglied, „erledigt von“. Gruppieren nach Status oder
  Person, sortieren nach Fälligkeit, Priorität oder Erstellung.
- **Einkauf**: Artikel mit Menge, Einheit und Notiz, „gekauft von“.
- **Chat pro Todo** mit Ungelesen-Zähler.
- **Push** über Firebase Cloud Messaging, je Ereignis im Profil abschaltbar.
- **Konto**: Registrierung/Anmeldung mit E-Mail, „Passwort vergessen“,
  Profilbild (Kamera/Fotos), Kontolöschung mit allen Daten.
- **Design**: 10 Themes (u. a. Fiberoptics25), Deutsch und Englisch,
  Split-View auf iPad/Mac/Desktop.

## Aufbau

| Bereich | Ort |
|---|---|
| Zustand | BLoC je Bereich (`lib/blocs/`) |
| Daten | Repositories mit Firebase-Implementierung (`lib/repositories/`) |
| Texte | ARB-Dateien `lib/l10n/app_de.arb`, `app_en.arb` → `flutter gen-l10n` |
| Rechtliche Links | `lib/config/legal_links.dart` (Datenschutz, Impressum) |
| Cloud Functions | `functions/src/*.ts` (TypeScript, Region europe-west3) |
| Firestore-Regeln | `firestore.rules`, Indizes `firestore.indexes.json` |
| Storage-Regeln | `storage.rules` |

### Firestore

- `users/{uid}` – Profil, FCM-Token, Benachrichtigungs-Einstellungen
- `lists/{id}` – Name, Typ, Besitzer, `shareCode`, `memberIds`/`memberNames`,
  `allUserIds` (Besitzer + Mitglieder), `allowEdit`
- `todos/{id}` mit Unterkollektion `chatMessages`
- `shopping_items/{id}`
- `rateLimits/{uid}` – nur Server (Drosselung beim Beitritt)

Die Regeln folgen dem Mitglieder-Prinzip: Listen und deren Inhalte sieht nur,
wer in `allUserIds` steht. Listen anlegen, per Code suchen und beitreten geht
nur über Functions.

### Cloud Functions

| Function | Zweck |
|---|---|
| `createList` | Liste mit eindeutigem Code anlegen |
| `previewListByCode`, `joinListByCode` | Vorschau und Beitritt per Code, gedrosselt (10 Fehlversuche/Stunde je Nutzer) |
| `deleteAccount` | Konto vollständig löschen (frische Anmeldung nötig, Auth-Konto zuletzt) |
| `onUserDeleted` | Aufräumen, wenn ein Konto anders gelöscht wird |
| `onListDeleted` | Todos, Chats und Artikel gelöschter Listen mitlöschen |
| `onTodo*`, `onShoppingItem*`, `onListMember*`, `onShoppingListMember*`, `onChatMessageCreated` | Push-Benachrichtigungen |
| `sendTestNotification` | Test-Push an das eigene Gerät |

Kontolöschung: Eigene Listen mit weiteren Mitgliedern gehen an das am längsten
beigetretene Mitglied über, Listen ohne Mitglieder werden samt Inhalt gelöscht.
Eigene Todos, Artikel und Nachrichten, Zuweisungen, Profilbild und Profil
(mit FCM-Token) werden entfernt.

## Entwickeln

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Version: nur `version:` in `pubspec.yaml` pflegen (iOS/macOS lesen
`FLUTTER_BUILD_NAME`/`FLUTTER_BUILD_NUMBER`).

### Lokal gegen die Firebase-Emulatoren (nie Produktion)

```bash
cd functions && npm install && npm run build && cd ..
firebase emulators:start --only auth,firestore,functions,storage --project demo-togetherdo
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

Tests für Regeln und Functions:

```bash
cd functions && npm run build && npm run test:emulator
```

## Ausrollen (nur nach Freigabe)

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project togetherdo-c9179
firebase deploy --only functions --project togetherdo-c9179
```

## Datenschutz

Daten liegen in Google Firebase (Firestore-Standort `eur3`, EU). Kein
Tracking, keine Werbung. Datenschutzerklärung und Impressum: siehe
`lib/config/legal_links.dart`.
