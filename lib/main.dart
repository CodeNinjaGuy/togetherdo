import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

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
import 'utils/app_theme.dart';
import 'firebase_options.dart';
import 'services/messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Messaging Service initialisieren
  await MessagingService().initialize();

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
    return MultiRepositoryProvider(
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepository>())
                  ..add(const AuthCheckRequested()),
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
          BlocProvider<NotificationBloc>(
            create: (context) => NotificationBloc(),
          ),
        ],
        child: TogetherDoAppView(),
      ),
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
        return MaterialApp.router(
          title: 'TogetherDo',
          debugShowCheckedModeBanner: false,
          theme: themeData,
          routerConfig: _router,
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
                }
              },
              child: child!,
            );
          },
        );
      },
    );
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (authState is AuthAuthenticated) {
        if (isAuthRoute) {
          return '/';
        }
        return null;
      } else {
        if (isAuthRoute) {
          return null;
        }
        return '/login';
      }
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ListsScreen()),
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
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
