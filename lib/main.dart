/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/todo/todo_bloc.dart';
import 'blocs/shopping/shopping_bloc.dart';
import 'blocs/list/list_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_event.dart';
import 'blocs/theme/theme_state.dart';
import 'blocs/notification/notification_bloc.dart';
import 'blocs/language/language_bloc.dart';
import 'blocs/language/language_event.dart';
import 'blocs/language/language_state.dart';
import 'design/td_design.dart';
import 'navigation/app_shell.dart';
import 'navigation/kalender_platzhalter.dart';
import 'repositories/anhang_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/todo_repository.dart';
import 'repositories/shopping_repository.dart';
import 'repositories/list_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/product_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/heute_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/todo/todo_screen.dart';
import 'screens/shopping/shopping_screen.dart';
import 'screens/shopping/shopping_demo_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'design/showcase/design_gallery_screen.dart';
import 'design/showcase/today_screen.dart';
import 'services/attachment_service.dart';
import 'utils/app_theme.dart';
import 'utils/global_navigator.dart';
import 'firebase_options.dart';
import 'services/messaging_service.dart';
import 'services/firebase_emulator.dart';
import 'services/review_service.dart';
import 'services/product_lookup_service.dart';
import 'config/app_info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Nur für lokale Tests: `--dart-define=USE_FIREBASE_EMULATOR=true`
  // verbindet Auth, Firestore und Storage mit der Firebase Emulator Suite.
  if (useFirebaseEmulator) {
    await connectToFirebaseEmulator();
  }

  // Navigation Callbacks für Push-Benachrichtigungen setzen
  MessagingService().setNavigationCallbacks(
    navigateToChat: (todoId, listId, todoTitle) {
      GlobalNavigator().navigateToChat(todoId, listId, todoTitle);
    },
    navigateToTodo: (todoId, listId) {
      GlobalNavigator().navigateToTodo(todoId, listId);
    },
    navigateToList: (listId) {
      GlobalNavigator().navigateToList(listId);
    },
    navigateToShoppingList: (listId, [itemId]) {
      GlobalNavigator().navigateToShoppingList(listId, itemId);
    },
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => FirebaseAuthRepository(),
        ),
        RepositoryProvider<TodoRepository>(
          create: (context) => FirebaseTodoRepository(),
        ),
        RepositoryProvider<ShoppingRepository>(
          create: (context) => FirebaseShoppingRepository(),
        ),
        RepositoryProvider<ListRepository>(
          create: (context) => FirebaseListRepository(),
        ),
        RepositoryProvider<ChatRepository>(
          create: (context) => FirestoreChatRepository(),
        ),
        // Anhänge (Fotos, PDFs, Dokumente) an Aufgaben und Terminen,
        // Bilder im Chat: ein Dienst, eine Ablage.
        RepositoryProvider<AnhangRepository>(
          create: (context) => FirestoreAnhangRepository(),
        ),
        RepositoryProvider<AttachmentService>(
          create: (context) => AttachmentService(),
        ),
        // Produktsuche per Strichcode: Gerät → Firestore → Open Food Facts.
        RepositoryProvider<ProductRepository>(
          create: (context) => ProductRepository(
            store: FirestoreProductStore(),
            lookupService: ProductLookupService(appVersion: appVersion),
          ),
        ),
      ],
      child: const TogetherDoApp(),
    ),
  );

  // Push erst nach dem ersten Bild einrichten: Berechtigungsdialog und
  // APNs-Token dürfen den Start nicht blockieren (weißer Bildschirm).
  // Beim Debug-Start auf einer Design-Route (Screenshots) kein Push.
  if (!(kDebugMode && _debugStart.startsWith('/design/'))) {
    unawaited(MessagingService().initialize());
  }

  // Erste Nutzung merken (Bewertungsanfrage frühestens nach 3 Tagen).
  unawaited(ReviewService.instance.recordAppStart());
}

class TogetherDoApp extends StatelessWidget {
  const TogetherDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LanguageBloc>(
          create: (context) =>
              LanguageBloc(authRepository: context.read<AuthRepository>())
                ..add(const LanguageLoadRequested()),
        ),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: context.read<AuthRepository>(),
            languageBloc: context.read<LanguageBloc>(),
          )..add(const AuthCheckRequested()),
        ),
        BlocProvider<TodoBloc>(
          create: (context) =>
              TodoBloc(todoRepository: context.read<TodoRepository>()),
        ),
        BlocProvider<ShoppingBloc>(
          create: (context) => ShoppingBloc(
            shoppingRepository: context.read<ShoppingRepository>(),
          ),
        ),
        BlocProvider<ListBloc>(
          create: (context) =>
              ListBloc(listRepository: context.read<ListRepository>()),
        ),
        BlocProvider<ThemeBloc>(
          create: (context) => ThemeBloc()..add(const ThemeLoadRequested()),
        ),
        BlocProvider<NotificationBloc>(create: (context) => NotificationBloc()),
      ],
      child: TogetherDoAppView(),
    );
  }
}

const String _debugStart = String.fromEnvironment('TD_START');

/// Gespeicherter Theme-Name aus dem [ThemeState].
String themeNameOf(ThemeState state) => switch (state) {
  ThemeLoadSuccess(:final themeName) => themeName,
  ThemeChangedSuccess(:final themeName) => themeName,
  _ => AppTheme.defaultTheme,
};

class TogetherDoAppView extends StatelessWidget {
  TogetherDoAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final themeName = themeNameOf(themeState);
        // „System“: hell/dunkel folgt dem Gerät; sonst das gewählte Theme
        // unabhängig von der Systemeinstellung.
        final system = AppTheme.isSystem(themeName);
        final chosen = AppTheme.of(themeName);
        // Global Navigator Router setzen
        GlobalNavigator().setRouter(_router);

        return BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, languageState) {
            Locale? currentLocale;
            if (languageState is LanguageLoadSuccess) {
              currentLocale = languageState.locale;
            } else if (languageState is LanguageChangedSuccess) {
              currentLocale = languageState.locale;
            }

            return MaterialApp.router(
              title: 'ToGetherDo',
              debugShowCheckedModeBanner: false,
              theme: system ? AppTheme.of(AppTheme.defaultTheme) : chosen,
              darkTheme: system ? AppTheme.of(AppTheme.darkTheme) : chosen,
              themeMode: system ? ThemeMode.system : ThemeMode.light,
              routerConfig: _router,
              locale: currentLocale,
              localeResolutionCallback: (locale, supportedLocales) {
                // Immer das gewünschte Locale übernehmen
                return currentLocale ?? locale ?? supportedLocales.first;
              },
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('de', 'DE'), // Deutsch (Deutschland)
                Locale('de', 'AT'), // Deutsch (Österreich)
                Locale('en', 'GB'), // Englisch (England)
                Locale('en', 'US'), // Englisch (USA)
              ],
              builder: (context, child) {
                return BlocListener<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthFailure) {
                      TdToast.show(
                        context,
                        state.message,
                        variant: TdToastVariant.error,
                      );
                    } else if (state is AuthAuthenticated &&
                        state is! AuthAvatarState) {
                      // Nach erfolgreicher Authentifizierung: Profilsprache laden
                      context.read<LanguageBloc>().add(
                        const LanguageLoadProfileRequested(),
                      );
                    }
                  },
                  child: child!,
                );
              },
            );
          },
        );
      },
    );
  }

  final GoRouter _router = GoRouter(
    // Debug-Builds können mit `--dart-define=TD_START=/design/einkauf`
    // direkt auf einer Design-Route starten (Screenshots im Simulator).
    initialLocation: kDebugMode && _debugStart.startsWith('/design/')
        ? _debugStart
        : '/login',
    redirect: (context, state) {
      // Prüfe Auth-Status
      final authBloc = context.read<AuthBloc>();
      final authState = authBloc.state;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc.startsWith('/passwort-vergessen');

      // Wenn nicht authentifiziert und nicht auf Login/Register-Seite
      if (authState is! AuthAuthenticated &&
          !isAuthRoute &&
          !loc.startsWith('/design/')) {
        return '/login';
      }

      // Wenn authentifiziert und auf Login/Register-Seite
      if (authState is AuthAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Routes (außerhalb der Shell)
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Design-Entwurf (Stufe 2), nur im Debug-Build: Startbildschirm
      // „Heute“ mit Beispieldaten und Galerie aller Bausteine.
      if (kDebugMode) ...[
        GoRoute(
          path: '/design/heute',
          builder: (context, state) => TdTodayScreen(
            onOpenGallery: () => context.push('/design/galerie'),
          ),
        ),
        GoRoute(
          path: '/design/galerie',
          builder: (context, state) => const TdDesignGalleryScreen(),
        ),
        // Einkaufsliste mit Scanner im Demo-Modus (Simulator ohne Kamera).
        GoRoute(
          path: '/design/einkauf',
          builder: (context, state) => const ShoppingDemoScreen(),
        ),
      ],

      // Chat je Aufgabe: Vollbild über der Shell (Tastatur, Bilder).
      GoRoute(
        path: '/chat/:todoId',
        pageBuilder: (context, state) {
          final todoId = state.pathParameters['todoId']!;
          final todoTitle = state.uri.queryParameters['title'] ?? '';
          final listId = state.uri.queryParameters['liste'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatScreen(
              todoId: todoId,
              todoTitle: todoTitle,
              listId: listId,
            ),
            transitionDuration: TdMotion.page,
            reverseTransitionDuration: TdMotion.page,
            transitionsBuilder: TdTransitions.fadeSlide,
          );
        },
      ),

      // App Routes (nur für authentifizierte Benutzer)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HeuteScreen()),
          GoRoute(
            path: '/lists',
            builder: (context, state) => const ListsScreen(),
          ),
          GoRoute(
            path: '/kalender',
            builder: (context, state) => KalenderPlatzhalter(
              listId: state.uri.queryParameters['liste'],
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/todo/:listId',
            builder: (context, state) {
              final listId = state.pathParameters['listId']!;
              return TodoScreen(listId: listId);
            },
          ),
          GoRoute(
            path: '/shopping/:listId',
            builder: (context, state) {
              final listId = state.pathParameters['listId']!;
              return ShoppingScreen(
                listId: listId,
                highlightItemId: state.uri.queryParameters['highlight'],
              );
            },
          ),
        ],
      ),
    ],
  );
}
