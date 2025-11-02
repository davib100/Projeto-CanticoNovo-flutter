
// /modules/settings/widgets/notifications_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'setting_card.dart';

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return SettingCard(
      title: 'Notificações',
      description: 'Configure alertas e lembretes',
      icon: Icons.notifications,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Receber Notificações'),
            value: settings.notifications,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).updateSetting('notifications', value);
            },
          ),
          
          if (settings.notifications) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Horário Preferido'),
                TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.parse(settings.notificationTime.split(':')[0]),
                        minute: int.parse(settings.notificationTime.split(':')[1]),
                      ),
                    );

                    if (time != null) {
                      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      ref.read(settingsProvider.notifier).updateSetting('notificationTime', timeString);
                    }
                  },
                  child: Text(settings.notificationTime),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
