import 'package:equatable/equatable.dart';

abstract class LanguageEvent extends Equatable {
  const LanguageEvent();

  @override
  List<Object?> get props => [];
}

class LanguageLoadRequested extends LanguageEvent {
  const LanguageLoadRequested();
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
