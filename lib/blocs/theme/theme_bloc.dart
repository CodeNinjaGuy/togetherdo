import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      emit(ThemeLoadSuccess(themeName: themeName));
    } catch (e) {
      emit(const ThemeLoadSuccess(themeName: 'Light'));
    }
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, event.themeName);
      emit(ThemeChangedSuccess(themeName: event.themeName));
    } catch (e) {
      emit(ThemeChangedSuccess(themeName: event.themeName));
    }
  }
}
