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
- **Chat-Symbol nur bei zusätzlichen Teilnehmern** - Intelligente Anzeige basierend auf Teilnehmerzahl
- **Badge-Counter für ungelesene Nachrichten** - Rote Badge-Anzeige mit Anzahl
- **Echtzeit-Updates** der ungelesenen Nachrichten
- **Automatische Markierung als gelesen** beim Öffnen des Chats
- Nachrichten werden in Echtzeit synchronisiert (Firestore)
- Beim Löschen eines Todos wird auch der zugehörige Chat gelöscht

### 👤 Benutzerverwaltung
- Registrierung und Login über Firebase Auth
- Profilverwaltung mit Avatar-Upload (Firebase Storage)
- Sichere Authentifizierung
- Benutzerprofile mit Anzeigename

### 🎨 Moderne UI/UX (erweitert)
- **9 wunderschöne Themes**: Light, Matrix, Neo, Summer, Aurora, Sunset, Ocean, Forest, Galaxy
  - **Aurora**: Nordlichter-inspiriert mit grünen und blauen Akzenten
  - **Sunset**: Warme Orange- und Rottöne für gemütliche Atmosphäre
  - **Ocean**: Beruhigende Blau- und Türkistöne
  - **Forest**: Natürliche Grüntöne für eine frische Umgebung
  - **Galaxy**: Mystische Lila- und Violettöne für kosmische Atmosphäre
- Kategorie-Auswahl beim Todo-Erstellen als Dropdown mit den wichtigsten Kategorien (Arbeit, Privat, Einkaufen, Haushalt, Gesundheit, Lernen, Sonstiges, Benutzerdefiniert)
- Alle Listen- und Todo-Ansichten sind für Kontrast und Lesbarkeit optimiert
- **Responsives Split-View-Layout:**
  - Automatische Umschaltung zwischen einspaltigem Layout (Mobil) und Split-View (macOS/iPad/Desktop)
  - Split-View zeigt links die Listenübersicht, rechts die Details (z.B. Todos, Chat)
  - Moderne, adaptive UI für alle Bildschirmgrößen
- **Badge-Counter für ungelesene Chat-Nachrichten:**
  - Rote Badge-Anzeige am Chat-Icon bei ungelesenen Nachrichten
  - Automatische Markierung als gelesen beim Öffnen des Chats
  - Echtzeit-Updates der ungelesenen Nachrichtenanzahl
  - **Intelligente Chat-Sichtbarkeit**: Chat-Symbol nur bei zusätzlichen Teilnehmern

## Technische Architektur

### State Management
- **BLOC Pattern** für saubere Architektur
- Separate BLOCs für Auth, Todo, Shopping, Share, List und Theme
- Event-driven Architecture
- Predictable State Management

### Datenmodelle
- **UserModel**: Benutzerdaten mit Avatar
- **ListModel**: Listen mit automatisch generierten Codes, Bearbeitungsberechtigung und Mitgliedernamen
- **TodoModel**: Todos mit Priorität, Fälligkeit, Zuweisungen und "Erledigt von"-Information (zugeordnet zu Listen)
- **ShoppingItemModel**: Einkaufslisten-Items mit Menge (zugeordnet zu Listen)
- **ShareModel**: Geteilte Listen mit Codes und Mitgliedern
- **ChatMessageModel**: Nachrichten mit todoId, userId, userName, message, timestamp und isRead-Status

### Repository Pattern
- Abstrakte Repository-Interfaces
- **Firebase-Implementierungen** für Produktion
- Mock-Implementierungen für Entwicklung
- **Stream-basierte APIs** für Echtzeit-Updates

### Firebase-Integration
- **Firebase Auth**: Sichere Benutzerauthentifizierung
- **Cloud Firestore**: Echtzeit-Datenbank mit Streams
- **Firebase Storage**: Avatar-Upload (geplant)
- **Echtzeit-Synchronisation**: Alle Änderungen werden sofort übertragen

## Installation

1. **Flutter installieren**
   ```bash
   flutter --version
   ```

2. **Firebase-Projekt einrichten**
   - Firebase-Projekt erstellen
   - Firebase CLI installieren
   - `firebase_options.dart` konfigurieren

3. **Dependencies installieren**
   ```bash
   flutter pub get
   ```

4. **App starten**
   ```bash
   flutter run
   ```

## Firebase-Konfiguration

Die App verwendet Firebase für:
- **Authentifizierung**: Registrierung und Login
- **Datenbank**: Echtzeit-Synchronisation aller Listen und Items
- **Storage**: Avatar-Upload (in Entwicklung)

### Firestore Collections
- `users`: Benutzerprofile
- `lists`: Todo- und Einkaufslisten (mit Bearbeitungsberechtigung)
- `todos`: Todo-Items
- `shopping_items`: Einkaufslisten-Items
- `shares`: Geteilte Listen
- `chatMessages`: Chat-Nachrichten pro Todo

## Echtzeit-Features

### Live-Updates
- **Todo-Listen**: Neue, bearbeitete und gelöschte Todos werden sofort angezeigt
- **Einkaufslisten**: Gekaufte Items werden sofort synchronisiert
- **Listen-Management**: Neue Listen und Mitglieder werden sofort sichtbar
- **Sharing**: Beitritte und Verlassen werden sofort übertragen
- **Chat-System**: Nachrichten und Badge-Counter werden in Echtzeit aktualisiert
- **Teilnehmer-Prüfung**: Chat-Symbol erscheint/verschwindet sofort bei Teilnehmer-Änderungen

### Stream-basierte Architektur
- Firestore-Streams für Echtzeit-Updates
- Automatische UI-Aktualisierung
- Effiziente Datenübertragung
- Offline-Unterstützung

## Bearbeitungsberechtigung & Todo-Zuweisungen

### Bearbeitungsberechtigung
- **Beim Erstellen**: Wähle aus, ob andere Mitglieder bearbeiten dürfen
- **Visuelle Hinweise**: "Nur-Lese-Modus" wird klar angezeigt
- **UI-Anpassungen**: 
  - FloatingActionButton wird deaktiviert
  - Checkboxen werden deaktiviert
  - Delete-Buttons werden ausgeblendet
  - Informationsbanner wird angezeigt

### Berechtigungslogik
- **Besitzer**: Kann immer alles bearbeiten
- **Mitglieder mit Bearbeitungsberechtigung**: Können Items hinzufügen, bearbeiten und löschen
- **Mitglieder ohne Bearbeitungsberechtigung**: Können nur lesen

### Todo-Zuweisungen
- **Beim Erstellen**: Wähle optional einen Benutzer aus, dem das Todo zugewiesen werden soll
- **Visuelle Unterscheidung**:
  - Hellgrüne Outline für dir zugewiesene Todos
  - Hellblaue Darstellung für anderen zugewiesene Todos
  - "Dir zugewiesen" / "Zugewiesen an [Name]" Badges
- **Berechtigungssteuerung**:
  - Allgemeine Todos: Können von allen erledigt werden
  - Zugewiesene Todos: Können nur vom zugewiesenen Benutzer erledigt werden
  - Besitzer können immer alle Todos erledigen
- **"Erledigt von"-Anzeige**: Zeigt den Namen des Benutzers, der das Todo erledigt hat

### Sicherheit
- Berechtigungen werden serverseitig in Firestore gespeichert
- Client-seitige Validierung für bessere UX
- Echtzeit-Updates der Berechtigungen und Zuweisungen

### ✅ Konsistente Berechtigungen
- Erledigen und Löschen von Todos ist nur für berechtigte Nutzer möglich (Besitzer oder zugewiesene Person)

## Projektstruktur

```
lib/
├── blocs/           # BLOC State Management
│   ├── auth/        # Authentifizierung
│   ├── todo/        # Todo-Verwaltung
│   ├── shopping/    # Einkaufslisten
│   ├── share/       # Listen teilen
│   ├── list/        # Listen-Management
│   └── theme/       # Theme-Verwaltung
├── models/          # Datenmodelle
├── repositories/    # Datenzugriff (Firebase + Mock)
│   ├── auth_repository.dart
│   ├── todo_repository.dart
│   ├── shopping_repository.dart
│   ├── share_repository.dart
│   └── list_repository.dart
├── screens/         # UI-Screens
│   ├── auth/        # Login/Register
│   ├── home/        # Hauptnavigation
│   ├── lists/       # Listen-Übersicht
│   ├── todo/        # Todo-Screens (mit Echtzeit-Streams + Berechtigungen)
│   ├── shopping/    # Shopping-Screens (mit Echtzeit-Streams + Berechtigungen)
│   ├── share/       # Share-Screens
│   └── profile/     # Profilverwaltung
├── widgets/         # Wiederverwendbare Widgets
│   ├── todo/        # Todo-Widgets (mit Berechtigungsprüfung)
│   ├── shopping/    # Shopping-Widgets (mit Berechtigungsprüfung)
│   ├── share/       # Share-Widgets
│   ├── lists/       # Listen-Widgets (mit Bearbeitungsberechtigung)
│   └── theme/       # Theme-Widgets
├── utils/           # Utilities und Themes
├── firebase_options.dart  # Firebase-Konfiguration
└── main.dart        # App-Einstiegspunkt
```

### 🔌 Architektur (erweitert)
- **ChatRepository**: Firestore-Implementierung für Chat pro Todo
- Chat-Provider global eingebunden (Provider-Fix)

## Responsive Design

Die App ist vollständig responsive und unterstützt:
- **Mobile**: iPhone und Android
- **Tablet**: iPad und Android Tablets
- **Web**: Desktop und Mobile Browser

## Entwicklung

### Dependencies
- **flutter_bloc**: State Management
- **go_router**: Navigation
- **google_fonts**: Typography
- **intl**: Internationalisierung
- **equatable**: Value Equality
- **firebase_core**: Firebase Core
- **firebase_auth**: Firebase Authentication
- **cloud_firestore**: Firestore Database
- **firebase_storage**: Firebase Storage

### Code-Qualität
- Linting mit flutter_lints
- Saubere Architektur
- Testbare Komponenten
- Dokumentierter Code

## Lizenz

Dieses Projekt ist für private und kommerzielle Nutzung freigegeben.

## Support

Bei Fragen oder Problemen erstelle bitte ein Issue im Repository.
