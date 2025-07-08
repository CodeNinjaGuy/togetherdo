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
  final bool isDarkMode;

  const ThemeLoadSuccess({required this.isDarkMode});

  @override
  List<Object?> get props => [isDarkMode];
}

class ThemeToggleSuccess extends ThemeState {
  final bool isDarkMode;

  const ThemeToggleSuccess({required this.isDarkMode});

  @override
  List<Object?> get props => [isDarkMode];
}
