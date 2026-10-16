/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthProfileUpdateLoading extends AuthState {
  const AuthProfileUpdateLoading();
}

class AuthProfileUpdateSuccess extends AuthState {
  final UserModel user;

  const AuthProfileUpdateSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthProfileUpdateFailure extends AuthState {
  final String message;

  const AuthProfileUpdateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Zustände rund ums Profilbild. Sie bleiben „angemeldet“, damit die
/// Oberfläche während Upload/Fehler normal sichtbar bleibt.
abstract class AuthAvatarState extends AuthAuthenticated {
  const AuthAvatarState({required super.user});
}

class AuthAvatarUpdating extends AuthAvatarState {
  const AuthAvatarUpdating({required super.user});
}

class AuthAvatarUpdated extends AuthAvatarState {
  const AuthAvatarUpdated({required super.user});
}

class AuthAvatarUpdateFailure extends AuthAvatarState {
  final String message;

  const AuthAvatarUpdateFailure({required super.user, required this.message});

  @override
  List<Object?> get props => [user, message];
}
