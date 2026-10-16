/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// Übersetzt technische Fehler in verständliche Sätze; Details nur ins Log.
String kalFehlerText(AppLocalizations s, Object fehler) {
  debugPrint('Kalender-Fehler: $fehler');
  final code = fehler is FirebaseException ? fehler.code : _codeAusText('$fehler');
  switch (code) {
    case 'failed-precondition':
      return s.kalFehlerVorbereitung;
    case 'unavailable':
    case 'deadline-exceeded':
      return s.kalFehlerOffline;
    case 'permission-denied':
    case 'unauthorized':
      return s.kalFehlerRechte;
    default:
      return s.kalFehlerAllgemein;
  }
}

String? _codeAusText(String text) {
  final treffer = RegExp(r'\[[a-z_]+/([a-z-]+)\]').firstMatch(text);
  return treffer?.group(1);
}
