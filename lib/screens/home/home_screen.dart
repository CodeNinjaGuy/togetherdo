import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/responsive_scaffold.dart';
import '../lists/lists_screen.dart';

class HomeScreen extends StatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _updateCurrentIndex();
      _initialized = true;
    }
  }

  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).uri.path;
    switch (location) {
      case '/':
        _currentIndex = 0;
        break;
      case '/profile':
        _currentIndex = 1;
        break;
      default:
        _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthAuthenticated) {
          final width = MediaQuery.of(context).size.width;
          final bool isWide = width >= 800;
          final location = GoRouterState.of(context).uri.path;
          final bool showSplitView =
              isWide &&
              (location.startsWith('/todo/') ||
                  location.startsWith('/shopping/'));

          return Scaffold(
            appBar: AppBar(title: const Text('ToGetherDo')),
            body: showSplitView
                ? ResponsiveScaffold(
                    leftChild: const ListsScreen(),
                    rightChild: widget.child,
                  )
                : widget.child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
                switch (index) {
                  case 0:
                    context.push('/');
                    break;
                  case 1:
                    context.push('/profile');
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.list_outlined),
                  selectedIcon: Icon(Icons.list),
                  label: 'Listen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          );
        }

        // Redirect zur Login-Seite, wenn nicht authentifiziert
        if (authState is AuthUnauthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const SizedBox.shrink();
        }

        // Fallback für nicht authentifizierte Benutzer
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  l10n.loading,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
