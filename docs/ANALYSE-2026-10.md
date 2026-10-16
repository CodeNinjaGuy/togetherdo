# ToGetherDo – Analyse und Richtung (2026-10-16)

Stand: Repo `ToGetherDo`, Commit `e406bf2` (2025-07-17), nur gelesen und angesehen, nichts verändert.
Beim Lesen lief parallel eine andere Sitzung, die gerade den Avatar-Upload baut (`lib/services/avatar_service.dart`, `lib/widgets/common/user_avatar.dart`, `image`-Paket). Diese Änderungen sind hier nicht bewertet.

Screenshots (Web-Build, lokal): `/private/tmp/claude-501/-Users-martinbundschuh-Documents-Coding-SecondBrain/33362639-af21-4c5b-aab9-8981333d62ff/scratchpad/togetherdo/01-login-web.jpg`, `02-register-web.jpg`. Hinter dem Login konnte ich ohne Konto nichts ansehen (Produktions-Firebase, kein Testkonto angelegt). Der macOS-Debug-Build scheitert an der Signierung (`com.example.togetherdo` hat kein Profil), der Web-Build läuft.

---

## 1. Kernaussagen in drei Sätzen

1. Die App ist ein solides, kleines Fundament: geteilte Todo- und Einkaufslisten per 6-stelligem Code, Echtzeit über Firestore, Zuweisung, Chat pro Todo, Push, 10 Themes, DE/EN, Split-View auf Desktop/iPad.
2. Sie ist aber heute „noch eine Todo-App unter tausend“: nichts, was Bring!, AnyList, Apple Erinnerungen oder Any.do nicht auch können – und einiges (Passwort vergessen, Wiederholungen, Erinnerungen, Offline, Sortierung im Einkauf) fehlt.
3. Die Lücke im Markt ist **Fairness in der gemeinsamen Haushaltsarbeit** – kein Konkurrent aus der Todo-/Einkaufswelt macht sichtbar, *wer wie viel trägt*. Das ist meine Empfehlung für die Hauptrichtung: **ToGetherDo = die Listen-App, die fair verteilt.**

---

## 2. Bestandsaufnahme

### 2.1 Was die App heute kann
| Bereich | Stand |
|---|---|
| Konto | E-Mail/Passwort über Firebase Auth. Kein Google/Apple-Login, **kein „Passwort vergessen“** (kein `sendPasswordResetEmail` im Code). Kontolöschung mit Re-Auth, Fortschrittsdialog (Commit 3bc485d). |
| Listen | Zwei Typen (Todo, Einkauf). Jede Liste hat einen 6-stelligen Zahlencode, Beitritt per Code, Besitzer löscht, Mitglied verlässt. `allowEdit` pro Liste. Code wird in die Zwischenablage kopiert; kein Teilen-Sheet, kein Link, kein QR. |
| Todos | Titel, Beschreibung, Fälligkeit mit Uhrzeit, Priorität (3 Stufen), Kategorie (Dropdown), Zuweisung an Mitglied, „erledigt von“. Gruppieren nach Status/Benutzer, Sortieren nach Fälligkeit/Priorität/Erstellung. Keine Wiederholungen, keine lokalen Erinnerungen zur Fälligkeit (Methode `showTodoDueNotification` existiert, wird aber nirgends geplant), keine Unteraufgaben. |
| Einkauf | Artikel mit Menge + Einheit (11 Einheiten), Notiz, gekauft von/wann. Zwei Abschnitte (offen/gekauft). **Keine Kategorien, keine Sortierung nach Gang, keine Vorschläge/Autovervollständigung, keine Bilder, keine Rezepte, keine Mengen-Zusammenfassung.** |
| Chat | Ein Chat pro Todo (Unterkollektion `todos/{id}/chatMessages`), ungelesen-Badge. `isRead` ist **ein Flag pro Nachricht, nicht pro Leser** – in einer 3er-Liste verschwindet der Badge für alle, sobald einer liest. |
| Push | FCM + Cloud Functions (europe-west3): Todo erstellt/erledigt/gelöscht, Mitglied rein/raus, Chat, Einkaufsartikel erstellt/gekauft/gelöscht. Einstellungen pro Ereignis im Profil. Eigener Sound. Nur ein FCM-Token pro Nutzer (`users.fcmToken`) – wer iPhone **und** Mac nutzt, bekommt Push nur auf dem zuletzt angemeldeten Gerät. |
| Themes | 10 Themes (Light, Matrix, Neo, Summer, Aurora, Sunset, Ocean, Forest, Galaxy, Fiberoptics25) mit je eigener Google-Font. Fiberoptics25 = dunkel, Orange-Rot `#FF430B`, Roboto Mono, zeigt das FO25-Logo (SVG) im Profil. Kein System-Dark-Mode (kein `darkTheme`), Theme wird in SharedPreferences gehalten, nicht im Profil. |
| Sprachen | DE und EN (je 297 Schlüssel), Varianten de_AT/en_GB/en_US mit ~20 Abweichungen. **27 hartkodierte deutsche Texte** in `todo_screen.dart` („Meine Todos“, „Nach Status“, „Liste nicht gefunden“ …), `share_screen.dart`, `shopping_item_widget.dart`, `list_item_widget.dart`, Abschnittsüberschriften „Todo-Listen“/„Gekauft“. Englische Nutzer sehen gemischte Sprache. |
| Plattformen | iOS, macOS, Android, Web, Windows, Linux-Ordner vorhanden. Responsive: unter ~800 px Bottom-Navigation, darüber Split-View (`responsive_scaffold.dart`, eigener `profile_screen_desktop.dart`). |
| Architektur | BLoC pro Bereich, Repository-Interfaces mit Mock + Firebase-Implementierung, go_router mit ShellRoute. 17 300 Zeilen Dart. |

### 2.2 Datenmodell (Firestore, flach)
- `users/{uid}`: email, displayName, avatarUrl, fcmToken, notificationSettings, languageCode, countryCode
- `lists/{id}`: name, type, ownerId, ownerName, shareCode, memberIds[], memberNames[], allUserIds[] (= Owner + Mitglieder, für Abfragen), allowEdit
- `todos/{id}`: listId, userId, title, description, dueDate, priority, category, assignedTo*, completedBy*
- `todos/{id}/chatMessages/{id}`
- `shopping_items/{id}`: listId, userId, name, quantity, unit, notes, isPurchased, purchasedBy/At
- `shares/…` (altes Modul, s. u.)

Schwächen: `memberNames` läuft parallel zu `memberIds` als Index-gekoppelte Liste (fehleranfällig; in `deleteAccount` wird mit `name.contains(userId)` gefiltert – trifft nie). Namen werden in Listen und Todos **kopiert**, Umbenennen im Profil ändert sie dort nicht. Datumsfelder als ISO-Strings statt Timestamps (keine Server-Zeit, Sortierung in Firestore nicht möglich).

### 2.3 Code-Qualität und Halbfertiges
- `flutter analyze`: 11 Hinweise (veraltete `value:`/`groupValue:`-Parameter, `assets/icons/` fehlt → Warnung bei jedem Build).
- **Toter Code:** komplettes Share-Modul (`blocs/share`, `screens/share`, `widgets/share`, `repositories/share_repository.dart`, ~1 300 Zeilen) ist nicht mehr geroutet; die Code-Funktion lebt jetzt in `lists`. Alte Kollektion `shares` kann in Firestore liegen.
- **Functions: Quelle und Deployment klaffen auseinander.** `functions/src/index.ts` (TypeScript-Quelle) liest `list.members` und lauscht auf `chatMessages/{id}` – beides passt nicht zur App (die schreibt `allUserIds` und `todos/{id}/chatMessages`). Die kompilierte `functions/lib/index.js` ist neuer und richtig (allUserIds, Settings-Prüfung, Shopping-Functions). Ein `npm run build` überschreibt die funktionierende Version mit der kaputten. Außerdem ist `functions/node_modules/` ins Git eingecheckt, `functions/testNotification.js` ist ein Überbleibsel, `firebase.json` sagt Region `europe-west1`, der Code `europe-west3`.
- `MockAuthRepository` etc. (~600 Zeilen) werden nirgends benutzt.
- `README.md` beschreibt Dinge, die nicht stimmen: „Avatar-Upload (Firebase Storage)“ (ist Platzhalter), „4 Themes“ und „10 Themes“ nebeneinander, Projekt heißt dort „TogetherDo“, in der App „ToGetherDo“, im iOS-Plist „Togetherdo“. `web/index.html`: „A new Flutter project.“
- Kein einziger echter Test (`widget_test.dart` ist das Flutter-Template).
- Versionen: pubspec `1.0.0+1`, macOS-pbxproj `1.0`, iOS-pbxproj `MARKETING_VERSION = 2 / BUILD 3`. Der Mac-Store-Stand 1.2 ist aus diesem Repo nicht reproduzierbar → Versionsquelle festlegen (pubspec).
- `print`/`debugPrint`-Spam: keiner – gut.

### 2.4 Store-Risiken (Apple)
1. **Kamera-Knopf ohne Funktion** (`profile_screen.dart:69`, Snackbar „Avatar-Upload wird später implementiert“) – Richtlinie 2.1 (Platzhalter) und war Teil der Ablehnung. Wird gerade parallel gebaut; die Desktop-Variante `profile_screen_desktop.dart` muss ebenso mitziehen.
2. **Kontolöschung (5.1.1(v))** ist vorhanden, aber unvollständig: Todos, Einkaufsartikel und Chats der gelöschten Listen bleiben als Waisen in Firestore; Mitgliedernamen bleiben in fremden Listen; Avatar in Storage bleibt. Wenn `user.delete()` nach dem Löschen des Profils scheitert, existiert das Auth-Konto ohne Profil weiter („Benutzerprofil nicht gefunden“ beim nächsten Login). Reihenfolge: erst Re-Auth, dann Daten, dann Konto – und serverseitig (Cloud Function `onUserDeleted`) aufräumen.
3. **Datenschutz-Text widerspricht der App** (`app_de.arb:222`): „Keine Chat-Speicherung: Nachrichten werden nicht dauerhaft gespeichert“ – sie liegen dauerhaft in Firestore. Dazu „Keine Haftung“ als „Datenschutzrichtlinie“. Apple verlangt eine **echte Datenschutzerklärung als URL** (5.1.1(i)) im App Store Connect und in der App; die gibt es nicht. Das kann die nächste Ablehnung werden.
4. `NSAllowsArbitraryLoads = true` in `ios/Runner/Info.plist` – Apple fragt nach Begründung; Firebase braucht das nicht → entfernen.
5. `UIBackgroundModes` enthält `processing` und `fetch` plus `BGTaskSchedulerPermittedIdentifiers`, ohne dass die App Background-Tasks nutzt → Reviewer fragen nach, entfernen.
6. Entitlements beider Apple-Plattformen stehen auf `aps-environment = development`; für den Store braucht es `production` (Xcode setzt das beim Archiv meist automatisch, aber prüfen).
7. **Bundle-ID `com.example.togetherdo`**: Apple akzeptiert `com.example.*` technisch (die Mac-Version ist ja im Store), aber es ist der Flutter-Beispielwert; ohne Apple-ID-Prefix kann niemand anderes sie belegen, sie liegt also bei dir. Problem ist eher: iOS-Reviewer und Google Play. **Google Play lehnt `com.example`-Paketnamen ab** („You need to use a different package name because com.example is restricted“). Für Android **muss** sie geändert werden, bevor die erste Play-Veröffentlichung – und zwar vor dem ersten Upload, danach ist sie fix. Für iOS/macOS: belassen (Store-Identität, Keychain-Gruppe, APNs-Zertifikate hängen daran); eine Umbenennung hieße eine neue App im Store.
8. Signierung: `android/app/build.gradle.kts` signiert Release mit dem Debug-Schlüssel; kein Keystore eingerichtet.

### 2.5 Sicherheit
- **Es gibt keine `firestore.rules` und keine `storage.rules` im Repo**, `firebase.json` hat keinen `firestore`-Abschnitt. Die Regeln leben nur in der Firebase-Konsole – unbekannt, ob sie das Datenmodell absichern. Bei den flachen Kollektionen muss jede Regel für `todos`/`shopping_items` per `get()` die Mitgliedschaft in `lists/{listId}.allUserIds` prüfen und `userId`/`createdBy` gegen `request.auth.uid` absichern. Ohne Repo-Kopie ist das weder prüfbar noch versionierbar. ❓ Offene Frage: Wie lauten die Regeln in der Konsole (`togetherdo-c9179`)?
- Beitritt per **6-stelligem Zahlencode = 1 Mio. Möglichkeiten**, keine Ablaufzeit, keine Drosselung. Wer `lists` lesen darf (für `getListByCode` muss die Abfrage `where shareCode ==` erlaubt sein), kann Codes durchprobieren. Besser: Code 8 Zeichen alphanumerisch oder Einladungs-Link mit Ablauf, Beitritt über Cloud Function.
- Die Cloud Functions prüfen `sendTestNotification` nicht auf `request.auth` → jeder mit Projekt-ID kann an beliebige Tokens Push schicken (laut `lib/index.js:198` nicht geprüft; verifizieren).
- `Firebase API-Keys` in `firebase_options.dart` und `google-services.json` sind eingecheckt – das ist bei Firebase normal und unkritisch, solange die Regeln stimmen.
- FCM-Token wird einmal in `users.fcmToken` gehalten (kein Multi-Device, kein Aufräumen abgelaufener Tokens).

### 2.6 Datenschutz
- Gespeichert: E-Mail, Anzeigename, Avatar-URL, FCM-Token, Sprache, alle Listen/Todos/Artikel/Chats mit Namen und Zeitstempeln. Firestore-Standort nicht aus dem Repo ersichtlich (Functions in Frankfurt).
- Nötig: Datenschutzerklärung (URL + Link in App), Impressum (SeeBubble Media FlexCo), Apple „App Privacy“-Angaben (Kontakt, Nutzerinhalte, Kennungen), Google-Play-Datensicherheitsformular. Kein Tracking/Analytics eingebaut – gut, das ist ein Verkaufsargument („keine Werbung, kein Tracking“ – im Gegensatz zu Bring!).

### 2.7 Sichtbare Fehler/Ungereimtheiten (Code-Lesung)
- Löschen einer Liste löscht Todos/Artikel/Chats nicht (Waisen, Kosten, Datenschutz).
- Umbenennen des Profils ändert kopierte Namen nicht.
- Theme hängt am Gerät, nicht am Konto; keine Dark-Mode-Automatik.
- Login-/Register-Seite erscheint auf Englisch, obwohl das System Deutsch ist (Web-Test, Screenshot 01) – `localeResolutionCallback` gibt `supportedLocales.first` zurück, aber `LanguageBloc` lädt erst asynchron; prüfen, ob auf dem Gerät dasselbe passiert.
- Chat-Badge ist nicht pro Leser (s. o.).
- `ListModel.isOwner => true` („wird später dynamisch gesetzt“) – Platzhalter.

---

## 3. Markt – kurz

| App | Stärke | Schwäche für „gemeinsam“ |
|---|---|---|
| **Bring!** (Schweiz, gratis) | Einkaufen mit Icon-Katalog, Rezept-Import, Wearable/Sprache, sehr verbreitet im DACH-Raum | Werbung/Angebote, keine Todos, keine Verteilung |
| **AnyList** | Rezepte, Wochenplan, Sortierung nach Gang/Laden, Alexa; Familie im Abo | nur Einkauf/Rezepte, Abo pro Haushalt |
| **OurGroceries** | schlicht, Alexa | altbacken, keine Todos |
| **Apple Erinnerungen** | gratis, geteilte Listen, Siri, Widgets, Einkaufslisten mit automatischer Kategorie (iOS 17+), Zuweisen | nur Apple, kein Android/Web, keine Fairness, kein Chat |
| **Microsoft To Do** | gratis, geteilte Listen, Zuweisen, überall | langsam im Team, keine Einkaufslogik |
| **Todoist / TickTick** | Profi-Aufgaben, Wiederholungen, Projekte, Kalender | für Familien überladen, Preis, Fairness fehlt |
| **Any.do** | Familien-Marketing, Zuweisung, Einkaufsliste, 40 Mio. Nutzer (Eigenangabe) | Abo nötig für fast alles |
| **Cozi / Cupla** | Familien-/Paar-Kalender, Einkauf, Essensplan | Kalender-zentriert, Werbung (Cozi) |
| **FairShare, fiftyfifty, Household Fair Share** | neue Nische 2025/26: Mental Load, Fairness, Fair-Play-Karten | sind Coaching-/Abo-Apps (~60 €/Jahr), **keine** brauchbare Einkaufs-/Todo-Liste |

**Lücke:** Es gibt gute Listen-Apps ohne Fairness und neue Fairness-Apps ohne gute Listen. Niemand verbindet *die Liste, die man eh täglich benutzt* mit *sichtbar gerechter Verteilung*. Zweite, kleinere Lücke: keine der großen Listen-Apps ist tracking-frei UND auf allen Plattformen inkl. Mac nativ (Bring! hat Werbung, Apple ist nur Apple).

Quellen: [iTechGuides](https://www.itechguides.com/best/shopping-list-apps/), [Macaron – shared grocery apps](https://macaron.im/blog/best-grocery-list-apps-shared-shopping), [Listonic-Vergleich (Hersteller)](https://listonic.com/compare-apps), [Any.do-Blog (Hersteller)](https://www.any.do/blog/the-best-shared-to-do-list-app-for-families-couples-in-2026/), [Toolfinder](https://toolfinder.com/best/shared-to-do-apps), [Cupla (Hersteller)](https://cupla.app/blog/best-shared-to-do-list-apps-for-couples/), [FairShare](https://peerpush.com/p/fairshare), [fiftyfifty](https://apps.apple.com/us/app/-/id6749406018), [Household Fair Share](https://apps.apple.com/us/app/-/id1662481936), [Starling „Share the Load“](https://scottishfinancialnews.com/articles/and-finally-clean-sweep).

---

## 4. Was macht ToGetherDo einzigartig – drei Richtungen

### A) „Fair verteilt“ – die Liste zeigt, wer wie viel trägt (EMPFEHLUNG)
**Idee:** Jedes Todo und jeder Einkauf hat ein Gewicht (Standard 1, einstellbar). Pro Liste/Haushalt gibt es eine Wochen- und Monatsansicht: Balken je Person, erledigt/offen, plus „Vorschlag: nächstes Todo an X, weil X diese Woche weniger hatte“. Wiederkehrende Aufgaben („Müll Dienstag“, „Wocheneinkauf“) rotieren automatisch fair. Kleine Anerkennung statt Gamification: „Lena hat diese Woche 7 Dinge erledigt – Danke sagen?“ sendet eine Push an sie.
**Nutzen:** Löst ein echtes, viel diskutiertes Problem (Mental Load, Streit um Haushalt); gibt der App eine Geschichte, die sich erzählen lässt („die Todo-App, die fair ist“); nutzt die vorhandenen Daten (`completedBy`, `purchasedBy`, `assignedTo`) fast ohne neues Modell.
**Aufwand:** mittel. Stufe 1 (Statistik + Wochenbalken + Vorschlag beim Zuweisen) ~1–2 Wochen; Stufe 2 (Wiederholungen mit Rotation) +1–2 Wochen; Stufe 3 (Danke/Anerkennung, Haushalt als Einheit über Listen hinweg) +1 Woche.
**Risiko:** mittel-gering. Gefahr „Buchhaltung in der Beziehung“ – darum Verteilung als sanfte Anzeige, nie als Punktestand mit Rangliste; opt-in pro Liste. Hat sonst niemand im Listen-Segment.

### B) Einkaufen, das mitdenkt – Gang-Sortierung + Rezept→Liste per KI
**Idee:** Artikel bekommen automatisch eine Kategorie (Obst/Gemüse, Kühlregal, …) aus einem lokalen Wörterbuch (DE/EN, ~500 Begriffe) mit KI-Fallback; Sortierung pro Laden lernbar („bei meinem Spar ist Brot vorne“). Rezept-Text oder Foto → Zutaten → Liste mit Mengen; Reste-Modus: „Was habe ich noch, was fehlt?“ Autovervollständigung aus der Historie des Haushalts.
**Nutzen:** Spürbar beim täglichen Gebrauch, großer Komfortsprung gegenüber heute (keine Kategorien).
**Aufwand:** mittel-groß. Kategorisierung + Autovervollständigung ~1 Woche; Laden-Sortierung ~1 Woche; Rezept-Import per KI (Claude-API über Cloud Function, Kosten je Aufruf) ~1–2 Wochen inkl. Datenschutz-Hinweis.
**Risiko:** mittel-hoch. Genau da sind Bring! und AnyList sehr gut und gratis bzw. günstig; Apple Erinnerungen sortiert Einkaufslisten seit iOS 17 automatisch. Man holt auf, überholt aber nicht.

### C) Sprache, Siri, Widgets, Teilen per Link
**Idee:** Siri-Kurzbefehle / App Intents („Füg Milch zur Einkaufsliste hinzu“), Home-Screen- und Lock-Screen-Widgets (offene Todos, Einkaufsliste), Live Activity beim Einkaufen, Teilen per Link/QR statt Zahlencode, Apple-/Google-Login.
**Nutzen:** Macht die App auf iPhone/Mac „zuhause“, senkt die Hürde zum Beitreten enorm (Link in WhatsApp statt Code abtippen).
**Aufwand:** mittel, aber plattformspezifisch (Swift-Extensions für Widgets/Intents, `home_widget`-Paket; Universal Links brauchen Domain + AASA-Datei; Android App Links).
**Risiko:** gering, aber **nicht unterscheidend** – Apple Erinnerungen hat all das gratis. Gehört als Komfort dazu, trägt aber keine Positionierung.

### Empfehlung
**Hauptrichtung A („Fair verteilt“)**, ergänzt um die billigen Teile aus C (Einladungslink/QR, Widgets) und die billigen Teile aus B (Kategorie-Wörterbuch, Autovervollständigung). Slogan-Richtung: *„ToGetherDo – gemeinsam erledigt, fair verteilt.“* Zielgruppe: Paare, Familien, WGs. Preis: Grundfunktion gratis, „Haushalt“-Abo (ein Abo für alle Mitglieder, wie fiftyfifty) für Statistik/Rotation/Rezept-KI.

---

## 5. Priorisierte Liste

### (a) Muss vor dem Einreichen (iOS)
1. Kamera-Knopf: Avatar-Upload fertigstellen (läuft parallel) **oder** Knopf entfernen – in `profile_screen.dart` **und** `profile_screen_desktop.dart`. Storage-Regel für `avatars/{uid}_*` nur für den Besitzer.
2. Kontolöschung vollständig: Reihenfolge Re-Auth → Daten → Auth; Todos/Artikel/Chats der eigenen Listen und Avatar mitlöschen; Namen aus fremden Listen entfernen (per `memberIds`-Index, nicht `contains(userId)`); am besten serverseitig in einer Function `onUserDeleted` (functions v1 `auth.user().onDelete`), damit nichts hängen bleibt.
3. Datenschutz: Text in `app_de.arb`/`app_en.arb` (Zeilen 219–225) korrigieren (Chats **werden** gespeichert), echte Datenschutzerklärung + Impressum als Webseite, Link in der App und in App Store Connect; App-Privacy-Angaben ausfüllen.
4. `Info.plist`: `NSAllowsArbitraryLoads`, `UIBackgroundModes processing/fetch`, `BGTaskSchedulerPermittedIdentifiers` entfernen (nur `remote-notification` bleibt).
5. `firestore.rules` + `storage.rules` aus der Konsole ins Repo holen, in `firebase.json` eintragen, prüfen: Lesen/Schreiben von `todos`/`shopping_items`/`chatMessages` nur für `allUserIds` der Liste, `users/{uid}` nur für sich selbst, `sendTestNotification` nur mit Auth.
6. `functions/src/index.ts` mit `functions/lib/index.js` in Deckung bringen (Quelle neu aus JS ableiten oder JS als Quelle deklarieren), `node_modules` aus Git, `testNotification.js` löschen, Region in `firebase.json` angleichen.
7. Bundle-ID: iOS/macOS **behalten** (`com.example.togetherdo` ist deine Store-Identität); Android **vor** dem ersten Play-Upload auf z. B. `com.seebubble.togetherdo` umstellen (neue `google-services.json` in Firebase anlegen) und einen Release-Keystore einrichten.
8. Hartkodierte deutsche Texte (27 Stellen) in die ARB-Dateien; `assets/icons/` anlegen oder aus `pubspec.yaml` streichen; README und `web/index.html` bereinigen; Versionsnummer nur in `pubspec.yaml` pflegen (Mac-Store steht bei 1.2 → pubspec auf 1.3.0+x).
9. Toten Share-Code entfernen (eine Quelle der Wahrheit, weniger Reviewer-Verwirrung durch zwei „Teilen“-Modelle).

### (b) Schnell, große Wirkung
1. **„Passwort vergessen“** (ein Aufruf `sendPasswordResetEmail`, eine Seite) – heute sperrt sich jeder aus, der sein Passwort vergisst.
2. **Einladung per Link/QR** statt Zahlencode; Code länger und alphanumerisch, Beitritt über Function (Rate-Limit).
3. **Lokale Erinnerung zur Fälligkeit** – `flutter_local_notifications` ist drin, `showTodoDueNotification` existiert, wird nur nie geplant.
4. **Push auf allen Geräten**: `fcmTokens` als Map je Gerät statt ein Token.
5. **Listen-Löschung räumt auf** (Function `onListDeleted` löscht Todos/Artikel/Chats).
6. Chat-Gelesen pro Leser (`readBy[]`), Chat auch pro Einkaufsliste.
7. System-Dark-Mode + Theme am Konto speichern; Login-Seite in Systemsprache.
8. Einkauf: Kategorie-Wörterbuch + Autovervollständigung aus eigener Historie, Artikel mit Wisch-Geste abhaken, „alle gekauften aufräumen“.
9. Firestore-Daten mit Server-Timestamps statt ISO-Strings (Sortierung, Offline-Konflikte); Offline-Persistenz einschalten (`Settings(persistenceEnabled: true)`, bei Web `enablePersistence`).
10. Namen nicht kopieren, sondern über `users/{uid}` auflösen (oder Function, die Umbenennung nachzieht).
11. Ein paar Widget-Tests für Login, Liste anlegen, Todo abhaken; Copyright-Kopf (SeeBubble Media FlexCo) in alle Dateien.

### (c) Einzigartigkeit in Stufen (Richtung A)
- **Stufe 1 – Sichtbar machen (2 Wochen):** Wochen-/Monatsstatistik pro Liste (erledigt je Person, Gewicht je Todo), Haushalts-Ansicht über alle Listen, Hinweis beim Zuweisen („X hat diese Woche am wenigsten“). Opt-in pro Liste.
- **Stufe 2 – Wiederholungen mit Rotation (2 Wochen):** Wiederkehrende Todos (täglich/wöchentlich/monatlich) mit automatischer fairer Rotation; Function legt die nächste Instanz an und weist zu; Push „du bist dran“.
- **Stufe 3 – Anerkennung und Paar-/Familien-Modus (1–2 Wochen):** „Danke“-Reaktion auf erledigte Todos (Push), Wochenrückblick-Benachrichtigung („Diese Woche: Martin 9, Lena 11 – gut verteilt“), Haushalt als Einheit mit Rollen (Erwachsene/Kinder, Kinder ohne Statistik-Druck).
- **Stufe 4 – Einkauf, der mitdenkt (3–4 Wochen):** Gang-Sortierung pro Laden lernbar, Rezept→Liste per KI (Cloud Function mit Claude-API, Kosten/Abo), Reste-Modus.
- **Stufe 5 – Plattform-Komfort (laufend):** Widgets, Siri/App Intents, Live Activity beim Einkaufen, Apple-/Google-Login.

---

## 6. Offene Fragen an Martin
- ❓ Firestore-/Storage-Regeln aus der Konsole – gibt es sie, und darf ich sie ins Repo legen?
- ❓ Soll Android überhaupt in den Play Store (dann Paketname jetzt ändern)?
- ❓ Gibt es schon eine Datenschutz-/Impressum-Seite (z. B. unter seebubble.*), die verlinkt werden kann?
- ❓ Zielgruppe zuerst: Paare/Familien (Richtung A) – einverstanden?
