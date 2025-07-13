# TogetherDo - Eine professionelle Todo-App

Eine moderne Flutter-App für die Verwaltung von Todos und Einkaufslisten mit Echtzeit-Updates und Firebase-Integration.

## Features

### 📋 Listen-Management
- Erstelle beliebig viele Todo- und Einkaufslisten
- Übersicht aller Listen mit automatisch generierten 6-stelligen Codes
- Einfaches Beitreten zu Listen über Codes
- Listen nach Typ gruppiert (Todo/Einkaufslisten)
- Besitzer können Listen löschen, Mitglieder können verlassen
- **Bearbeitungsberechtigung**: Wähle beim Erstellen aus, ob andere Mitglieder bearbeiten dürfen

### ✅ Todo-Verwaltung
- Erstelle, bearbeite und lösche Todos in spezifischen Listen
- Optionales Fälligkeitsdatum mit Uhrzeit (24h-Format)
- Prioritätsstufen (Niedrig, Mittel, Hoch)
- Kategorisierung von Todos
- Status-Tracking (Ausstehend/Erledigt)
- **Flexible Gruppierung und Sortierung**:
  - Gruppierung nach Status (Ausstehend/Erledigt) oder Benutzer
  - Sortierung nach Fälligkeit, Priorität oder Erstellungsdatum
  - Benutzer-Gruppierung zeigt "Allgemein" und zugewiesene Benutzer
- Übersichtliche Listenansicht
- **Echtzeit-Updates** - Änderungen werden sofort für alle Mitglieder sichtbar
- **Bearbeitungsberechtigung**: Nur berechtigte Benutzer können Todos bearbeiten
- **Todo-Zuweisungen**: Weise Todos bestimmten Mitgliedern zu
  - Visuelle Unterscheidung: Hellgrüne Outline für dir zugewiesene Todos
  - Hellblaue Darstellung für anderen zugewiesene Todos
  - Berechtigungssteuerung: Zugewiesene Todos können nur vom zugewiesenen Benutzer erledigt werden
  - "Erledigt von"-Anzeige: Zeigt an, wer das Todo erledigt hat

### 🛒 Einkaufslisten
- Erstelle Einkaufslisten mit Menge und Einheit in spezifischen Listen
- Markiere Items als gekauft
- Notizen zu einzelnen Items
- Tracking wer was gekauft hat
- Responsive Listenansicht
- **Echtzeit-Updates** - Gekaufte Items werden sofort synchronisiert
- **Bearbeitungsberechtigung**: Nur berechtigte Benutzer können Items bearbeiten

### 🔗 Listen teilen
- Jede Liste erhält automatisch einen 6-stelligen Code
- Einfaches Teilen von Codes mit anderen Nutzern
- Beitreten zu fremden Listen über Codes
- **Besitzer-Anzeige**: Zeigt den Namen des Listenbesitzers beim Beitritt an
- Todo-Listen und Einkaufslisten teilbar
- **Echtzeit-Synchronisation** zwischen allen Mitgliedern
- **Bearbeitungsberechtigung**: Kontrolle über wer was bearbeiten darf
- Besitzer können Listen löschen, Mitglieder können verlassen

### 💬 Chat pro Todo
- Jeder Todo-Eintrag hat einen eigenen Chatraum
- Chat-Icon im Todo-Listeneintrag öffnet den ChatScreen
- Nachrichten werden in Echtzeit synchronisiert (Firestore)
- Beim Löschen eines Todos wird auch der zugehörige Chat gelöscht

### 🔔 Push-Benachrichtigungen (Erweitert)
- **Cloud Functions** für automatische Push-Benachrichtigungen
- **Intelligente Benachrichtigungseinstellungen** im Profil-Screen
- **Benutzerdefinierte Einstellungen**:
  - Todo-Benachrichtigungen: Neues Todo erstellt, Todo erledigt, Todo gelöscht
  - Member-Benachrichtigungen: Neuer Member beigetreten, Member verlassen
  - Chat-Benachrichtigungen: Neue Chat-Nachricht im Todo-Chat
  - Jede Einstellung kann individuell aktiviert/deaktiviert werden
- **Firestore-Integration**: Einstellungen werden in Firestore gespeichert und von Cloud Functions berücksichtigt
- **Intelligente Filterung**: Nur Benutzer mit aktivierten Einstellungen erhalten Benachrichtigungen
- **FCM Token-Management**: Automatische Token-Aktualisierung in Firestore
- **Multi-Plattform Support**: iOS, Android, macOS mit APNs/FCM
- **Test-Benachrichtigungen**: Lokale Test-Benachrichtigungen im Profil-Screen
- **Benutzerdefinierte Sounds**: Eigene Notification-Sounds für alle Plattformen
- **Sound-Tests**: Separate Buttons für Standard- und Custom-Sound Tests
- **Echtzeit-Synchronisation**: Einstellungsänderungen werden sofort wirksam

### 👤 Benutzerverwaltung
- Registrierung und Login über Firebase Auth
- Profilverwaltung mit Avatar-Upload (Firebase Storage)
- Sichere Authentifizierung
- Benutzerprofile mit Anzeigename

### 🎨 Moderne UI/UX (erweitert)
- Theme-Auswahl: Vier Themes (Light, Matrix, Neo, Summer) mit optimierten Kontrastfarben für beste Lesbarkeit
- Kategorie-Auswahl beim Todo-Erstellen als Dropdown mit den wichtigsten Kategorien (Arbeit, Privat, Einkaufen, Haushalt, Gesundheit, Lernen, Sonstiges, Benutzerdefiniert)
- Alle Listen- und Todo-Ansichten sind für Kontrast und Lesbarkeit optimiert
- **Responsives Split-View-Layout:**
  - Automatische Umschaltung zwischen einspaltigem Layout (Mobil) und Split-View (macOS/iPad/Desktop)
  - Split-View zeigt links die Listenübersicht, rechts die Details (z.B. Todos, Chat)
  - Moderne, adaptive UI für alle Bildschirmgrößen
- **10 wunderschöne Themes:**
  - Light, Matrix, Neo, Summer, Aurora, Sunset, Ocean, Forest, Galaxy, Fiberoptics25
  - Jedes Theme mit einzigartigen Farben, Schriften und Stilen
  - Aurora: Nordlichter-inspiriert mit grünen und blauen Akzenten
  - Sunset: Warme Orange- und Rottöne für gemütliche Atmosphäre
  - Ocean: Beruhigende Blau- und Türkistöne
  - Forest: Natürliche Grüntöne für eine frische Umgebung
  - Galaxy: Mystische Lila- und Violettöne für kosmische Atmosphäre
  - **Fiberoptics25**: Technologie-inspiriertes Theme mit Orange-Rot, Blau und Akzentfarben aus dem FO25-Logo
- **Badge-Counter für ungelesene Chat-Nachrichten:**
  - Rote Badge-Anzeige am Chat-Icon bei ungelesenen Nachrichten
  - Automatische Markierung als gelesen beim Öffnen des Chats
  - Echtzeit-Updates der ungelesenen Nachrichtenanzahl

## Technische Architektur

### State Management
- **BLOC Pattern** für saubere Architektur
- Separate BLOCs für Auth, Todo, Shopping, Share, List, Theme und Notification
- Event-driven Architecture
- Predictable State Management

### Datenmodelle
- **UserModel**: Benutzerdaten mit Avatar
- **ListModel**: Listen mit automatisch generierten Codes, Bearbeitungsberechtigung und Mitgliedernamen
- **TodoModel**: Todos mit Priorität, Fälligkeit, Zuweisungen und "Erledigt von"-Information (zugeordnet zu Listen)
- **ShoppingItemModel**: Einkaufslisten-Items mit Menge (zugeordnet zu Listen)
- **ShareModel**: Geteilte Listen mit Codes und Mitgliedern
- **ChatMessageModel**: Nachrichten mit todoId, userId, userName, message, timestamp
- **NotificationSettingsModel**: Benachrichtigungseinstellungen für jeden Benutzer

### Repository Pattern
- Abstrakte Repository-Interfaces
- **Firebase-Implementierungen** für Produktion
- Mock-Implementierungen für Entwicklung

### Firebase-Integration
- **Firebase Auth**: Sichere Benutzerauthentifizierung
- **Cloud Firestore**: Echtzeit-Datenbank mit Streams
- **Firebase Storage**: Avatar-Upload (geplant)
- **Firebase Cloud Functions**: Automatische Push-Benachrichtigungen mit Benutzer-Einstellungen
- **Firebase Cloud Messaging**: Push-Benachrichtigungen für alle Plattformen
- **Echtzeit-Synchronisation**: Alle Änderungen werden sofort übertragen

### Cloud Functions
- **onTodoCreated**: Benachrichtigung bei neuem Todo (berücksichtigt Einstellungen)
- **onTodoCompleted**: Benachrichtigung bei erledigtem Todo (berücksichtigt Einstellungen)
- **onTodoDeleted**: Benachrichtigung bei gelöschtem Todo (berücksichtigt Einstellungen)
- **onListMemberAdded**: Benachrichtigung bei neuem Member (berücksichtigt Einstellungen)
- **onListMemberRemoved**: Benachrichtigung bei entferntem Member (berücksichtigt Einstellungen)
- **onChatMessageCreated**: Benachrichtigung bei neuer Chat-Nachricht (berücksichtigt Einstellungen)
- **sendTestNotification**: Test-Benachrichtigungen für Debugging

## Installation

1. **Flutter installieren**
   ```bash
   flutter --version
   ```