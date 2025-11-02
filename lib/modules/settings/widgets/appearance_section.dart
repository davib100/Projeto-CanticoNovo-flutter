
// /modules/settings/widgets/appearance_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'setting_card.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return SettingCard(
      title: 'Aparência',
      description: 'Personalize a aparência do aplicativo',
      icon: Icons.palette,
      child: Column(
        children: [
          // Tema
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tema'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'light', label: Text('Claro'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: 'dark', label: Text('Escuro'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {settings.theme},
                onSelectionChanged: (Set<String> newSelection) {
                  ref.read(settingsProvider.notifier).updateSetting('theme', newSelection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tamanho da fonte
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tamanho da Fonte: ${settings.fontSize}px'),
              Slider(
                value: settings.fontSize.toDouble(),
                min: 12,
                max: 24,
                divisions: 6,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSetting('fontSize', value.toInt());
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cor de destaque
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cor de Destaque'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  '#f59e0b', '#3b82f6', '#10b981', 
                  '#ef4444', '#8b5cf6', '#f97316'
                ].map((color) {
                  final isSelected = settings.accentColor == color;
                  return GestureDetector(
                    onTap: () {
                      ref.read(settingsProvider.notifier).updateSetting('accentColor', color);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
