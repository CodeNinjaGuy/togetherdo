import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';

class ThemeSwitchWidget extends StatelessWidget {
  const ThemeSwitchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        bool isDarkMode = false;

        if (state is ThemeLoadSuccess) {
          isDarkMode = state.isDarkMode;
        } else if (state is ThemeToggleSuccess) {
          isDarkMode = state.isDarkMode;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Switch(
              value: isDarkMode,
              onChanged: (value) {
                context.read<ThemeBloc>().add(const ThemeToggleRequested());
              },
              activeColor: Theme.of(context).colorScheme.primary,
              activeTrackColor: Theme.of(context).colorScheme.primaryContainer,
              inactiveThumbColor: Theme.of(context).colorScheme.outline,
              inactiveTrackColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ],
        );
      },
    );
  }
}
