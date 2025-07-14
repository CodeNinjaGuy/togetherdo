import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class LanguageState extends Equatable {
  const LanguageState();

  @override
  List<Object?> get props => [];
}

class LanguageInitial extends LanguageState {
  const LanguageInitial();
}

class LanguageLoadSuccess extends LanguageState {
  final String languageCode;
  final String countryCode;

  const LanguageLoadSuccess({
    required this.languageCode,
    required this.countryCode,
  });

  Locale get locale => Locale(languageCode, countryCode);

  @override
  List<Object?> get props => [languageCode, countryCode];
}

class LanguageChangedSuccess extends LanguageState {
  final String languageCode;
  final String countryCode;

  const LanguageChangedSuccess({
    required this.languageCode,
    required this.countryCode,
  });

  Locale get locale => Locale(languageCode, countryCode);

  @override
  List<Object?> get props => [languageCode, countryCode];
}

class LanguageFailure extends LanguageState {
  final String message;

  const LanguageFailure(this.message);

  @override
  List<Object?> get props => [message];
}
