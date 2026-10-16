/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_de.dart';
import '../../models/anhang_model.dart';
import '../../services/attachment_service.dart';

/// Übersetzungen für die Anhang-Bausteine. Ohne eingerichtete Delegates
/// (Design-Galerie, Tests) fällt die Funktion auf Deutsch zurück.
AppLocalizations anhangL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsDe();

/// Symbol je MIME-Typ.
IconData anhangSymbol(String mime) {
  if (mime.startsWith('image/')) return Icons.image_rounded;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
  if (mime.contains('word') || mime == 'application/rtf') {
    return Icons.description_rounded;
  }
  if (mime.contains('excel') ||
      mime.contains('spreadsheet') ||
      mime == 'text/csv') {
    return Icons.table_chart_rounded;
  }
  if (mime.contains('powerpoint') || mime.contains('presentation')) {
    return Icons.slideshow_rounded;
  }
  if (mime == 'text/calendar') return Icons.event_rounded;
  if (mime.startsWith('text/')) return Icons.notes_rounded;
  return Icons.insert_drive_file_rounded;
}

extension AnhangTexte on AppLocalizations {
  /// Dateigröße lesbar: unter 1 MB in kB ohne Nachkommastelle, sonst MB
  /// mit einer Nachkommastelle in der Schreibweise der Sprache.
  String anhangGroesse(int bytes) {
    const mb = 1024 * 1024;
    if (bytes < mb) {
      final kb = (bytes / 1024).ceil().clamp(1, 1023);
      return anhangGroesseKb(
        NumberFormat.decimalPattern(localeName).format(kb),
      );
    }
    final f = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: 1,
    );
    return anhangGroesseMb(f.format(bytes / mb));
  }

  /// Kurzbezeichnung des Typs („Bild“, „PDF“, „Dokument“).
  String anhangTypFuerMime(String mime) {
    if (mime.startsWith('image/')) return anhangTypBild;
    if (mime == 'application/pdf') return anhangTypPdf;
    return anhangTypDokument;
  }

  String anhangTyp(Anhang a) => anhangTypFuerMime(a.typ);

  /// Verständlicher Text für Fehler aus dem [AttachmentService].
  String anhangFehler(Object fehler) {
    if (fehler is AnhangZuGross) {
      return anhangZuGross(fehler.name, anhangGroesse(fehler.maxGroesse));
    }
    if (fehler is AnhangTypUnzulaessig) {
      return anhangTypUnzulaessig(fehler.name);
    }
    if (fehler is AnhangLimitErreicht) return anhangLimitErreicht(fehler.max);
    return anhangFehlerAllgemein;
  }
}
