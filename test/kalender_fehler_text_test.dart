/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/services/fehler_text.dart';
import 'package:togetherdo/l10n/app_localizations_de.dart';

void main() {
  final s = AppLocalizationsDe();
  test('Index im Aufbau wird verständlich gemeldet', () {
    expect(
      kalFehlerText(s, '[cloud_firestore/failed-precondition] The query requires an index.'),
      s.kalFehlerVorbereitung,
    );
  });
  test('Rechte, Netz und Unbekanntes', () {
    expect(kalFehlerText(s, '[cloud_firestore/permission-denied] x'), s.kalFehlerRechte);
    expect(kalFehlerText(s, '[cloud_firestore/unavailable] x'), s.kalFehlerOffline);
    expect(kalFehlerText(s, StateError('kaputt')), s.kalFehlerAllgemein);
  });
}
