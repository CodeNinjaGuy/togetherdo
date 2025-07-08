import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthUpdateProfileRequested extends AuthEvent {
  final String displayName;
  final String? avatarUrl;

  const AuthUpdateProfileRequested({required this.displayName, this.avatarUrl});

  @override
  List<Object?> get props => [displayName, avatarUrl];
}

class AuthUploadAvatarRequested extends AuthEvent {
  final String imagePath;

  const AuthUploadAvatarRequested({required this.imagePath});

  @override
  List<Object?> get props => [imagePath];
}
