import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themeKey = 'theme_mode';

  ThemeBloc() : super(const ThemeInitial()) {
    on<ThemeLoadRequested>(_onThemeLoadRequested);
    on<ThemeToggleRequested>(_onThemeToggleRequested);
  }

  Future<void> _onThemeLoadRequested(
    ThemeLoadRequested event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDarkMode = prefs.getBool(_themeKey) ?? false;
      emit(ThemeLoadSuccess(isDarkMode: isDarkMode));
    } catch (e) {
      // Fallback auf Light Mode bei Fehler
      emit(const ThemeLoadSuccess(isDarkMode: false));
    }
  }

  Future<void> _onThemeToggleRequested(
    ThemeToggleRequested event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentMode = prefs.getBool(_themeKey) ?? false;
      final newMode = !currentMode;

      await prefs.setBool(_themeKey, newMode);
      emit(ThemeToggleSuccess(isDarkMode: newMode));
    } catch (e) {
      // Bei Fehler: Toggle basierend auf aktuellem State
      final currentState = state;
      if (currentState is ThemeLoadSuccess) {
        emit(ThemeToggleSuccess(isDarkMode: !currentState.isDarkMode));
      } else if (currentState is ThemeToggleSuccess) {
        emit(ThemeToggleSuccess(isDarkMode: !currentState.isDarkMode));
      } else {
        emit(const ThemeToggleSuccess(isDarkMode: true));
      }
    }
  }
}
