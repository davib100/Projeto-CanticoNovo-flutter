
// /modules/settings/widgets/typography_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'setting_card.dart';

class TypographySection extends ConsumerWidget {
  const TypographySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return SettingCard(
      title: 'Tipografia',
      description: 'Configure fontes e tamanhos de texto',
      icon: Icons.text_fields,
      child: Column(
        children: [
          // Tipo de Fonte
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tipo de Fonte'),
              DropdownButton<String>(
                value: settings.fontFamily,
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('Sistema')),
                  DropdownMenuItem(value: 'serif', child: Text('Serifada')),
                  DropdownMenuItem(value: 'mono', child: Text('Monoespaçada')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updateSetting('fontFamily', value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Velocidade de Rolagem Automática
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Velocidade da Rolagem: ${settings.autoScrollSpeed.toStringAsFixed(1)}x'),
              Slider(
                value: settings.autoScrollSpeed,
                min: 0.5,
                max: 5.0,
                divisions: 9,
                label: '${settings.autoScrollSpeed.toStringAsFixed(1)}x',
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSetting('autoScrollSpeed', value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
