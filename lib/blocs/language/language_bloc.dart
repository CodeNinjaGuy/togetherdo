import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'language_event.dart';
import 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  static const String _languageKey = 'language_code';
  static const String _countryKey = 'country_code';

  LanguageBloc() : super(const LanguageInitial()) {
    on<LanguageLoadRequested>(_onLanguageLoadRequested);
    on<LanguageChanged>(_onLanguageChanged);
  }

  Future<void> _onLanguageLoadRequested(
    LanguageLoadRequested event,
    Emitter<LanguageState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'de';
      final countryCode = prefs.getString(_countryKey) ?? 'DE';
      developer.log('[LanguageBloc] Lade Sprache: $languageCode-$countryCode');
      emit(
        LanguageLoadSuccess(
          languageCode: languageCode,
          countryCode: countryCode,
        ),
      );
    } catch (e) {
      developer.log('[LanguageBloc] Fehler beim Laden, fallback de-DE');
      emit(const LanguageLoadSuccess(languageCode: 'de', countryCode: 'DE'));
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
}
