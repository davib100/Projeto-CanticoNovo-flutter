
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cantico_novo/shared/widgets/loading_overlay.dart';
import 'package:cantico_novo/shared/utils/validators.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    final result = await ref.read(authStateProvider.notifier).resetPassword(email: email);

    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (_) {
        setState(() {
          _emailSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Instruções enviadas para $email'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _handleResendEmail() async {
    final email = _emailController.text.trim();

    final result = await ref.read(authStateProvider.notifier).resetPassword(email: email);

    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email reenviado com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark 
          ? const Color(0xFF0F172A) 
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _emailSent ? _buildSuccessState(isDark) : _buildFormState(authState, isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState(AuthState authState, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const AuthHeader(
            title: 'Redefinir sua senha',
            subtitle: 'Digite seu email para receber as instruções de redefinição de senha.',
            showIcon: true,
            icon: Icons.shield_outlined,
          ),
          
          const SizedBox(height: 40),

          // Email
          AuthTextField(
            controller: _emailController,
            label: 'Email',
            hintText: 'seu@email.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: Validators.email,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleResetPassword(),
            autofocus: true,
          ),

          const SizedBox(height: 24),

          // Botão Enviar
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark 
                  ? const Color(0xFFFBBF24) 
                  : const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: authState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Enviar instruções',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // Link para login
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lembrou da senha? ',
                style: TextStyle(
                  color: isDark 
                      ? Colors.grey[400] 
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: authState.isLoading 
                    ? null 
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Fazer login',
                  style: TextStyle(
                    color: isDark 
                        ? const Color(0xFFFBBF24) 
                        : const Color(0xFFF59E0B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Aviso de segurança
          Center(
            child: Text(
              'Por segurança, o link expira em 1 hora',
              style: TextStyle(
                fontSize: 12,
                color: isDark 
                    ? Colors.grey[500] 
                    : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ícone de sucesso
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.email_outlined,
            size: 40,
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 24),

        // Título
        Text(
          'Email enviado',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Descrição
        Text(
          'Enviamos um link de redefinição para:',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          _emailController.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Card com instruções
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFFFBBF24).withOpacity(0.1) 
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próximos passos:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark 
                      ? const Color(0xFFFBBF24) 
                      : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 12),
              _buildStep('1. Verifique sua caixa de entrada', isDark),
              const SizedBox(height: 8),
              _buildStep('2. Clique no link do email', isDark),
              const SizedBox(height: 8),
              _buildStep('3. Crie uma nova senha', isDark),
              const SizedBox(height: 8),
              _buildStep('4. Faça login com a nova senha', isDark),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Botão Reenviar
        OutlinedButton(
          onPressed: _handleResendEmail,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(
              color: isDark 
                  ? const Color(0xFFFBBF24) 
                  : const Color(0xFFF59E0B),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Reenviar email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark 
                  ? const Color(0xFFFBBF24) 
                  : const Color(0xFFF59E0B),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Botão Voltar
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Voltar ao login',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark 
                  ? const Color(0xFFFBBF24) 
                  : const Color(0xFFD97706),
            ),
          ),
        ),
      ],
    );
  }
}
