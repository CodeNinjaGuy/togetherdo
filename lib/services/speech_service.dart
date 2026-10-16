/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Ergebnis des Startversuchs.
enum SpeechStartStatus { listening, permissionDenied, unavailable }

/// Ob die Spracheingabe auf dieser Plattform angeboten wird. Die Erkennung
/// übernimmt das System (iOS/macOS: Apple, Android: Google), kostenlos.
bool get speechInputSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);

typedef SpeechTextCallback = void Function(String text, bool isFinal);
typedef SpeechLevelCallback = void Function(double level);

/// Schmale Hülle um die Spracherkennung, damit Oberfläche und Tests nicht
/// am Paket hängen.
abstract class SpeechService {
  Future<SpeechStartStatus> start({
    required String localeId,
    required SpeechTextCallback onText,
    required SpeechLevelCallback onLevel,
    required VoidCallback onDone,
  });

  Future<void> stop();

  Future<void> cancel();
}

/// Echte Erkennung über `speech_to_text`.
class DeviceSpeechService implements SpeechService {
  DeviceSpeechService({SpeechToText? plugin}) : _stt = plugin ?? SpeechToText();

  final SpeechToText _stt;
  bool _initialized = false;
  bool _permissionDenied = false;
  VoidCallback? _onDone;

  @override
  Future<SpeechStartStatus> start({
    required String localeId,
    required SpeechTextCallback onText,
    required SpeechLevelCallback onLevel,
    required VoidCallback onDone,
  }) async {
    _onDone = onDone;
    if (!_initialized) {
      try {
        _initialized = await _stt.initialize(
          onError: _onError,
          onStatus: _onStatus,
        );
      } catch (e) {
        debugPrint('Spracherkennung nicht verfügbar: $e');
        return SpeechStartStatus.unavailable;
      }
      if (!_initialized) {
        // initialize() liefert false bei verweigerter Erlaubnis und bei
        // fehlender Erkennung; die Erlaubnis lässt sich getrennt abfragen.
        final has = await _hasPermissionSafe();
        return has
            ? SpeechStartStatus.unavailable
            : SpeechStartStatus.permissionDenied;
      }
    }
    if (_permissionDenied) return SpeechStartStatus.permissionDenied;

    // Beste passende Sprache: exakt, sonst gleiche Sprachfamilie.
    final locale = await _resolveLocale(localeId);
    try {
      await _stt.listen(
        onResult: (r) => onText(r.recognizedWords, r.finalResult),
        onSoundLevelChange: (level) => onLevel(_normalizeLevel(level)),
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
        ),
      );
    } catch (e) {
      debugPrint('Zuhören fehlgeschlagen: $e');
      return SpeechStartStatus.unavailable;
    }
    return SpeechStartStatus.listening;
  }

  Future<bool> _hasPermissionSafe() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _resolveLocale(String wanted) async {
    try {
      final locales = await _stt.locales();
      if (locales.isEmpty) return null;
      final normalized = wanted.replaceAll('-', '_');
      final exact = locales.where(
        (l) => l.localeId.replaceAll('-', '_') == normalized,
      );
      if (exact.isNotEmpty) return exact.first.localeId;
      final lang = normalized.split('_').first;
      final family = locales.where(
        (l) => l.localeId.replaceAll('-', '_').split('_').first == lang,
      );
      if (family.isNotEmpty) return family.first.localeId;
      return (await _stt.systemLocale())?.localeId;
    } catch (_) {
      return null;
    }
  }

  /// Pegel des Pakets: iOS etwa -50…10 dB, Android 0…10. Auf 0…1 bringen.
  static double _normalizeLevel(double raw) {
    if (raw < 0) return ((raw + 50) / 60).clamp(0.0, 1.0);
    return (raw / 10).clamp(0.0, 1.0);
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('Spracherkennung: ${error.errorMsg}');
    if (error.errorMsg == 'error_permission') _permissionDenied = true;
    if (error.permanent) _onDone?.call();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _onDone?.call();
    }
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}

/// Erkennung mit Drehbuch für Demo und Tests: liefert [script] Wort für
/// Wort mit wechselndem Pegel, zum Schluss als endgültigen Text.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({
    required this.script,
    this.wordDelay = const Duration(milliseconds: 220),
    this.status = SpeechStartStatus.listening,
  });

  final String script;
  final Duration wordDelay;
  final SpeechStartStatus status;
  Timer? _timer;
  final List<String> startedLocales = [];

  @override
  Future<SpeechStartStatus> start({
    required String localeId,
    required SpeechTextCallback onText,
    required SpeechLevelCallback onLevel,
    required VoidCallback onDone,
  }) async {
    startedLocales.add(localeId);
    if (status != SpeechStartStatus.listening) return status;
    final words = script.split(' ');
    var i = 0;
    _timer?.cancel();
    _timer = Timer.periodic(wordDelay, (t) {
      i++;
      if (i > words.length) {
        t.cancel();
        _timer = null;
        onLevel(0);
        onText(script, true);
        onDone();
        return;
      }
      onLevel(0.35 + 0.5 * ((i * 7) % 5) / 4);
      onText(words.take(i).join(' '), false);
    });
    return SpeechStartStatus.listening;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> cancel() => stop();
}
