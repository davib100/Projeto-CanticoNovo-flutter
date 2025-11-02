
// /modules/settings/widgets/support_section.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'setting_card.dart';

class SupportSection extends StatefulWidget {
  const SupportSection({super.key});

  @override
  State<SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<SupportSection> {
  bool _showFeedback = false;
  final _feedbackController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escreva seu feedback')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Simula envio de feedback
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Feedback enviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _feedbackController.clear();
        setState(() => _showFeedback = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:suporte@canticonovo.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingCard(
      title: 'Suporte e Ajuda',
      description: 'Obtenha ajuda e envie feedback',
      icon: Icons.help_outline,
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _showFeedback = !_showFeedback),
            icon: const Icon(Icons.message),
            label: const Text('Enviar Feedback'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _launchEmail,
            icon: const Icon(Icons.email),
            label: const Text('Contato com Suporte'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/terms');
            },
            icon: const Icon(Icons.description),
            label: const Text('Termos de Uso e Privacidade'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),

          if (_showFeedback) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Seu Feedback',
                hintText: 'Compartilhe suas sugestões, problemas ou elogios...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendFeedback,
                    child: Text(_isSending ? 'Enviando...' : 'Enviar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showFeedback = false),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
