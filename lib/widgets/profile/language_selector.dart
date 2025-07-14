import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/language/language_bloc.dart';
import '../../blocs/language/language_event.dart';
import '../../blocs/language/language_state.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageBloc, LanguageState>(
      builder: (context, state) {
        String currentLanguage = 'de';
        String currentCountry = 'DE';

        if (state is LanguageLoadSuccess) {
          currentLanguage = state.languageCode;
          currentCountry = state.countryCode;
        } else if (state is LanguageChangedSuccess) {
          currentLanguage = state.languageCode;
          currentCountry = state.countryCode;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Sprache'),
            subtitle: Text(
              _getLanguageDisplayName(currentLanguage, currentCountry),
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () =>
                _showLanguageDialog(context, currentLanguage, currentCountry),
          ),
        );
      },
    );
  }

  String _getLanguageDisplayName(String languageCode, String countryCode) {
    switch ('$languageCode-$countryCode') {
      case 'de-DE':
        return 'Deutsch (Deutschland)';
      case 'de-AT':
        return 'Deutsch (Österreich)';
      case 'en-EN':
        return 'English (England)';
      case 'en-US':
        return 'English (United States)';
      default:
        return 'Deutsch (Deutschland)';
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    String currentLanguage,
    String currentCountry,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sprache auswählen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context,
                'de',
                'DE',
                'Deutsch (Deutschland)',
                currentLanguage,
                currentCountry,
              ),
              _buildLanguageOption(
                context,
                'de',
                'AT',
                'Deutsch (Österreich)',
                currentLanguage,
                currentCountry,
              ),
              _buildLanguageOption(
                context,
                'en',
                'EN',
                'English (England)',
                currentLanguage,
                currentCountry,
              ),
              _buildLanguageOption(
                context,
                'en',
                'US',
                'English (United States)',
                currentLanguage,
                currentCountry,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String languageCode,
    String countryCode,
    String displayName,
    String currentLanguage,
    String currentCountry,
  ) {
    return ListTile(
      leading: Radio<String>(
        value: '$languageCode-$countryCode',
        groupValue: '$currentLanguage-$currentCountry',
        onChanged: (value) {
          context.read<LanguageBloc>().add(
            LanguageChanged(
              languageCode: languageCode,
              countryCode: countryCode,
            ),
          );
          Navigator.of(context).pop();
        },
      ),
      title: Text(displayName),
      onTap: () {
        context.read<LanguageBloc>().add(
          LanguageChanged(languageCode: languageCode, countryCode: countryCode),
        );
        Navigator.of(context).pop();
      },
    );
  }
}
