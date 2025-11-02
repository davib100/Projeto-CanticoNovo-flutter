
// /modules/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../widgets/setting_card.dart';
import '../widgets/appearance_section.dart';
import '../widgets/typography_section.dart';
import '../widgets/backup_section.dart';
import '../widgets/security_section.dart';
import '../widgets/notifications_section.dart';
import '../widgets/language_section.dart';
import '../widgets/account_section.dart';
import '../widgets/support_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: settingsAsync.when(
        data: (settings) => _buildContent(context, ref, settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar configurações: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(settingsProvider),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          const SizedBox(height: 24),

          // Seções
          const AccountSection(),
          const SizedBox(height: 16),
          
          const AppearanceSection(),
          const SizedBox(height: 16),
          
          const TypographySection(),
          const SizedBox(height: 16),
          
          const BackupSection(),
          const SizedBox(height: 16),
          
          const SecuritySection(),
          const SizedBox(height: 16),
          
          const NotificationsSection(),
          const SizedBox(height: 16),
          
          const LanguageSection(),
          const SizedBox(height: 16),
          
          const SupportSection(),
          const SizedBox(height: 24),

          // Botão de salvar na nuvem
          _buildSaveButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.settings, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Personalize sua experiência',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await ref.read(settingsProvider.notifier).syncWithCloud();
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Configurações sincronizadas com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Salvar na Nuvem'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      ),
    );
  }
}
