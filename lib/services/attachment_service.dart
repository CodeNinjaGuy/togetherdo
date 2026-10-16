/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment_model.dart';
import 'avatar_service.dart' show DeviceCapabilities;

/// Woher ein Anhang kommt.
enum AttachmentSource { camera, gallery, file }

/// Ergebnis einer Auswahl.
enum AttachmentPickStatus { picked, cancelled, permissionDenied, tooLarge, unsupported, unavailable }

/// Größte Bildkante nach dem Verkleinern.
const int kAttachmentMaxSide = 1600;
const int kAttachmentJpegQuality = 82;

/// Grenzen wie in `storage.rules`.
const int kAttachmentMaxImageBytes = 10 * 1024 * 1024;
const int kAttachmentMaxPdfBytes = 20 * 1024 * 1024;

/// Eine ausgewählte, noch nicht hochgeladene Datei.
class PickedAttachment {
  const PickedAttachment({
    required this.bytes,
    required this.name,
    required this.contentType,
  });

  final Uint8List bytes;
  final String name;
  final String contentType;

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
}

class AttachmentPickResult {
  const AttachmentPickResult(this.status, [this.file]);

  final AttachmentPickStatus status;
  final PickedAttachment? file;
}

/// Verkleinert ein Bild auf höchstens [maxSide] Pixel Kantenlänge und
/// liefert JPEG (EXIF-Ausrichtung angewendet, Transparenz auf Weiß).
/// `null`, wenn die Daten kein Bild sind.
Uint8List? compressAttachmentImage(
  Uint8List input, {
  int maxSide = kAttachmentMaxSide,
  int quality = kAttachmentJpegQuality,
}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: maxSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: maxSide,
            interpolation: img.Interpolation.average,
          );
  }
  if (image.hasAlpha) {
    final canvas = img.Image(width: image.width, height: image.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, image);
    image = canvas;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

Uint8List? _compressInBackground(Uint8List raw) => compressAttachmentImage(raw);

/// Prüft Typ und Größe gegen die Regeln (`storage.rules`).
AttachmentPickStatus checkAttachment(String contentType, int size) {
  if (contentType.startsWith('image/')) {
    return size <= kAttachmentMaxImageBytes
        ? AttachmentPickStatus.picked
        : AttachmentPickStatus.tooLarge;
  }
  if (contentType == 'application/pdf') {
    return size <= kAttachmentMaxPdfBytes
        ? AttachmentPickStatus.picked
        : AttachmentPickStatus.tooLarge;
  }
  return AttachmentPickStatus.unsupported;
}

/// Pfad in Storage: `todos/{listId}/{todoId}/{datei}` bzw. für Chat-Bilder
/// `chats/{listId}/{todoId}/{datei}`.
String attachmentStoragePath({
  required String listId,
  required String todoId,
  required String fileName,
  bool chat = false,
}) => '${chat ? 'chats' : 'todos'}/$listId/$todoId/$fileName';

/// Wählt Anhänge aus (Kamera, Galerie, Datei), verkleinert Bilder und lädt
/// sie mit Fortschritt nach Firebase Storage.
class AttachmentService {
  AttachmentService({
    ImagePicker? picker,
    FilePicker? filePicker,
    FirebaseStorage? storage,
    DeviceCapabilities? device,
  }) : _picker = picker ?? ImagePicker(),
       _filePicker = filePicker,
       _storage = storage,
       _device = device ?? const DeviceCapabilities();

  final ImagePicker _picker;
  final FilePicker? _filePicker;
  final FirebaseStorage? _storage;
  final DeviceCapabilities _device;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;
  FilePicker get filePicker => _filePicker ?? FilePicker.platform;
  DeviceCapabilities get device => _device;

  Future<bool> canUseCamera() => _device.hasCamera();

  /// Dateiauswahl (PDF) gibt es auf allen Plattformen außer Web-Kamera.
  bool get canPickFiles => true;

  Future<AttachmentPickResult> pick(AttachmentSource source) async {
    try {
      switch (source) {
        case AttachmentSource.camera:
        case AttachmentSource.gallery:
          final file = await _picker.pickImage(
            source: source == AttachmentSource.camera
                ? ImageSource.camera
                : ImageSource.gallery,
            maxWidth: 2400,
            maxHeight: 2400,
            imageQuality: 95,
            requestFullMetadata: false,
          );
          if (file == null) {
            return const AttachmentPickResult(AttachmentPickStatus.cancelled);
          }
          final raw = await file.readAsBytes();
          final jpeg = await compute(_compressInBackground, raw);
          if (jpeg == null) {
            return const AttachmentPickResult(AttachmentPickStatus.unsupported);
          }
          final name = _jpegName(file.name);
          return AttachmentPickResult(
            checkAttachment('image/jpeg', jpeg.length),
            PickedAttachment(bytes: jpeg, name: name, contentType: 'image/jpeg'),
          );
        case AttachmentSource.file:
          final result = await filePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
            withData: true,
          );
          final f = result?.files.firstOrNull;
          if (f == null) {
            return const AttachmentPickResult(AttachmentPickStatus.cancelled);
          }
          var bytes = f.bytes;
          if (bytes == null && f.path != null) {
            bytes = await XFile(f.path!).readAsBytes();
          }
          if (bytes == null) {
            return const AttachmentPickResult(AttachmentPickStatus.unavailable);
          }
          final type = contentTypeFor(f.name);
          if (type.startsWith('image/')) {
            final jpeg = await compute(_compressInBackground, bytes);
            if (jpeg == null) {
              return const AttachmentPickResult(
                AttachmentPickStatus.unsupported,
              );
            }
            return AttachmentPickResult(
              checkAttachment('image/jpeg', jpeg.length),
              PickedAttachment(
                bytes: jpeg,
                name: _jpegName(f.name),
                contentType: 'image/jpeg',
              ),
            );
          }
          return AttachmentPickResult(
            checkAttachment(type, bytes.length),
            PickedAttachment(bytes: bytes, name: f.name, contentType: type),
          );
      }
    } on PlatformException catch (e) {
      debugPrint('Anhang-Auswahl: ${e.code} ${e.message}');
      final c = e.code.toLowerCase();
      if (c.contains('denied') ||
          c.contains('permission') ||
          c.contains('restricted')) {
        return const AttachmentPickResult(
          AttachmentPickStatus.permissionDenied,
        );
      }
      return const AttachmentPickResult(AttachmentPickStatus.unavailable);
    } catch (e) {
      debugPrint('Anhang-Auswahl fehlgeschlagen: $e');
      return const AttachmentPickResult(AttachmentPickStatus.unavailable);
    }
  }

  /// Lädt eine Datei hoch und liefert die Beschreibung für Firestore.
  /// [onProgress] bekommt 0…1.
  Future<AttachmentModel> upload({
    required PickedAttachment file,
    required String listId,
    required String todoId,
    required String userId,
    required String userName,
    bool chat = false,
    ValueChanged<double>? onProgress,
  }) async {
    final id = const Uuid().v4();
    final safeName = sanitizeFileName(file.name);
    final path = attachmentStoragePath(
      listId: listId,
      todoId: todoId,
      fileName: '$id-$safeName',
      chat: chat,
    );
    final ref = storage.ref(path);
    final task = ref.putData(
      file.bytes,
      SettableMetadata(
        contentType: file.contentType,
        customMetadata: {'uploadedBy': userId, 'name': file.name},
      ),
    );
    StreamSubscription<TaskSnapshot>? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
      });
    }
    try {
      await task;
    } finally {
      await sub?.cancel();
    }
    final url = await ref.getDownloadURL();
    return AttachmentModel(
      id: id,
      todoId: todoId,
      listId: listId,
      name: file.name,
      path: path,
      url: url,
      contentType: file.contentType,
      size: file.bytes.length,
      uploadedBy: userId,
      uploadedByName: userName,
      createdAt: DateTime.now(),
    );
  }

  Future<void> delete(String path) async {
    try {
      await storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  static String _jpegName(String original) {
    final base = original.contains('.')
        ? original.substring(0, original.lastIndexOf('.'))
        : original;
    return '${base.isEmpty ? 'foto' : base}.jpg';
  }
}

/// MIME-Typ aus der Dateiendung.
String contentTypeFor(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'application/octet-stream',
  };
}

/// Nur Buchstaben, Ziffern, Punkt, Bindestrich; höchstens 80 Zeichen.
String sanitizeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-');
  final trimmed = cleaned.replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  final result = trimmed.isEmpty ? 'datei' : trimmed;
  return result.length > 80 ? result.substring(result.length - 80) : result;
}
