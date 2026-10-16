<!--
Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
Written by Martin Bundschuh.
-->

# Ausrollen: Release (Stufe 4 + Familienkalender)

Stand 2026-10-16, Branch `release`. Diese Liste wurde nur vorbereitet. Ausgerollt
ist noch nichts. Die Reihenfolge ist wichtig: zuerst Server (Regeln, Indizes,
Functions), dann die App.

## 0. Vorher

- [ ] Martin bestätigt die Screenshots bzw. den Testlauf (Regel: erst belegen,
      dann hinauslassen).
- [ ] `git fetch` und mit dem Ziel-Branch vergleichen, ob seitdem etwas
      dazugekommen ist.
- [ ] Prüfen: `npm --prefix functions test` (Build, Logik, alle Emulator-Tests)
      und `flutter analyze`, `flutter test` sind grün.

## 1. Firestore-Indizes

```
firebase deploy --only firestore:indexes --project togetherdo-c9179
```

Neu: `termine` (listId ↑, sichtbarBis ↑). Bestehend: `todos` (listId ↑,
completedAt ↑) sowie die Feldausnahme für `chatMessages.userId`.

- [ ] Fragt firebase, ob live vorhandene Indizes gelöscht werden sollen:
      **immer N**. Vorher die Datei mit den live vorhandenen Indizes abgleichen.
- [ ] Warten, bis der Index in der Konsole „Aktiviert“ zeigt. Erst dann
      Kalender-Abfragen in der App nutzen.

## 2. Firestore-Regeln und Storage-Regeln

```
firebase deploy --only firestore:rules,storage --project togetherdo-c9179
```

Was neu ist:
- Firestore: `termine` (lesen/anlegen = Mitglied, ändern/löschen = Ersteller
  oder Besitzer/Mitglied mit allowEdit). Gemeinsame Untersammlung
  `anhaenge` unter `todos/{id}` und `termine/{id}` (anhängen = Mitglied,
  löschen = Hochlader oder Bearbeitungsrecht). Chat-Bilder nur noch als
  Pfade unter der eigenen Aufgabe (`imagePath`, `imagePreviewPath`), keine
  offene Download-Adresse mehr.
- Storage: `todos/…`, `termine/…` (Bilder bis 10 MB, PDFs/Dokumente bis
  20 MB) und `chats/…` (nur Bilder). Metadatum `hochgeladenVon` ist Pflicht,
  Überschreiben verboten.

## 3. Secrets (setzt Martin)

Die Mail-Functions (Erinnerungen, Wochen- und Monatsüberblick,
Einladungen) brauchen die SMTP-Zugangsdaten von Amazon SES
(Region eu-north-1, Absender `noreply@seebubble.me`):

```
firebase functions:secrets:set SES_SMTP_USER --project togetherdo-c9179
firebase functions:secrets:set SES_SMTP_PASSWORD --project togetherdo-c9179
```

- [ ] Werte nur im Terminal eingeben, nie in Dateien, Chat oder Wiki.
- [ ] Secret Manager API und Cloud Scheduler API müssen im Projekt aktiv sein
      (firebase fragt beim ersten Ausrollen danach).

## 4. Cloud Functions

```
npm --prefix functions run build
firebase deploy --only functions --project togetherdo-c9179
```

Neu:
- `onTerminCreated`: Push „Neuer Termin“ an betroffene Mitglieder.
- `onTerminDeleted`: löscht `termine/{id}/anhaenge` und die Dateien unter
  `termine/{listId}/{terminId}/`.
- `erinnerungenSenden`: alle 5 Minuten, Push oder Mail mit .ics.
- `wochenueberblickSenden`: sonntags 18:00 (Europe/Vienna).
- `monatsueberblickSenden`: am 1. des Monats um 07:00.
- `inviteByEmail`: Einladung per Mail (Callable).
- `mailEinstellungen`: Abmelde- und Einstellungslink aus den Mails (HTTP).

Geändert:
- `onListDeleted` (über `deleteListContent`): räumt jetzt Todos (mit Chat
  und Anhängen), Einkaufsartikel und Termine (mit Anhängen) auf. Außerdem
  die Storage-Bereiche `todos/`, `chats/` und `termine/` der Liste.
- `onTodoDeleted`: löscht Chat und Untersammlung `anhaenge` sowie die
  Dateien unter `todos/…` und `chats/…`.
- `deleteAccount` / `onUserDeleted`: gemeinsame Aufräumfunktionen wie oben.

Entfällt: `onListDeletedTermine`, weil das jetzt `onListDeleted` mit erledigt.
Sie sollte live nicht existieren, weil der Kalender-Branch nie ausgerollt wurde. Fragt firebase trotzdem nach dem Löschen,
vorher die live vorhandenen Functions prüfen.

- [ ] Nach dem Ausrollen: Testtermin mit Erinnerung in 10 Minuten anlegen
      (Martins Konto) und prüfen, dass Push bzw. Mail ankommt.

## 5. App

- Vorschlag Version: **1.4.0+11** (bisher 1.3.0+10). Neue Funktionen
  (Kalender, Anhänge, neue Startseite) rechtfertigen die Minor-Stufe. Die
  Nummer wird beim Ausliefern gesetzt, nicht im Branch hochgezählt.
- macOS-Mindestversion 12.0: Das Flutter-Engine-Pod `FlutterMacOS` verlangt
  12.0, deshalb bleibt die Anhebung aus Stufe 4.
- iOS: `pod install` ist erledigt (file_picker, share_plus, path_provider,
  url_launcher). Gerätebuild ohne Signatur geprüft
  (`xcodebuild -configuration Release -destination generic/platform=iOS`).
- [ ] TestFlight bzw. Play erst nach Martins Freigabe (fastlane nur einmal
      starten, Build-Nummern danach committen).

## Hinweis Datenform

Anhänge liegen bei Aufgaben und Terminen jetzt einheitlich in der
Untersammlung `anhaenge`. Das frühere Array `anhaenge` im Termin-Dokument
und `todos/{id}/attachments` aus den Zwischenständen waren nie live.
Eine Migration ist deshalb nicht nötig.
