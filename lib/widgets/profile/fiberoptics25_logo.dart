import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_state.dart';

class Fiberoptics25Logo extends StatelessWidget {
  const Fiberoptics25Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        // Aktuelles Theme ermitteln
        String currentTheme = 'Light'; // Default
        if (state is ThemeLoadSuccess) {
          currentTheme = state.themeName;
        } else if (state is ThemeChangedSuccess) {
          currentTheme = state.themeName;
        }

        // Logo nur im Fiberoptics25 Theme anzeigen
        if (currentTheme == 'Fiberoptics25') {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo
                SvgPicture.asset(
                  'assets/images/FO25-Logo.svg',
                  height: 80,
                  width: 80,
                ),
                const SizedBox(height: 12),
                // Theme Name
                Text(
                  'Fiberoptics25',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Beschreibung
                Text(
                  'Technologie meets Design',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                // Farbpalette anzeigen
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildColorDot(
                      Theme.of(context).colorScheme.primary,
                      'Primary',
                    ),
                    _buildColorDot(
                      Theme.of(context).colorScheme.secondary,
                      'Secondary',
                    ),
                    _buildColorDot(
                      Theme.of(context).colorScheme.tertiary,
                      'Accent',
                    ),
                    _buildColorDot(
                      Theme.of(context).colorScheme.outline,
                      'Blue',
                    ),
                    _buildColorDot(
                      Theme.of(context).colorScheme.outlineVariant,
                      'Green',
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Wenn nicht Fiberoptics25 Theme, nichts anzeigen
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildColorDot(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
}
