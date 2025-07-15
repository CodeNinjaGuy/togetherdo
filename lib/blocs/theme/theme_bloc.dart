import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themeKey = 'theme_name';

  ThemeBloc() : super(const ThemeInitial()) {
    on<ThemeLoadRequested>(_onThemeLoadRequested);
    on<ThemeChanged>(_onThemeChanged);
  }

  Future<void> _onThemeLoadRequested(
    ThemeLoadRequested event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_themeKey) ?? 'Light';
      developer.log('[ThemeBloc] Theme geladen: $themeName');
      emit(ThemeLoadSuccess(themeName: themeName));
    } catch (e) {
      developer.log('[ThemeBloc] Fehler beim Laden des Themes, fallback Light');
      emit(const ThemeLoadSuccess(themeName: 'Light'));
    }
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      developer.log('[ThemeBloc] Theme wechseln zu: ${event.themeName}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, event.themeName);
      developer.log('[ThemeBloc] Theme gespeichert: ${event.themeName}');
      emit(ThemeChangedSuccess(themeName: event.themeName));
    } catch (e) {
      developer.log('[ThemeBloc] Fehler beim Speichern des Themes: $e');
      emit(ThemeChangedSuccess(themeName: event.themeName));
    }
  }
}
