# ToGetherDo – Umbau 2026-10: Fundament, „Fair verteilt“, neues Design

Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
Written by Martin Bundschuh.

Auftrag von Martin (2026-10-16): Profilbild (fertig, Branch `profilbild`), „fair verteilt“ einbauen, und das Visuelle komplett auf heutigen Standard: ästhetisch, ansprechend, coole Animationen – „wie eine Millionen-App“. Grundlage: `docs/ANALYSE-2026-10.md`.

## Stufen und Helfer
| Stufe | Inhalt | Branch/Worktree |
|---|---|---|
| 1 Fundament | Store-Pflichten und Technik: Datenschutz-Text korrigieren (Chats werden gespeichert), Links Datenschutz/Impressum (Platzhalter-URLs NICHT erfinden – Konfiguration, Martin liefert URL), Info.plist bereinigen (NSAllowsArbitraryLoads, unbenutzte Background-Modes), Kontolöschung vollständig + serverseitig (Todos, Artikel, Chats, Mitgliedschaften, Avatar; Reihenfolge Auth/Profil), Firestore-Regeln aus der Konsole ins Repo (lesend holen), Functions-Quelle mit Deployment (`functions/lib/index.js`) abgleichen, `node_modules` aus Git, Beitrittscode gegen Durchprobieren (serverseitige Drosselung/Callable), „Passwort vergessen“, 27 hartkodierte Texte → ARB, toten Share-Code entfernen, Versionsquelle pubspec. | `fundament`, Worktree `~/Documents/Coding/ToGetherDo-fundament` |
| 2 Design-System | Neues visuelles System (Fable): Farben/Typografie/Abstände/Radien/Schatten als Tokens, hell+dunkel, Komponenten (Karten, Knöpfe, Eingaben, Chips, Listenzeilen, Leerzustände, Sheets), Animationsbausteine (Abhaken mit Konfetti/Partikel, Listen-Übergänge, Hero, Zähler/Balken, haptisches Feedback), Startbildschirm „Heute“ als Vorzeige-Entwurf. Bestehende 10 Themes in das neue System überführen (Fiberoptics25 bleibt). | `design`, Worktree `~/Documents/Coding/ToGetherDo-design` |
| 3 Fair verteilt | Gewicht je Aufgabe (leicht/mittel/schwer), Statistik je Person und Liste (Woche/Monat), Vorschlag „wer ist dran“ beim Zuweisen, wiederkehrende Aufgaben mit Rotation, „Danke“-Reaktion; Datenmodell + Regeln + Logik mit Tests. | nach 1+2 |
| 4 Alle Bildschirme | Fable bringt alle Bildschirme (Handy, iPad, Mac) auf das neue Design inkl. Fairness-Oberfläche. | nach 3 |
| 5 Einreichen | Build, TestFlight, Antwort an Apple (Kontolöschung, Kamera), Store-Texte/Screenshots. | Koordinator |

## Regeln
GitHub-Repo ist öffentlich (Entscheidung Martin offen) – keine Geheimnisse committen. Keine Produktionsdaten schreiben; Tests mit Firebase-Emulator (`--dart-define=USE_FIREBASE_EMULATOR=true`). Bundle-ID iOS/macOS bleibt `com.example.togetherdo` (Store-Identität). Copyright-Kopf in neue/umgebaute Dateien. Texte Deutsch/Englisch (ARB). Lokal committen, nicht pushen, nicht deployen.
