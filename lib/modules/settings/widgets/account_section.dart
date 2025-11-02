
// /modules/settings/widgets/account_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import 'setting_card.dart';

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return SettingCard(
          title: 'Conta',
          description: 'Informações da sua conta',
          icon: Icons.person,
          child: Column(
            children: [
              _buildInfoField('Nome', user.fullName ?? 'Não informado'),
              const SizedBox(height: 12),
              _buildInfoField('Email', user.email),
              const SizedBox(height: 12),
              _buildInfoField('Função', user.role == 'admin' ? 'Administrador' : 'Usuário'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar Saída'),
                        content: const Text('Tem certeza que deseja sair?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(authServiceProvider).logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sair da Conta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value),
        ),
      ],
    );
  }
}
