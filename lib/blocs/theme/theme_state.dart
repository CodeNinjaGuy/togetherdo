import 'package:equatable/equatable.dart';

abstract class ThemeState extends Equatable {
  const ThemeState();

  @override
  List<Object?> get props => [];
}

class ThemeInitial extends ThemeState {
  const ThemeInitial();
}

class ThemeLoadSuccess extends ThemeState {
  final String themeName;
  const ThemeLoadSuccess({required this.themeName});
  @override
  List<Object?> get props => [themeName];
}

class ThemeChangedSuccess extends ThemeState {
  final String themeName;
  const ThemeChangedSuccess({required this.themeName});
  @override
  List<Object?> get props => [themeName];
}

class ThemeToggleSuccess extends ThemeState {
  final bool isDarkMode;

  const ThemeToggleSuccess({required this.isDarkMode});

  @override
  List<Object?> get props => [isDarkMode];
}
