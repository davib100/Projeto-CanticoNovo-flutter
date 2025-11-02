
// /modules/settings/widgets/backup_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import 'setting_card.dart';

class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

  Future<void> _handleBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final backupService = BackupService(
        logger: ref.read(appLoggerProvider),
      );

      // Simula coleta de dados do banco
      final data = {'settings': 'example', 'timestamp': DateTime.now().toIso8601String()};
      
      final backupFile = await backupService.createLocalBackup(data);
      await backupService.uploadToGoogleDrive(backupFile);

      final settings = ref.read(settingsProvider).value;
      if (settings != null) {
        await ref.read(settingsProvider.notifier).updateSetting(
          'lastBackup',
          DateTime.now(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao fazer backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Restauração'),
        content: const Text(
          'Isso substituirá todos os dados atuais. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);

    try {
      // Lógica de restauração aqui
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup restaurado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao restaurar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return SettingCard(
      title: 'Sincronização e Backup',
      description: 'Gerencie seus dados na nuvem',
      icon: Icons.cloud_upload,
      child: Column(
        children: [
          // Backup Automático
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Backup Automático'),
            subtitle: const Text('Sincroniza apenas via Wi-Fi'),
            value: settings.autoBackup,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).updateSetting('autoBackup', value);
            },
          ),
          const SizedBox(height: 8),

          // Último Backup
          if (settings.lastBackup != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Último backup: ${DateFormat('dd/MM/yyyy HH:mm').format(settings.lastBackup!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          const SizedBox(height: 16),

          // Botões
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBackingUp ? null : _handleBackup,
                  icon: _isBackingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.backup),
                  label: Text(_isBackingUp ? 'Fazendo...' : 'Fazer Backup'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRestoring ? null : _handleRestore,
                  icon: _isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore),
                  label: Text(_isRestoring ? 'Restaurando...' : 'Restaurar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
