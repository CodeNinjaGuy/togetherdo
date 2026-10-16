/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Kantenlänge des gespeicherten Profilbilds in Pixeln.
const int kAvatarSize = 512;

/// JPEG-Qualität des gespeicherten Profilbilds.
const int kAvatarJpegQuality = 85;

/// Wählbare Aktionen im Profilbild-Menü.
enum AvatarAction { camera, gallery, remove }

/// Ergebnis eines Auswahlversuchs.
enum AvatarPickStatus { picked, cancelled, permissionDenied, unavailable }

class AvatarPickResult {
  final AvatarPickStatus status;
  final Uint8List? bytes;

  const AvatarPickResult(this.status, [this.bytes]);
}

/// Schneidet ein Bild quadratisch aus der Mitte zu, verkleinert es auf
/// [size] Pixel und liefert es als JPEG.
///
/// Gibt `null` zurück, wenn die Daten kein lesbares Bild sind.
Uint8List? processAvatarBytes(Uint8List input, {int size = kAvatarSize}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  // Ausrichtung aus EXIF anwenden (Kamera-Fotos liegen sonst quer).
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height
      ? oriented.width
      : oriented.height;
  final target = side < size ? side : size;
  final square = img.copyResizeCropSquare(
    oriented,
    size: target,
    interpolation: img.Interpolation.average,
  );
  // Transparente Bereiche (PNG) auf Weiß legen, JPEG kennt kein Alpha.
  var output = square;
  if (square.hasAlpha) {
    final canvas = img.Image(width: square.width, height: square.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, square);
    output = canvas;
  }
  return Uint8List.fromList(img.encodeJpg(output, quality: kAvatarJpegQuality));
}

/// Zugriff auf Geräteeigenschaften, die image_picker nicht liefert
/// (Kamera vorhanden? Einstellungen öffnen).
class DeviceCapabilities {
  static const MethodChannel _channel = MethodChannel('togetherdo/device');

  const DeviceCapabilities();

  /// `true`, wenn das Gerät eine nutzbare Kamera hat. Nur iOS und Android.
  Future<bool> hasCamera() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('hasCamera') ?? false;
    } catch (e) {
      debugPrint('Kamera-Abfrage fehlgeschlagen: $e');
      return false;
    }
  }

  /// Öffnet die App-Einstellungen des Systems (iOS/Android).
  Future<bool> openAppSettings() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (e) {
      debugPrint('Einstellungen konnten nicht geöffnet werden: $e');
      return false;
    }
  }

  /// Ob die Plattform „Einstellungen öffnen“ unterstützt.
  bool get canOpenSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
}

/// Wählt ein Bild aus und bereitet es als Profilbild auf.
class AvatarService {
  final ImagePicker _picker;
  final DeviceCapabilities _device;

  AvatarService({ImagePicker? picker, DeviceCapabilities? device})
    : _picker = picker ?? ImagePicker(),
      _device = device ?? const DeviceCapabilities();

  DeviceCapabilities get device => _device;

  Future<bool> canUseCamera() => _device.hasCamera();

  Future<AvatarPickResult> pick(AvatarAction action) async {
    assert(action != AvatarAction.remove);
    final source = action == AvatarAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        // Vorab verkleinern spart Speicher und Rechenzeit beim Zuschnitt.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.front,
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      debugPrint('Bildauswahl: ${e.code} ${e.message}');
      if (_isPermissionError(e.code)) {
        return const AvatarPickResult(AvatarPickStatus.permissionDenied);
      }
      return const AvatarPickResult(AvatarPickStatus.unavailable);
    } catch (e) {
      debugPrint('Bildauswahl fehlgeschlagen: $e');
      return const AvatarPickResult(AvatarPickStatus.unavailable);
    }
    if (file == null) {
      return const AvatarPickResult(AvatarPickStatus.cancelled);
    }
    final raw = await file.readAsBytes();
    final processed = await compute(_processInBackground, raw);
    if (processed == null) {
      return const AvatarPickResult(AvatarPickStatus.unavailable);
    }
    return AvatarPickResult(AvatarPickStatus.picked, processed);
  }

  static bool _isPermissionError(String code) {
    final c = code.toLowerCase();
    return c.contains('denied') ||
        c.contains('permission') ||
        c.contains('restricted');
  }
}

Uint8List? _processInBackground(Uint8List raw) => processAvatarBytes(raw);
