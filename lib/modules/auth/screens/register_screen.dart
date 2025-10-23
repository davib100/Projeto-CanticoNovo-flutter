
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cantico_novo/shared/widgets/loading_overlay.dart';
import 'package:cantico_novo/shared/utils/validators.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_strength_indicator.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha';
    }
    if (value != _passwordController.text) {
      return 'Senhas não coincidem';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você deve aceitar os termos de uso'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await ref.read(authStateProvider.notifier).register(
      fullName: fullName,
      email: email,
      password: password,
    );

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
      (user) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Redirecionar para home ou login
        Navigator.of(context).pushReplacementNamed('/home');
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const AuthHeader(
                        title: 'Criar nova conta',
                        subtitle: 'Preencha os dados abaixo para começar',
                        showIcon: true,
                      ),
                      
                      const SizedBox(height: 40),

                      // Nome Completo
                      AuthTextField(
                        controller: _fullNameController,
                        label: 'Nome Completo',
                        hintText: 'Seu nome completo',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nome é obrigatório';
                          }
                          if (value.trim().length < 2) {
                            return 'Nome deve ter pelo menos 2 caracteres';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 16),

                      // Email
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'seu@email.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: Validators.email,
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 16),

                      // Senha
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Senha',
                        hintText: 'Mínimo 8 caracteres',
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword 
                                ? Icons.visibility_outlined 
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: Validators.password,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),

                      // Indicador de força da senha
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        PasswordStrengthIndicator(
                          password: _passwordController.text,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Confirmar Senha
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirmar Senha',
                        hintText: 'Confirme sua senha',
                        obscureText: _obscureConfirmPassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword 
                                ? Icons.visibility_outlined 
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        validator: _validateConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleRegister(),
                        onChanged: (_) => setState(() {}),
                      ),

                      // Indicador de senhas coincidentes
                      if (_confirmPasswordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _passwordController.text == _confirmPasswordController.text
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color: _passwordController.text == _confirmPasswordController.text
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _passwordController.text == _confirmPasswordController.text
                                  ? 'Senhas coincidem'
                                  : 'Senhas não coincidem',
                              style: TextStyle(
                                fontSize: 12,
                                color: _passwordController.text == _confirmPasswordController.text
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Termos e Condições
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFFF59E0B),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark 
                                        ? Colors.grey[400] 
                                        : Colors.grey[600],
                                  ),
                                  children: [
                                    const TextSpan(text: 'Eu aceito os '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pushNamed('/terms');
                                        },
                                        child: Text(
                                          'Termos de Uso',
                                          style: TextStyle(
                                            color: isDark 
                                                ? const Color(0xFFFBBF24) 
                                                : const Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: ' e '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pushNamed('/privacy');
                                        },
                                        child: Text(
                                          'Política de Privacidade',
                                          style: TextStyle(
                                            color: isDark 
                                                ? const Color(0xFFFBBF24) 
                                                : const Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Botão Criar Conta
                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleRegister,
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
                                    'Criar conta',
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
                            'Já tem uma conta? ',
                            style: TextStyle(
                              color: isDark 
                                  ? Colors.grey[400] 
                                  : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Faça login',
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
                          'Todos os dados são criptografados e protegidos',
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
