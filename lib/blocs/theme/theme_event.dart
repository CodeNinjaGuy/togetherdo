import 'package:equatable/equatable.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ThemeToggleRequested extends ThemeEvent {
  const ThemeToggleRequested();
}

class ThemeLoadRequested extends ThemeEvent {
  const ThemeLoadRequested();
}
