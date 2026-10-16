/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Anhänge (Fotos, PDFs, Dokumente) an Terminen und Aufgaben: auswählen,
/// verkleinern, nach Firebase Storage laden, laden, teilen, öffnen, löschen.
///
/// Ein Dienst für Aufgaben, Termine und Bilder im Chat: der Aufrufer gibt
/// den Storage-Basispfad vor (`todos/{listId}/{todoId}`,
/// `termine/{listId}/{terminId}` oder `chats/{listId}/{todoId}`), alles
/// andere ist für alle gleich. Die Beschreibungen (Firestore) verwaltet
/// `AnhangRepository` in `lib/repositories/anhang_repository.dart`.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/anhang_model.dart';
import 'avatar_service.dart' show DeviceCapabilities;

// ---------------------------------------------------------------------------
// Grenzen und Dateitypen
// ---------------------------------------------------------------------------

/// Feste Grenzen für Anhänge. Dieselben Werte stehen in `storage.rules`.
abstract final class AnhangGrenzen {
  /// Bilder höchstens 10 MB (nach dem Verkleinern praktisch nie erreicht).
  static const int maxBildBytes = 10 * 1024 * 1024;

  /// PDFs und Dokumente höchstens 20 MB.
  static const int maxDokumentBytes = 20 * 1024 * 1024;

  /// Höchstens so viele Anhänge je Termin bzw. Aufgabe.
  static const int maxAnzahl = 20;

  /// Längste Seite des hochgeladenen Bilds.
  static const int bildMaxSeite = 2048;
  static const int bildQualitaet = 82;

  /// Längste Seite des Vorschaubilds.
  static const int vorschauMaxSeite = 400;
  static const int vorschauQualitaet = 70;

  /// Dateiendungen, die der Dokument-Wähler anbietet.
  static const List<String> dokumentErweiterungen = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'csv',
    'ics',
  ];

  /// MIME-Typ je Dateiendung (Dokumente und Bilder).
  static const Map<String, String> mimeJeErweiterung = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt': 'text/plain',
    'rtf': 'application/rtf',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'csv': 'text/csv',
    'ics': 'text/calendar',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };

  /// Erlaubte Bild-MIME-Typen (wie in den Storage-Regeln).
  static const Set<String> bildMimeTypen = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  /// Erlaubte Dokument-MIME-Typen (wie in den Storage-Regeln).
  static Set<String> get dokumentMimeTypen => {
    for (final e in dokumentErweiterungen) mimeJeErweiterung[e]!,
  };

  static bool istBildMime(String mime) => bildMimeTypen.contains(mime);
  static bool istDokumentMime(String mime) => dokumentMimeTypen.contains(mime);

  /// Größengrenze für einen MIME-Typ; `null`, wenn der Typ unzulässig ist.
  static int? maxBytesFuer(String mime) {
    if (istBildMime(mime)) return maxBildBytes;
    if (istDokumentMime(mime)) return maxDokumentBytes;
    return null;
  }

  /// MIME-Typ aus dem Dateinamen; `application/octet-stream` als Rückfall.
  static String mimeAusName(String name) {
    final punkt = name.lastIndexOf('.');
    if (punkt < 0 || punkt == name.length - 1) {
      return 'application/octet-stream';
    }
    final ext = name.substring(punkt + 1).toLowerCase();
    return mimeJeErweiterung[ext] ?? 'application/octet-stream';
  }
}

// ---------------------------------------------------------------------------
// Fehler
// ---------------------------------------------------------------------------

/// Datei überschreitet die Größengrenze.
class AnhangZuGross implements Exception {
  const AnhangZuGross({
    required this.name,
    required this.groesse,
    required this.maxGroesse,
  });

  final String name;
  final int groesse;
  final int maxGroesse;

  @override
  String toString() =>
      'AnhangZuGross($name: $groesse Bytes, erlaubt $maxGroesse)';
}

/// MIME-Typ wird nicht angenommen.
class AnhangTypUnzulaessig implements Exception {
  const AnhangTypUnzulaessig({required this.name, required this.mime});

  final String name;
  final String mime;

  @override
  String toString() => 'AnhangTypUnzulaessig($name: $mime)';
}

/// Das System hat den Zugriff auf Kamera bzw. Fotos verweigert.
class AnhangZugriffVerweigert implements Exception {
  const AnhangZugriffVerweigert();

  @override
  String toString() => 'AnhangZugriffVerweigert';
}

/// Zu viele Anhänge an einem Eintrag.
class AnhangLimitErreicht implements Exception {
  const AnhangLimitErreicht({this.max = AnhangGrenzen.maxAnzahl});

  final int max;

  @override
  String toString() => 'AnhangLimitErreicht(max $max)';
}

// ---------------------------------------------------------------------------
// Werte
// ---------------------------------------------------------------------------

/// Woher ein Anhang kommt.
enum AnhangQuelle { kamera, galerie, dokument }

/// Eine ausgewählte, noch nicht hochgeladene Datei.
@immutable
class AnhangAuswahl {
  const AnhangAuswahl({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;

  /// MIME-Typ, z. B. `image/jpeg` oder `application/pdf`.
  final String mime;

  int get groesse => bytes.length;
  bool get istBild => mime.startsWith('image/');

  AnhangAuswahl copyWith({Uint8List? bytes, String? name, String? mime}) =>
      AnhangAuswahl(
        bytes: bytes ?? this.bytes,
        name: name ?? this.name,
        mime: mime ?? this.mime,
      );

  @override
  String toString() => 'AnhangAuswahl($name, $mime, $groesse Bytes)';
}

/// Stand eines laufenden Uploads. Beim letzten Ereignis ist [fertig] gesetzt.
@immutable
class UploadFortschritt {
  const UploadFortschritt({
    required this.anhangId,
    required this.name,
    required this.fortschritt,
    this.fertig,
  });

  /// Kennung, die der fertige Anhang bekommt (schon vor dem Ende bekannt).
  final String anhangId;
  final String name;

  /// 0 … 1
  final double fortschritt;

  /// Fertiges Anhang-Objekt, nur beim letzten Ereignis.
  final Anhang? fertig;

  bool get istFertig => fertig != null;

  @override
  String toString() =>
      'UploadFortschritt($anhangId ${(fortschritt * 100).round()} %'
      '${istFertig ? ', fertig' : ''})';
}

// ---------------------------------------------------------------------------
// Reine Bildfunktionen (ohne Flutter, in compute/Isolate nutzbar)
// ---------------------------------------------------------------------------

/// Verkleinert ein Bild auf längste Seite [AnhangGrenzen.bildMaxSeite] und
/// liefert JPEG (Qualität [AnhangGrenzen.bildQualitaet]). Kleinere Bilder
/// werden nicht vergrößert, nur neu als JPEG gespeichert. EXIF-Drehung wird
/// eingerechnet. `null`, wenn die Daten kein lesbares Bild sind.
Uint8List? bildVerkleinern(Uint8List bytes) => _bildAufJpeg(
  bytes,
  maxSeite: AnhangGrenzen.bildMaxSeite,
  qualitaet: AnhangGrenzen.bildQualitaet,
);

/// Erzeugt das Vorschaubild (längste Seite [AnhangGrenzen.vorschauMaxSeite],
/// JPEG Qualität [AnhangGrenzen.vorschauQualitaet]). `null`, wenn die Daten
/// kein lesbares Bild sind.
Uint8List? vorschauErzeugen(Uint8List bytes) => _bildAufJpeg(
  bytes,
  maxSeite: AnhangGrenzen.vorschauMaxSeite,
  qualitaet: AnhangGrenzen.vorschauQualitaet,
);

Uint8List? _bildAufJpeg(
  Uint8List bytes, {
  required int maxSeite,
  required int qualitaet,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var bild = img.bakeOrientation(decoded);
  final laengste = bild.width > bild.height ? bild.width : bild.height;
  if (laengste > maxSeite) {
    final faktor = maxSeite / laengste;
    bild = img.copyResize(
      bild,
      width: (bild.width * faktor).round().clamp(1, maxSeite),
      height: (bild.height * faktor).round().clamp(1, maxSeite),
      interpolation: img.Interpolation.average,
    );
  }
  // JPEG kennt keine Transparenz: durchsichtige Flächen auf Weiß legen.
  if (bild.hasAlpha) {
    final leinwand = img.Image(width: bild.width, height: bild.height);
    img.fill(leinwand, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(leinwand, bild);
    bild = leinwand;
  }
  return Uint8List.fromList(img.encodeJpg(bild, quality: qualitaet));
}

/// Beide Varianten in einem Isolate-Durchlauf; die Vorschau entsteht aus
/// dem bereits verkleinerten Bild. Liefert `null`, wenn das Bild nicht
/// lesbar ist.
({Uint8List bild, Uint8List vorschau})? bildUndVorschau(Uint8List bytes) {
  final bild = bildVerkleinern(bytes);
  if (bild == null) return null;
  final vorschau = vorschauErzeugen(bild);
  if (vorschau == null) return null;
  return (bild: bild, vorschau: vorschau);
}

/// Prüft Typ und Größe einer Auswahl; wirft [AnhangTypUnzulaessig] oder
/// [AnhangZuGross].
void anhangPruefen(AnhangAuswahl datei) {
  final max = AnhangGrenzen.maxBytesFuer(datei.mime);
  if (max == null) {
    throw AnhangTypUnzulaessig(name: datei.name, mime: datei.mime);
  }
  if (datei.groesse > max) {
    throw AnhangZuGross(
      name: datei.name,
      groesse: datei.groesse,
      maxGroesse: max,
    );
  }
}

/// Wirft [AnhangLimitErreicht], wenn [vorhanden] plus [neu] die Grenze
/// überschreiten würde.
void anhangAnzahlPruefen(int vorhanden, {int neu = 1}) {
  if (vorhanden + neu > AnhangGrenzen.maxAnzahl) {
    throw const AnhangLimitErreicht();
  }
}

/// Dateiname für die Speicherung: Pfadzeichen raus, Länge begrenzt.
String anhangNameBereinigen(String name) {
  var n = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
  if (n.isEmpty) n = 'datei';
  if (n.length > 120) {
    final punkt = n.lastIndexOf('.');
    final ext = punkt > 0 ? n.substring(punkt) : '';
    n = n.substring(0, 120 - ext.length) + ext;
  }
  return n;
}

// ---------------------------------------------------------------------------
// Schnittstelle
// ---------------------------------------------------------------------------

/// Anhänge wählen, hochladen, laden, teilen, öffnen und löschen.
///
/// `AttachmentService()` liefert die Firebase-Umsetzung; für Tests und die
/// Design-Galerie gibt es [FakeAttachmentService].
abstract class AttachmentService {
  /// Firebase-Umsetzung. [storage] und die Wähler sind für Tests austauschbar.
  factory AttachmentService({
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
    FilePicker? filePicker,
  }) = FirebaseAttachmentService;

  /// Ob das Gerät eine nutzbare Kamera hat (sonst keine Kamera-Kachel).
  Future<bool> kameraVerfuegbar();

  /// Lässt den Nutzer Dateien wählen. Leere Liste = abgebrochen.
  /// Prüft Typ und Größe noch nicht; das macht [hochladen].
  /// Fehler: [AnhangZugriffVerweigert], wenn das System den Zugriff sperrt.
  Future<List<AnhangAuswahl>> waehlen(AnhangQuelle quelle);

  /// Lädt eine Datei nach `basisPfad/<id>` hoch. Bilder werden vorher
  /// verkleinert und bekommen ein Vorschaubild `basisPfad/<id>_vorschau.jpg`.
  /// Der Strom liefert Fortschritt 0…1 und zuletzt das fertige [Anhang].
  /// Fehler: [AnhangZuGross], [AnhangTypUnzulaessig], sonst Storage-Fehler.
  Stream<UploadFortschritt> hochladen({
    required String basisPfad,
    required AnhangAuswahl datei,
    required String userId,
  });

  /// Löscht Datei und Vorschau. „Nicht gefunden“ wird nicht gemeldet.
  Future<void> loeschen(Anhang a);

  /// Lädt eine Datei (mit kleinem Speicher-Zwischenspeicher).
  Future<Uint8List> laden(String pfad);

  /// Download-Adresse der Datei.
  Future<String> downloadUrl(String pfad);

  /// Öffnet das Teilen-Blatt des Systems mit der Datei.
  Future<void> teilen(Anhang a);

  /// Öffnet die Datei mit einer passenden App (Handy: über das Teilen-Blatt,
  /// Mac/Windows/Linux: Standardprogramm).
  Future<void> oeffnen(Anhang a);
}

// ---------------------------------------------------------------------------
// Speicher-Zwischenspeicher
// ---------------------------------------------------------------------------

/// Kleiner LRU-Zwischenspeicher für geladene Dateien (Byte-Budget).
class AnhangCache {
  AnhangCache({this.maxBytes = 32 * 1024 * 1024});

  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _daten = LinkedHashMap();
  int _bytes = 0;

  int get groesse => _bytes;
  int get anzahl => _daten.length;

  Uint8List? get(String pfad) {
    final d = _daten.remove(pfad);
    if (d == null) return null;
    _daten[pfad] = d; // ans Ende = zuletzt genutzt
    return d;
  }

  void put(String pfad, Uint8List daten) {
    if (daten.length > maxBytes) return;
    final alt = _daten.remove(pfad);
    if (alt != null) _bytes -= alt.length;
    _daten[pfad] = daten;
    _bytes += daten.length;
    while (_bytes > maxBytes && _daten.isNotEmpty) {
      final aeltester = _daten.keys.first;
      _bytes -= _daten.remove(aeltester)!.length;
    }
  }

  void remove(String pfad) {
    final alt = _daten.remove(pfad);
    if (alt != null) _bytes -= alt.length;
  }

  void clear() {
    _daten.clear();
    _bytes = 0;
  }
}

// ---------------------------------------------------------------------------
// Firebase-Umsetzung
// ---------------------------------------------------------------------------

class FirebaseAttachmentService implements AttachmentService {
  FirebaseAttachmentService({
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
    FilePicker? filePicker,
    AnhangCache? cache,
    DeviceCapabilities device = const DeviceCapabilities(),
  }) : _storage = storage,
       _imagePicker = imagePicker ?? ImagePicker(),
       _filePicker = filePicker,
       _device = device,
       cache = cache ?? AnhangCache();

  final DeviceCapabilities _device;
  final FirebaseStorage? _storage;
  final ImagePicker _imagePicker;
  final FilePicker? _filePicker;
  final AnhangCache cache;
  static const _uuid = Uuid();

  FirebaseStorage get _st => _storage ?? FirebaseStorage.instance;
  FilePicker get _fp => _filePicker ?? FilePicker.platform;

  @override
  Future<bool> kameraVerfuegbar() => _device.hasCamera();

  @override
  Future<List<AnhangAuswahl>> waehlen(AnhangQuelle quelle) async {
    try {
      return await _waehlen(quelle);
    } on PlatformException catch (e) {
      final c = e.code.toLowerCase();
      if (c.contains('denied') ||
          c.contains('permission') ||
          c.contains('restricted')) {
        throw const AnhangZugriffVerweigert();
      }
      rethrow;
    }
  }

  Future<List<AnhangAuswahl>> _waehlen(AnhangQuelle quelle) async {
    switch (quelle) {
      case AnhangQuelle.kamera:
        final x = await _imagePicker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
        );
        if (x == null) return const [];
        return [await _ausXFile(x)];
      case AnhangQuelle.galerie:
        final xs = await _imagePicker.pickMultiImage(
          requestFullMetadata: false,
          limit: AnhangGrenzen.maxAnzahl,
        );
        return [for (final x in xs) await _ausXFile(x)];
      case AnhangQuelle.dokument:
        final ergebnis = await _fp.pickFiles(
          type: FileType.custom,
          allowedExtensions: AnhangGrenzen.dokumentErweiterungen,
          allowMultiple: true,
          withData: true,
        );
        if (ergebnis == null) return const [];
        final liste = <AnhangAuswahl>[];
        for (final f in ergebnis.files) {
          var bytes = f.bytes;
          if (bytes == null && f.path != null && !kIsWeb) {
            bytes = await File(f.path!).readAsBytes();
          }
          if (bytes == null) continue;
          liste.add(
            AnhangAuswahl(
              bytes: bytes,
              name: anhangNameBereinigen(f.name),
              mime: AnhangGrenzen.mimeAusName(f.name),
            ),
          );
        }
        return liste;
    }
  }

  Future<AnhangAuswahl> _ausXFile(XFile x) async {
    final bytes = await x.readAsBytes();
    final name = x.name.isEmpty ? 'foto.jpg' : anhangNameBereinigen(x.name);
    final mime = x.mimeType ?? AnhangGrenzen.mimeAusName(name);
    return AnhangAuswahl(
      bytes: bytes,
      name: name,
      // Unbekannte Bild-Typen aus dem Wähler als JPEG behandeln; nach dem
      // Verkleinern ist es ohnehin JPEG.
      mime: mime == 'application/octet-stream' ? 'image/jpeg' : mime,
    );
  }

  @override
  Stream<UploadFortschritt> hochladen({
    required String basisPfad,
    required AnhangAuswahl datei,
    required String userId,
  }) async* {
    anhangPruefen(datei);
    final id = _uuid.v4();
    final name = anhangNameBereinigen(datei.name);
    yield UploadFortschritt(anhangId: id, name: name, fortschritt: 0);

    var bytes = datei.bytes;
    var mime = datei.mime;
    Uint8List? vorschau;
    String? vorschauPfad;
    var uploadName = name;

    if (datei.istBild) {
      final ergebnis = await compute(bildUndVorschau, datei.bytes);
      if (ergebnis != null) {
        bytes = ergebnis.bild;
        vorschau = ergebnis.vorschau;
        mime = 'image/jpeg';
        uploadName = _mitEndung(name, 'jpg');
      }
      // Nicht lesbar (z. B. HEIC ohne Decoder): Original unverändert laden.
      if (bytes.length > AnhangGrenzen.maxBildBytes) {
        throw AnhangZuGross(
          name: name,
          groesse: bytes.length,
          maxGroesse: AnhangGrenzen.maxBildBytes,
        );
      }
    }

    final pfad = '$basisPfad/$id';
    final meta = {'hochgeladenVon': userId, 'name': uploadName};

    if (vorschau != null) {
      vorschauPfad = '$basisPfad/${id}_vorschau.jpg';
      await _st
          .ref(vorschauPfad)
          .putData(
            vorschau,
            SettableMetadata(contentType: 'image/jpeg', customMetadata: meta),
          );
      yield UploadFortschritt(anhangId: id, name: name, fortschritt: 0.05);
    }

    final task = _st
        .ref(pfad)
        .putData(
          bytes,
          SettableMetadata(contentType: mime, customMetadata: meta),
        );
    await for (final s in task.snapshotEvents) {
      if (s.state == TaskState.error || s.state == TaskState.canceled) break;
      final anteil = s.totalBytes > 0 ? s.bytesTransferred / s.totalBytes : 0.0;
      if (s.state == TaskState.success) break;
      yield UploadFortschritt(
        anhangId: id,
        name: name,
        fortschritt: (0.05 + anteil * 0.95).clamp(0.0, 0.99),
      );
    }
    // Wirft, falls der Upload fehlgeschlagen ist.
    await task;
    cache.put(pfad, bytes);
    if (vorschau != null) cache.put(vorschauPfad!, vorschau);

    yield UploadFortschritt(
      anhangId: id,
      name: name,
      fortschritt: 1,
      fertig: Anhang(
        id: id,
        name: uploadName,
        typ: mime,
        groesse: bytes.length,
        pfad: pfad,
        vorschauPfad: vorschauPfad,
        hochgeladenVon: userId,
        hochgeladenAm: DateTime.now().toUtc(),
      ),
    );
  }

  static String _mitEndung(String name, String ext) {
    final punkt = name.lastIndexOf('.');
    final basis = punkt > 0 ? name.substring(0, punkt) : name;
    return '$basis.$ext';
  }

  @override
  Future<void> loeschen(Anhang a) async {
    await _loeschenStill(a.pfad);
    if (a.vorschauPfad != null) await _loeschenStill(a.vorschauPfad!);
  }

  Future<void> _loeschenStill(String pfad) async {
    cache.remove(pfad);
    try {
      await _st.ref(pfad).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<Uint8List> laden(String pfad) async {
    final c = cache.get(pfad);
    if (c != null) return c;
    final maxBytes = AnhangGrenzen.maxDokumentBytes;
    final daten = await _st.ref(pfad).getData(maxBytes);
    if (daten == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
        message: 'Keine Daten unter $pfad',
      );
    }
    cache.put(pfad, daten);
    return daten;
  }

  @override
  Future<String> downloadUrl(String pfad) => _st.ref(pfad).getDownloadURL();

  @override
  Future<void> teilen(Anhang a) async {
    final bytes = await laden(a.pfad);
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: a.typ, name: a.name)],
          fileNameOverrides: [a.name],
        ),
      );
      return;
    }
    final datei = await _tempDatei(a, bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(datei.path, mimeType: a.typ, name: a.name)],
        fileNameOverrides: [a.name],
      ),
    );
  }

  @override
  Future<void> oeffnen(Anhang a) async {
    if (kIsWeb) {
      final url = await downloadUrl(a.pfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    final bytes = await laden(a.pfad);
    final datei = await _tempDatei(a, bytes);
    final desktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (desktop) {
      final ok = await launchUrl(Uri.file(datei.path));
      if (ok) return;
    }
    // Handy/Tablet: Das Teilen-Blatt bietet „Öffnen in …“ und Vorschau.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(datei.path, mimeType: a.typ, name: a.name)],
        fileNameOverrides: [a.name],
      ),
    );
  }

  /// Schreibt die Datei unter ihrem Anzeigenamen in einen eigenen
  /// Temp-Ordner je Anhang, damit der Name im Teilen-Blatt stimmt.
  Future<File> _tempDatei(Anhang a, Uint8List bytes) async {
    final tmp = await getTemporaryDirectory();
    final ordner = Directory('${tmp.path}/anhaenge/${a.id}');
    await ordner.create(recursive: true);
    final datei = File('${ordner.path}/${anhangNameBereinigen(a.name)}');
    if (!await datei.exists() || await datei.length() != bytes.length) {
      await datei.writeAsBytes(bytes, flush: true);
    }
    return datei;
  }
}

// ---------------------------------------------------------------------------
// Fake für Tests und Design-Galerie
// ---------------------------------------------------------------------------

/// Hält alles im Speicher. [naechsteAuswahl] bestimmt, was [waehlen] liefert;
/// Aufrufe von [teilen], [oeffnen], [loeschen] werden protokolliert.
class FakeAttachmentService implements AttachmentService {
  FakeAttachmentService({
    this.schrittDauer = Duration.zero,
    this.schritte = 4,
    this.bilderVerarbeiten = true,
    this.kamera = true,
  });

  /// Ergebnis von [kameraVerfuegbar].
  final bool kamera;

  /// Pause zwischen Fortschrittsereignissen (0 = sofort).
  final Duration schrittDauer;

  /// Anzahl Fortschrittsereignisse zwischen 0 und 1.
  final int schritte;

  /// Ob Bilder wie im echten Service verkleinert werden (langsam bei
  /// großen Testbildern; für Widget-Tests abschaltbar).
  final bool bilderVerarbeiten;

  /// Was der nächste [waehlen]-Aufruf liefert.
  List<AnhangAuswahl> naechsteAuswahl = const [];

  /// Fehler, den [laden] werfen soll (z. B. zum Testen des Fehlerzustands).
  Object? ladeFehler;

  final Map<String, Uint8List> dateien = {};
  final List<AnhangQuelle> gewaehlt = [];
  final List<Anhang> geteilt = [];
  final List<Anhang> geoeffnet = [];
  final List<Anhang> geloescht = [];

  /// Pfade, die über [laden] angefragt wurden (auch fehlgeschlagene).
  final List<String> geladen = [];
  int _zaehler = 0;

  @override
  Future<bool> kameraVerfuegbar() async => kamera;

  @override
  Future<List<AnhangAuswahl>> waehlen(AnhangQuelle quelle) async {
    gewaehlt.add(quelle);
    final a = naechsteAuswahl;
    naechsteAuswahl = const [];
    return a;
  }

  @override
  Stream<UploadFortschritt> hochladen({
    required String basisPfad,
    required AnhangAuswahl datei,
    required String userId,
  }) async* {
    anhangPruefen(datei);
    final id = 'fake-${++_zaehler}';
    final name = anhangNameBereinigen(datei.name);
    var bytes = datei.bytes;
    var mime = datei.mime;
    String? vorschauPfad;
    if (datei.istBild && bilderVerarbeiten) {
      final e = bildUndVorschau(datei.bytes);
      if (e != null) {
        bytes = e.bild;
        mime = 'image/jpeg';
        vorschauPfad = '$basisPfad/${id}_vorschau.jpg';
        dateien[vorschauPfad] = e.vorschau;
      }
    }
    for (var i = 0; i < schritte; i++) {
      yield UploadFortschritt(
        anhangId: id,
        name: name,
        fortschritt: i / schritte,
      );
      if (schrittDauer > Duration.zero) {
        await Future<void>.delayed(schrittDauer);
      }
    }
    final pfad = '$basisPfad/$id';
    dateien[pfad] = bytes;
    yield UploadFortschritt(
      anhangId: id,
      name: name,
      fortschritt: 1,
      fertig: Anhang(
        id: id,
        name: name,
        typ: mime,
        groesse: bytes.length,
        pfad: pfad,
        vorschauPfad: vorschauPfad,
        hochgeladenVon: userId,
        hochgeladenAm: DateTime.utc(2026, 10, 16, 12),
      ),
    );
  }

  @override
  Future<void> loeschen(Anhang a) async {
    geloescht.add(a);
    dateien.remove(a.pfad);
    if (a.vorschauPfad != null) dateien.remove(a.vorschauPfad);
  }

  @override
  Future<Uint8List> laden(String pfad) async {
    geladen.add(pfad);
    if (ladeFehler != null) throw ladeFehler!;
    final d = dateien[pfad];
    if (d == null) throw StateError('Fake: keine Datei unter $pfad');
    return d;
  }

  @override
  Future<String> downloadUrl(String pfad) async => 'fake://$pfad';

  @override
  Future<void> teilen(Anhang a) async => geteilt.add(a);

  @override
  Future<void> oeffnen(Anhang a) async => geoeffnet.add(a);
}
