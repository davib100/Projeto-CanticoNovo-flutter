
// /modules/settings/widgets/language_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'setting_card.dart';

class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return SettingCard(
      title: 'Idioma e Região',
      description: 'Configure seu idioma preferido',
      icon: Icons.language,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Idioma'),
          DropdownButton<String>(
            value: settings.language,
            items: const [
              DropdownMenuItem(value: 'pt', child: Text('🇧🇷 Português (BR)')),
              DropdownMenuItem(value: 'en', child: Text('🇺🇸 English')),
              DropdownMenuItem(value: 'es', child: Text('🇪🇸 Español')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).updateSetting('language', value);
              }
            },
          ),
        ],
      ),
    );
  }
}
