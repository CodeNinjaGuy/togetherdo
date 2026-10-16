/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Anhänge eines Eintrags (Aufgabe oder Termin) mit einheitlicher
/// Bedienung: Quelle wählen (Kamera, Galerie, Dokument), Bilder werden
/// verkleinert, Upload mit Fortschritt, Galerie, Vollbild mit Zoom, Teilen
/// und Öffnen, Löschen mit Rückfrage.
///
/// Für neue Aufgaben, die noch keine Kennung haben, sammelt eine
/// [AnhangVormerkung] die gewählten Dateien; das Formular lädt sie nach
/// dem Anlegen mit [AnhangVormerkung.hochladen] hoch.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../design/attachments/td_attachments.dart';
import '../../design/td_design.dart';
import '../../models/anhang_model.dart';
import '../../repositories/anhang_repository.dart';

/// Lädt gewählte Dateien hoch und trägt sie ein. Gemeinsamer Ablauf für den
/// Abschnitt und Bilder im Chat.
///
/// [onFortschritt] bekommt jeden Zwischenstand, [onFertig] den fertigen
/// Anhang, [onFehler] Fehler je Datei (z. B. für einen Hinweis).
List<StreamSubscription<UploadFortschritt>> anhaengeHochladen({
  required AttachmentService service,
  required String basisPfad,
  required String userId,
  required List<AnhangAuswahl> dateien,
  required ValueChanged<UploadFortschritt> onFortschritt,
  required Future<void> Function(Anhang a) onFertig,
  required void Function(AnhangAuswahl datei, Object fehler) onFehler,
}) {
  return [
    for (final d in dateien)
      service
          .hochladen(basisPfad: basisPfad, datei: d, userId: userId)
          .listen(
            (f) async {
              onFortschritt(f);
              if (f.fertig != null) {
                try {
                  await onFertig(f.fertig!);
                } catch (e) {
                  onFehler(d, e);
                }
              }
            },
            onError: (Object e) => onFehler(d, e),
            cancelOnError: true,
          ),
  ];
}

/// Fragt die Quelle ab und liefert die gewählten, geprüften Dateien.
/// Fehler (zu groß, Typ, zu viele, kein Zugriff) erscheinen als Hinweis;
/// dann ist die Liste leer.
Future<List<AnhangAuswahl>> anhaengeWaehlen(
  BuildContext context, {
  required AttachmentService service,
  int vorhanden = 0,
  bool dokumentErlaubt = true,
}) async {
  final kamera = await service.kameraVerfuegbar();
  if (!context.mounted) return const [];
  final quelle = await showTdAnhangQuelleSheet(
    context,
    kameraVerfuegbar: kamera,
    dokumentErlaubt: dokumentErlaubt,
  );
  if (quelle == null || !context.mounted) return const [];
  try {
    anhangAnzahlPruefen(vorhanden);
    final dateien = await service.waehlen(quelle);
    anhangAnzahlPruefen(vorhanden, neu: dateien.length);
    for (final d in dateien) {
      anhangPruefen(d);
    }
    return dateien;
  } catch (e) {
    if (context.mounted) {
      TdToast.show(
        context,
        anhangL10n(context).anhangFehler(e),
        variant: TdToastVariant.warning,
      );
    }
    return const [];
  }
}

/// Noch nicht hochgeladene Anhänge einer neuen Aufgabe.
class AnhangVormerkung extends ChangeNotifier {
  final List<(Anhang, AnhangAuswahl)> _eintraege = [];
  int _zaehler = 0;

  /// Vorläufige Anhänge (Pfad `vorgemerkt/…`) für die Galerie.
  List<Anhang> get anhaenge => [for (final e in _eintraege) e.$1];
  List<AnhangAuswahl> get dateien => [for (final e in _eintraege) e.$2];
  bool get leer => _eintraege.isEmpty;

  void hinzufuegen(AnhangAuswahl datei, {String userId = ''}) {
    final id = 'vorgemerkt-${++_zaehler}';
    _eintraege.add((
      Anhang(
        id: id,
        name: datei.name,
        typ: datei.mime,
        groesse: datei.groesse,
        pfad: 'vorgemerkt/$id',
        hochgeladenVon: userId,
        hochgeladenAm: DateTime.now().toUtc(),
      ),
      datei,
    ));
    notifyListeners();
  }

  void entfernen(String id) {
    _eintraege.removeWhere((e) => e.$1.id == id);
    notifyListeners();
  }

  /// Dienst für die Galerie: liefert vorgemerkte Dateien aus dem Speicher,
  /// alles andere vom echten Dienst.
  AttachmentService dienst(AttachmentService echt) =>
      _VorgemerktDienst(this, echt);

  /// Lädt alle vorgemerkten Dateien nach [ziel] hoch und trägt sie ein.
  Future<void> hochladen({
    required AnhangZiel ziel,
    required AttachmentService service,
    required AnhangRepository repository,
    required String userId,
  }) async {
    for (final d in dateien) {
      await for (final f in service.hochladen(
        basisPfad: ziel.storagePfad,
        datei: d,
        userId: userId,
      )) {
        if (f.fertig != null) await repository.hinzufuegen(ziel, f.fertig!);
      }
    }
    _eintraege.clear();
    notifyListeners();
  }
}

class _VorgemerktDienst implements AttachmentService {
  _VorgemerktDienst(this._vormerkung, this._echt);

  final AnhangVormerkung _vormerkung;
  final AttachmentService _echt;

  AnhangAuswahl? _datei(String pfad) {
    for (final e in _vormerkung._eintraege) {
      if (e.$1.pfad == pfad) return e.$2;
    }
    return null;
  }

  @override
  Future<bool> kameraVerfuegbar() => _echt.kameraVerfuegbar();

  @override
  Future<List<AnhangAuswahl>> waehlen(AnhangQuelle quelle) =>
      _echt.waehlen(quelle);

  @override
  Stream<UploadFortschritt> hochladen({
    required String basisPfad,
    required AnhangAuswahl datei,
    required String userId,
  }) => _echt.hochladen(basisPfad: basisPfad, datei: datei, userId: userId);

  @override
  Future<Uint8List> laden(String pfad) async =>
      _datei(pfad)?.bytes ?? await _echt.laden(pfad);

  @override
  Future<String> downloadUrl(String pfad) => _echt.downloadUrl(pfad);

  @override
  Future<void> loeschen(Anhang a) async {
    if (_datei(a.pfad) != null) {
      _vormerkung.entfernen(a.id);
      return;
    }
    await _echt.loeschen(a);
  }

  // Vorgemerkte Dateien liegen noch nicht in Storage; Teilen/Öffnen geht
  // erst nach dem Speichern.
  @override
  Future<void> teilen(Anhang a) async {
    if (_datei(a.pfad) == null) await _echt.teilen(a);
  }

  @override
  Future<void> oeffnen(Anhang a) async {
    if (_datei(a.pfad) == null) await _echt.oeffnen(a);
  }
}

/// Anhänge eines Eintrags: Überschrift, Galerie mit Plus-Kachel, laufende
/// Uploads. Mit [ziel] liest der Abschnitt aus [repository] und lädt sofort
/// hoch; ohne (neue Aufgabe) sammelt er in [vormerkung].
class AnhangAbschnitt extends StatefulWidget {
  const AnhangAbschnitt({
    super.key,
    required this.service,
    required this.repository,
    required this.userId,
    this.ziel,
    this.vormerkung,
    this.darfFremdeLoeschen = false,
    this.darfHinzufuegen = true,
    this.titel,
    this.heroPraefix = 'abschnitt',
  }) : assert(ziel != null || vormerkung != null);

  final AttachmentService service;
  final AnhangRepository repository;
  final String userId;
  final AnhangZiel? ziel;
  final AnhangVormerkung? vormerkung;

  /// Besitzer bzw. Mitglied mit Bearbeitungsrecht: darf auch Anhänge
  /// anderer löschen (eigene immer).
  final bool darfFremdeLoeschen;
  final bool darfHinzufuegen;

  /// Überschrift; ohne Angabe „Anhänge“.
  final String? titel;
  final String heroPraefix;

  @override
  State<AnhangAbschnitt> createState() => _AnhangAbschnittState();
}

class _AnhangAbschnittState extends State<AnhangAbschnitt> {
  final Map<String, UploadFortschritt> _laufend = {};
  final List<StreamSubscription<UploadFortschritt>> _subs = [];
  int _vorhanden = 0;
  Stream<List<Anhang>>? _strom;

  @override
  void initState() {
    super.initState();
    _abonnieren();
  }

  @override
  void didUpdateWidget(AnhangAbschnitt old) {
    super.didUpdateWidget(old);
    if (old.ziel != widget.ziel || old.repository != widget.repository) {
      _abonnieren();
    }
  }

  void _abonnieren() {
    final z = widget.ziel;
    _strom = z == null ? null : widget.repository.beobachten(z);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _hinzufuegen() async {
    final dateien = await anhaengeWaehlen(
      context,
      service: widget.service,
      vorhanden: _vorhanden + _laufend.length,
    );
    if (dateien.isEmpty || !mounted) return;
    final ziel = widget.ziel;
    if (ziel == null) {
      for (final d in dateien) {
        widget.vormerkung!.hinzufuegen(d, userId: widget.userId);
      }
      return;
    }
    final l = anhangL10n(context);
    _subs.addAll(
      anhaengeHochladen(
        service: widget.service,
        basisPfad: ziel.storagePfad,
        userId: widget.userId,
        dateien: dateien,
        onFortschritt: (f) {
          if (mounted) setState(() => _laufend[f.anhangId] = f);
        },
        onFertig: (a) async {
          try {
            await widget.repository.hinzufuegen(ziel, a);
          } finally {
            if (mounted) setState(() => _laufend.remove(a.id));
          }
        },
        onFehler: (d, e) {
          debugPrint('Anhang hochladen fehlgeschlagen: $e');
          if (!mounted) return;
          setState(() => _laufend.removeWhere((_, f) => f.name == d.name));
          TdToast.show(
            context,
            l.anhangFehler(e),
            variant: TdToastVariant.error,
          );
        },
      ),
    );
  }

  bool _darfLoeschen(Anhang a) =>
      widget.darfFremdeLoeschen || a.hochgeladenVon == widget.userId;

  Widget _galerie(
    List<Anhang> anhaenge,
    AttachmentService service,
    ValueChanged<Anhang> onLoeschen,
  ) {
    _vorhanden = anhaenge.length;
    return TdAnhangGalerie(
      anhaenge: anhaenge,
      service: service,
      laufend: _laufend,
      padding: EdgeInsets.zero,
      heroPraefix: widget.heroPraefix,
      darfLoeschen: _darfLoeschen,
      onLoeschen: onLoeschen,
      onHinzufuegen: widget.darfHinzufuegen ? _hinzufuegen : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final ziel = widget.ziel;
    final Widget inhalt;
    if (ziel == null) {
      final v = widget.vormerkung!;
      final dienst = v.dienst(widget.service);
      inhalt = ListenableBuilder(
        listenable: v,
        // Der Dienst entfernt vorgemerkte Dateien selbst.
        builder: (context, _) => _galerie(v.anhaenge, dienst, (_) {}),
      );
    } else {
      inhalt = StreamBuilder<List<Anhang>>(
        stream: _strom,
        builder: (context, snap) => _galerie(
          snap.data ?? const [],
          widget.service,
          (a) => widget.repository.entfernen(ziel, a.id),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file_rounded, size: 16, color: context.td.muted),
            const SizedBox(width: TdSpace.xs),
            Text(
              widget.titel ?? l.anhangTitel,
              style: context.text.labelMedium?.copyWith(
                color: context.td.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.sm),
        inhalt,
      ],
    );
  }
}

/// Kleines Kennzeichen (Büroklammer und Anzahl) für Listenzeilen; nichts
/// bei 0.
class AnhangAnzahl extends StatefulWidget {
  const AnhangAnzahl({super.key, required this.repository, required this.ziel});

  final AnhangRepository repository;
  final AnhangZiel ziel;

  @override
  State<AnhangAnzahl> createState() => _AnhangAnzahlState();
}

class _AnhangAnzahlState extends State<AnhangAnzahl> {
  late Stream<int> _anzahl = widget.repository.anzahl(widget.ziel);

  @override
  void didUpdateWidget(AnhangAnzahl old) {
    super.didUpdateWidget(old);
    if (old.ziel != widget.ziel || old.repository != widget.repository) {
      _anzahl = widget.repository.anzahl(widget.ziel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _anzahl,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        if (n <= 0) return const SizedBox.shrink();
        final farbe = context.colors.onSurfaceVariant;
        return Semantics(
          label: '${anhangL10n(context).anhangTitel}: $n',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file_rounded, size: 13, color: farbe),
              Text(
                '$n',
                style: context.text.labelSmall?.copyWith(color: farbe),
              ),
            ],
          ),
        );
      },
    );
  }
}
