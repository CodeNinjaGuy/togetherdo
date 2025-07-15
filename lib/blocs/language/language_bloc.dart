import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../repositories/auth_repository.dart';
import 'language_event.dart';
import 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  static const String _languageKey = 'language_code';
  static const String _countryKey = 'country_code';
  final AuthRepository _authRepository;

  LanguageBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const LanguageInitial()) {
    on<LanguageLoadRequested>(_onLanguageLoadRequested);
    on<LanguageChanged>(_onLanguageChanged);
    on<LanguageLoadSystemRequested>(_onLanguageLoadSystemRequested);
    on<LanguageLoadProfileRequested>(_onLanguageLoadProfileRequested);
  }

  Future<void> _onLanguageLoadRequested(
    LanguageLoadRequested event,
    Emitter<LanguageState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString(_languageKey);
      final savedCountryCode = prefs.getString(_countryKey);

      if (savedLanguageCode != null && savedCountryCode != null) {
        // Gespeicherte Sprache vorhanden - verwende diese
        developer.log(
          '[LanguageBloc] Gespeicherte Sprache gefunden: $savedLanguageCode-$savedCountryCode',
        );
        emit(
          LanguageLoadSuccess(
            languageCode: savedLanguageCode,
            countryCode: savedCountryCode,
          ),
        );
      } else {
        // Erster App-Start: English als Fallback verwenden
        developer.log(
          '[LanguageBloc] Erster App-Start - English als Fallback verwenden',
        );

        // English als Fallback speichern
        await prefs.setString(_languageKey, 'en');
        await prefs.setString(_countryKey, 'US');
        developer.log('[LanguageBloc] English als Fallback gespeichert: en-US');

        emit(const LanguageLoadSuccess(languageCode: 'en', countryCode: 'US'));
      }
    } catch (e) {
      developer.log(
        '[LanguageBloc] Fehler beim Laden der Sprache, fallback en-US',
      );
      emit(const LanguageLoadSuccess(languageCode: 'en', countryCode: 'US'));
    }
  }

  Future<void> _onLanguageLoadSystemRequested(
    LanguageLoadSystemRequested event,
    Emitter<LanguageState> emit,
  ) async {
    try {
      // Systemsprache erkennen und speichern
      final systemLocale = _getSystemLocale();
      developer.log(
        '[LanguageBloc] Systemsprache geladen: ${systemLocale.languageCode}-${systemLocale.countryCode}',
      );

      // Systemsprache in SharedPreferences speichern
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, systemLocale.languageCode);
      await prefs.setString(
        _countryKey,
        systemLocale.countryCode ?? systemLocale.languageCode.toUpperCase(),
      );
      developer.log(
        '[LanguageBloc] Systemsprache gespeichert: ${systemLocale.languageCode}-${systemLocale.countryCode ?? systemLocale.languageCode.toUpperCase()}',
      );

      emit(
        LanguageLoadSuccess(
          languageCode: systemLocale.languageCode,
          countryCode:
              systemLocale.countryCode ??
              systemLocale.languageCode.toUpperCase(),
        ),
      );
    } catch (e) {
      developer.log(
        '[LanguageBloc] Fehler beim Laden der Systemsprache, fallback en-US',
      );
      emit(const LanguageLoadSuccess(languageCode: 'en', countryCode: 'US'));
    }
  }

  Future<void> _onLanguageLoadProfileRequested(
    LanguageLoadProfileRequested event,
    Emitter<LanguageState> emit,
  ) async {
    try {
      // Lade Spracheinstellungen aus Firebase
      final userLanguage = await _authRepository.getUserLanguage();

      if (userLanguage != null) {
        final languageCode = userLanguage['languageCode']!;
        final countryCode = userLanguage['countryCode']!;

        developer.log(
          '[LanguageBloc] Benutzereinstellungen aus Firebase geladen: $languageCode-$countryCode',
        );

        // Aktualisiere SharedPreferences mit den Benutzereinstellungen
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languageKey, languageCode);
        await prefs.setString(_countryKey, countryCode);

        developer.log(
          '[LanguageBloc] SharedPreferences aktualisiert mit Benutzereinstellungen: $languageCode-$countryCode',
        );

        emit(
          LanguageLoadSuccess(
            languageCode: languageCode,
            countryCode: countryCode,
          ),
        );
      } else {
        // Keine Benutzereinstellungen vorhanden - verwende gespeicherte Sprache
        final prefs = await SharedPreferences.getInstance();
        final languageCode = prefs.getString(_languageKey);
        final countryCode = prefs.getString(_countryKey);

        if (languageCode != null && countryCode != null) {
          developer.log(
            '[LanguageBloc] Gespeicherte Sprache aus SharedPreferences geladen: $languageCode-$countryCode',
          );
          emit(
            LanguageLoadSuccess(
              languageCode: languageCode,
              countryCode: countryCode,
            ),
          );
        } else {
          // Keine gespeicherte Sprache vorhanden - verwende English als Fallback
          developer.log(
            '[LanguageBloc] Keine Spracheinstellungen - English als Fallback verwendet',
          );
          emit(
            const LanguageLoadSuccess(languageCode: 'en', countryCode: 'US'),
          );
        }
      }
    } catch (e) {
      developer.log(
        '[LanguageBloc] Fehler beim Laden der Profilsprache, fallback en-US',
      );
      emit(const LanguageLoadSuccess(languageCode: 'en', countryCode: 'US'));
    }
  }

  Future<void> _onLanguageChanged(
    LanguageChanged event,
    Emitter<LanguageState> emit,
  ) async {
    try {
      developer.log(
        '[LanguageBloc] Sprache wechseln zu: ${event.languageCode}-${event.countryCode}',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, event.languageCode);
      await prefs.setString(_countryKey, event.countryCode);

      emit(
        LanguageChangedSuccess(
          languageCode: event.languageCode,
          countryCode: event.countryCode,
        ),
      );
    } catch (e) {
      developer.log('[LanguageBloc] Fehler beim Wechseln, fallback');
      emit(
        LanguageChangedSuccess(
          languageCode: event.languageCode,
          countryCode: event.countryCode,
        ),
      );
    }
  }

  Locale _getSystemLocale() {
    // Versuche verschiedene Methoden zur Systemsprache-Erkennung
    final platformDispatcher = ui.PlatformDispatcher.instance;
    final windowLocale = platformDispatcher.locale;
    developer.log(
      '[LanguageBloc] Window Locale: ${windowLocale.languageCode}-${windowLocale.countryCode}',
    );

    // Prüfe alle verfügbaren Locales
    final locales = platformDispatcher.locales;
    developer.log(
      '[LanguageBloc] Verfügbare Locales: ${locales.map((l) => '${l.languageCode}-${l.countryCode}').join(', ')}',
    );

    // Verwende das erste verfügbare Locale oder fallback auf English
    if (locales.isNotEmpty) {
      final primaryLocale = locales.first;
      developer.log(
        '[LanguageBloc] Primäres Locale: ${primaryLocale.languageCode}-${primaryLocale.countryCode}',
      );
      return primaryLocale;
    }

    // Fallback auf English
    developer.log('[LanguageBloc] Fallback auf English');
    return const Locale('en', 'US');
  }
}
