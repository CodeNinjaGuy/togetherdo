/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-ID im App Store (App Store Connect), für „App bewerten“.
const String kAppStoreId = '6748375750';

/// Anlass für eine Bewertungsanfrage.
enum ReviewMoment { tenthTaskDone, taskMilestone, fairWeek }

/// Wann der System-Bewertungsdialog kommen darf – reine Regeln, testbar.
///
/// - frühestens 3 Tage nach der ersten Nutzung,
/// - höchstens alle 60 Tage,
/// - nie kurz nach einem Fehler (10 Minuten Ruhe),
/// - nur bei einem Erfolg: 10. erledigte Aufgabe, danach jede 25.,
///   oder eine faire Woche.
class ReviewPolicy {
  const ReviewPolicy();

  static const Duration minAgeSinceFirstUse = Duration(days: 3);
  static const Duration minGapBetweenPrompts = Duration(days: 60);
  static const Duration quietAfterError = Duration(minutes: 10);

  /// Ist die [count]-te eigene erledigte Aufgabe ein Erfolgsmoment?
  ReviewMoment? momentForCompletedCount(int count) {
    if (count == 10) return ReviewMoment.tenthTaskDone;
    if (count > 10 && count % 25 == 0) return ReviewMoment.taskMilestone;
    return null;
  }

  bool mayPrompt({
    required DateTime now,
    required DateTime? firstUse,
    required DateTime? lastPrompt,
    required DateTime? lastError,
  }) {
    if (firstUse == null) return false;
    if (now.difference(firstUse) < minAgeSinceFirstUse) return false;
    if (lastPrompt != null &&
        now.difference(lastPrompt) < minGapBetweenPrompts) {
      return false;
    }
    if (lastError != null && now.difference(lastError) < quietAfterError) {
      return false;
    }
    return true;
  }
}

/// Merkt sich Nutzung und Erfolge und fragt im passenden Moment über den
/// System-Dialog (`in_app_review`) nach einer Bewertung.
class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  static const _kFirstUse = 'review.firstUse';
  static const _kLastPrompt = 'review.lastPrompt';
  static const _kCompleted = 'review.completedCount';
  static const _kLastFairWeek = 'review.lastFairWeek';

  final ReviewPolicy policy = const ReviewPolicy();

  /// Für Tests austauschbar.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  @visibleForTesting
  Future<void> Function()? requestOverride;

  DateTime? _lastError;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Beim Start aufrufen: merkt sich den Tag der ersten Nutzung.
  Future<void> recordAppStart() async {
    try {
      final prefs = await _prefs;
      if (!prefs.containsKey(_kFirstUse)) {
        await prefs.setString(_kFirstUse, clock().toIso8601String());
      }
    } catch (e) {
      debugPrint('Bewertung: Start nicht gespeichert: $e');
    }
  }

  /// Nach einem Fehler eine Weile nicht fragen.
  void noteError() => _lastError = clock();

  /// Nach erfolgreichem Abhaken durch die angemeldete Person.
  Future<void> onTaskCompleted() async {
    try {
      final prefs = await _prefs;
      final count = (prefs.getInt(_kCompleted) ?? 0) + 1;
      await prefs.setInt(_kCompleted, count);
      final moment = policy.momentForCompletedCount(count);
      if (moment != null) await _maybeRequest(prefs, moment);
    } catch (e) {
      debugPrint('Bewertung: Zähler nicht gespeichert: $e');
    }
  }

  /// Wenn eine Woche gut verteilt war (je Woche höchstens einmal).
  Future<void> onFairWeek(DateTime weekStart) async {
    try {
      final prefs = await _prefs;
      final key = weekStart.toIso8601String();
      if (prefs.getString(_kLastFairWeek) == key) return;
      await prefs.setString(_kLastFairWeek, key);
      await _maybeRequest(prefs, ReviewMoment.fairWeek);
    } catch (e) {
      debugPrint('Bewertung: faire Woche nicht verarbeitet: $e');
    }
  }

  Future<bool> _maybeRequest(
    SharedPreferences prefs,
    ReviewMoment moment,
  ) async {
    final now = clock();
    final ok = policy.mayPrompt(
      now: now,
      firstUse: DateTime.tryParse(prefs.getString(_kFirstUse) ?? ''),
      lastPrompt: DateTime.tryParse(prefs.getString(_kLastPrompt) ?? ''),
      lastError: _lastError,
    );
    if (!ok) return false;
    final override = requestOverride;
    if (override != null) {
      await override();
    } else {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return false;
      await review.requestReview();
    }
    await prefs.setString(_kLastPrompt, now.toIso8601String());
    debugPrint('Bewertung angefragt ($moment)');
    return true;
  }

  /// Eintrag „App bewerten“: öffnet die Store-Seite (immer möglich).
  Future<void> openStoreListing() =>
      InAppReview.instance.openStoreListing(appStoreId: kAppStoreId);
}
