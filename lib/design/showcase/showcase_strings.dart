/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/widgets.dart';

/// Texte des Vorzeige-Startbildschirms und der Galerie (Deutsch/Englisch).
/// Bewusst nicht in den ARB-Dateien, damit der Fundament-Umbau dort
/// ungestört arbeiten kann; in Stufe 4 wandern die endgültigen Texte des
/// echten „Heute“-Bildschirms in `lib/l10n/*.arb`.
class ShowcaseStrings {
  const ShowcaseStrings._(this._de);

  final bool _de;

  static ShowcaseStrings of(BuildContext context) {
    final code =
        Localizations.maybeLocaleOf(context)?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return ShowcaseStrings._(code != 'en');
  }

  String _t(String de, String en) => _de ? de : en;

  // Navigation
  String get navToday => _t('Heute', 'Today');
  String get navLists => _t('Listen', 'Lists');
  String get navFair => _t('Fair', 'Fair');
  String get navProfile => _t('Profil', 'Profile');

  // Begrüßung
  String greeting(String name, int hour) {
    if (hour < 11) return _t('Guten Morgen, $name', 'Good morning, $name');
    if (hour < 18) return _t('Hallo, $name', 'Hello, $name');
    return _t('Guten Abend, $name', 'Good evening, $name');
  }

  String get tagline =>
      _t('Gemeinsam erledigt, fair verteilt.', 'Done together, shared fairly.');
  String openToday(int n) => _de
      ? (n == 1 ? '1 Aufgabe offen' : '$n Aufgaben offen')
      : (n == 1 ? '1 task open' : '$n tasks open');
  String get allDone => _t('Alles erledigt. Stark!', 'All done. Nice!');
  String get household => _t('Zuhause', 'Home');

  // Kennzahlen
  String get statOpen => _t('Offen heute', 'Open today');
  String get statDoneWeek => _t('Erledigt diese Woche', 'Done this week');
  String get statFairness => _t('Dein Anteil', 'Your share');

  // Abschnitte
  String get sectionToday => _t('Heute fällig', 'Due today');
  String get sectionShopping => _t('Einkauf', 'Shopping');
  String get sectionFairness => _t('Fair verteilt', 'Shared fairly');
  String get thisWeek => _t('diese Woche', 'this week');
  String get showAll => _t('Alle', 'All');
  String itemsLeft(int n) => _de
      ? (n == 1 ? 'noch 1 Artikel' : 'noch $n Artikel')
      : (n == 1 ? '1 item left' : '$n items left');
  String fairnessHint(String name) => _t(
    '$name hat diese Woche mehr übernommen – du bist dran.',
    '$name did more this week – your turn.',
  );
  String get fairnessBalanced => _t(
    'Ausgewogen – ihr seid ein gutes Team.',
    'Balanced – you make a good team.',
  );

  // Leerzustand
  String get emptyTitle => _t('Heute ist frei', 'Nothing due today');
  String get emptyMessage => _t(
    'Keine Aufgaben fällig. Gönn dir eine Pause oder plane voraus.',
    'No tasks due. Take a break or plan ahead.',
  );

  // Neue Aufgabe
  String get newTask => _t('Neue Aufgabe', 'New task');
  String get taskTitleLabel => _t('Was ist zu tun?', 'What needs doing?');
  String get taskTitleHint =>
      _t('z. B. Müll rausbringen', 'e.g. take out the trash');
  String get listLabel => _t('Liste', 'List');
  String get weightLabel => _t('Aufwand', 'Effort');
  String get assigneeLabel => _t('Wer macht’s?', 'Who does it?');
  String get suggestedTurn => _t('Vorschlag: dran', 'Suggested: next up');
  String get create => _t('Anlegen', 'Create');
  String get cancel => _t('Abbrechen', 'Cancel');
  String taskCreated(String title) =>
      _t('„$title“ angelegt', '“$title” created');
  String get taskDeleted => _t('Aufgabe gelöscht', 'Task deleted');
  String get undo => _t('Rückgängig', 'Undo');
  String get weightLight => _t('leicht', 'light');
  String get weightMedium => _t('mittel', 'medium');
  String get weightHeavy => _t('schwer', 'heavy');
  String get dueToday => _t('heute', 'today');
  String get dueTonight => _t('heute Abend', 'tonight');
  String get overdue => _t('überfällig', 'overdue');
  String get you => _t('Du', 'You');

  // Listendetail
  String get detailMembers => _t('Mitglieder', 'Members');
  String get detailProgress => _t('Fortschritt', 'Progress');
  String doneOf(int done, int total) =>
      _t('$done von $total erledigt', '$done of $total done');

  // Platzhalter-Reiter
  String get comingLater => _t(
    'Dieser Bereich wird in Stufe 4 auf das neue Design umgestellt.',
    'This area moves to the new design in stage 4.',
  );

  // Galerie
  String get galleryTitle => _t('Design-Galerie', 'Design gallery');
  String get light => _t('Hell', 'Light');
  String get dark => _t('Dunkel', 'Dark');
  String get paletteLabel => _t('Palette', 'Palette');
}
