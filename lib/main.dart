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
import 'repositories/auth_repository.dart';
import 'repositories/todo_repository.dart';
import 'repositories/shopping_repository.dart';
import 'repositories/list_repository.dart';
import 'repositories/chat_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/todo/todo_screen.dart';
import 'screens/shopping/shopping_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'utils/app_theme.dart';
import 'utils/global_navigator.dart';
import 'firebase_options.dart';
import 'services/messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Messaging Service initialisieren
  await MessagingService().initialize();

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
      ],
      child: const TogetherDoApp(),
    ),
  );
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

class TogetherDoAppView extends StatelessWidget {
  TogetherDoAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        String themeName = 'Light';
        if (themeState is ThemeLoadSuccess) {
          themeName = themeState.themeName;
        } else if (themeState is ThemeChangedSuccess) {
          themeName = themeState.themeName;
        }
        final themeData =
            AppTheme.themes[themeName] ?? AppTheme.themes['Light'];
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
              theme: themeData,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    } else if (state is AuthAuthenticated) {
                      // Nach erfolgreicher Authentifizierung: Profilsprache laden
                      context.read<LanguageBloc>().add(
                        const LanguageLoadProfileRequested(),
                      );
                    } else if (state is AuthUnauthenticated) {
                      // Nach Logout: Keine Sprachänderung - gespeicherte Sprache beibehalten
                      // context.read<LanguageBloc>().add(
                      //   const LanguageLoadSystemRequested(),
                      // );
                    }
                  },
                  child: BlocListener<LanguageBloc, LanguageState>(
                    listener: (context, state) {
                      if (state is LanguageChangedSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sprache geändert zu ${state.languageCode.toUpperCase()}',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: child!,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  final GoRouter _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Prüfe Auth-Status
      final authBloc = context.read<AuthBloc>();
      final authState = authBloc.state;

      // Wenn nicht authentifiziert und nicht auf Login/Register-Seite
      if (authState is! AuthAuthenticated &&
          !state.matchedLocation.startsWith('/login') &&
          !state.matchedLocation.startsWith('/register')) {
        return '/login';
      }

      // Wenn authentifiziert und auf Login/Register-Seite
      if (authState is AuthAuthenticated &&
          (state.matchedLocation.startsWith('/login') ||
              state.matchedLocation.startsWith('/register'))) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Routes (außerhalb der ShellRoute)
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // App Routes (nur für authentifizierte Benutzer)
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ListsScreen()),
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
              return ShoppingScreen(listId: listId);
            },
          ),
          GoRoute(
            path: '/lists',
            builder: (context, state) => const ListsScreen(),
          ),
          GoRoute(
            path: '/chat/:todoId',
            builder: (context, state) {
              final todoId = state.pathParameters['todoId']!;
              final todoTitle = state.uri.queryParameters['title'] ?? 'Chat';
              return ChatScreen(todoId: todoId, todoTitle: todoTitle);
            },
          ),
        ],
      ),
    ],
  );
}
