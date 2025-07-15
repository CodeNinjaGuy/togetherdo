import 'package:equatable/equatable.dart';

abstract class LanguageEvent extends Equatable {
  const LanguageEvent();

  @override
  List<Object?> get props => [];
}

class LanguageLoadRequested extends LanguageEvent {
  const LanguageLoadRequested();
}

class LanguageLoadSystemRequested extends LanguageEvent {
  const LanguageLoadSystemRequested();
}

class LanguageLoadProfileRequested extends LanguageEvent {
  const LanguageLoadProfileRequested();
}

class LanguageChanged extends LanguageEvent {
  final String languageCode;
  final String countryCode;

  const LanguageChanged({
    required this.languageCode,
    required this.countryCode,
  });

  @override
  List<Object?> get props => [languageCode, countryCode];
}
