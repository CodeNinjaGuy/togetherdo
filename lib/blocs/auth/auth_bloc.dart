import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../language/language_bloc.dart';
import '../language/language_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final LanguageBloc _languageBloc;

  AuthBloc({
    required AuthRepository authRepository,
    required LanguageBloc languageBloc,
  }) : _authRepository = authRepository,
       _languageBloc = languageBloc,
       super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthUpdateProfileRequested>(_onAuthUpdateProfileRequested);
    on<AuthUploadAvatarRequested>(_onAuthUploadAvatarRequested);
    on<AuthUpdateLanguageRequested>(_onAuthUpdateLanguageRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user: user));
        // Nach erfolgreicher Authentifizierung: Profilsprache laden
        _loadProfileLanguage();
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user: user));
      // Nach erfolgreichem Login: Profilsprache laden
      _loadProfileLanguage();
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      emit(AuthAuthenticated(user: user));
      // Nach erfolgreicher Registrierung: Profilsprache laden
      _loadProfileLanguage();
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signOut();
      emit(const AuthUnauthenticated());
      // Nach Logout: Gespeicherte Sprache beibehalten (nicht zur Systemsprache zurück)
      // _loadSystemLanguage(); // Entfernt - Sprache bleibt erhalten
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthUpdateProfileRequested(
    AuthUpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthProfileUpdateLoading());
    try {
      final user = await _authRepository.updateProfile(
        displayName: event.displayName,
        avatarUrl: event.avatarUrl,
      );
      // Nach erfolgreichem Update direkt zu AuthAuthenticated wechseln
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthProfileUpdateFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthUploadAvatarRequested(
    AuthUploadAvatarRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthProfileUpdateLoading());
    try {
      final avatarUrl = await _authRepository.uploadAvatar(event.imagePath);
      final currentState = state;
      if (currentState is AuthAuthenticated) {
        final updatedUser = currentState.user.copyWith(avatarUrl: avatarUrl);
        // Nach erfolgreichem Avatar-Upload direkt zu AuthAuthenticated wechseln
        emit(AuthAuthenticated(user: updatedUser));
      }
    } catch (e) {
      emit(AuthProfileUpdateFailure(message: e.toString()));
    }
  }

  void _loadProfileLanguage() {
    // Profilsprache aus Firebase laden und SharedPreferences aktualisieren
    _languageBloc.add(const LanguageLoadProfileRequested());
  }

  Future<void> _onAuthUpdateLanguageRequested(
    AuthUpdateLanguageRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthProfileUpdateLoading());
    try {
      final user = await _authRepository.updateLanguage(
        languageCode: event.languageCode,
        countryCode: event.countryCode,
      );

      // Sprache auch in SharedPreferences speichern
      _languageBloc.add(
        LanguageChanged(
          languageCode: event.languageCode,
          countryCode: event.countryCode,
        ),
      );

      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthProfileUpdateFailure(message: e.toString()));
    }
  }
}
