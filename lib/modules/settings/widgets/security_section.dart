
// /modules/settings/widgets/security_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/settings_provider.dart';
import 'setting_card.dart';

class SecuritySection extends ConsumerStatefulWidget {
  const SecuritySection({super.key});

  @override
  ConsumerState<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<SecuritySection> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      setState(() => _canCheckBiometrics = canCheck);
    } catch (e) {
      setState(() => _canCheckBiometrics = false);
    }
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value && _canCheckBiometrics) {
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Autentique-se para ativar o bloqueio biométrico',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (authenticated) {
          await ref.read(settingsProvider.notifier).updateSetting('biometricLock', true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao configurar biometria: $e')),
          );
        }
      }
    } else {
      await ref.read(settingsProvider.notifier).updateSetting('biometricLock', false);
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Cache'),
        content: const Text(
          'Isso irá limpar todos os dados salvos localmente. Configurações essenciais serão preservadas. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(settingsProvider.notifier).clearCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cache limpo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return SettingCard(
      title: 'Privacidade e Segurança',
      description: 'Configure segurança e privacidade',
      icon: Icons.security,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bloqueio por Biometria/Senha'),
            subtitle: Text(
              _canCheckBiometrics
                  ? 'Exigir autenticação para abrir o app'
                  : 'Biometria não disponível neste dispositivo',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: settings.biometricLock,
            onChanged: _canCheckBiometrics ? _handleBiometricToggle : null,
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Limpar Cache e Dados Locais'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
