
/// Uma classe de utilitário que fornece métodos de validação estáticos para
/// formulários e lógica de negócios.
class Validators {
  // Regex para validação de email, alinhado com padrões comuns.
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Regex para validar nomes, permitindo letras (incluindo acentos), espaços e apóstrofos.
  static final RegExp _nameRegExp = RegExp(r"^[a-zA-Z\\s\\-'\u00C0-\u017F]+$");

  // Lista (curta) de domínios de email descartáveis conhecidos para a validação.
  // Em um app real, isso seria mais extenso e possivelmente gerenciado remotamente.
  static const List<String> _disposableDomains = [
    '10minutemail.com',
    'temp-mail.org',
    'guerrillamail.com',
    'mailinator.com',
  ];

  // ---------------------------------------------------------------------------
  // Validadores de Lógica de Negócios (retornam bool)
  // Usados principalmente nos UseCases.
  // ---------------------------------------------------------------------------

  /// Verifica se a string fornecida tem um formato de email válido.
  ///
  /// Retorna `true` se o email for válido, `false` caso contrário.
  static bool isValidEmail(String email) {
    return _emailRegExp.hasMatch(email);
  }

  /// Verifica se o nome fornecido contém apenas caracteres válidos (letras, espaços, hífens, apóstrofos).
  ///
  /// Retorna `true` se o nome for válido, `false` caso contrário.
  static bool isValidName(String name) {
    return _nameRegExp.hasMatch(name);
  }

  /// Verifica se o domínio de um email pertence a uma lista de provedores de email descartáveis.
  ///
  /// Retorna `true` se for um domínio descartável, `false` caso contrário.
  static bool isDisposableEmail(String email) {
    if (!isValidEmail(email)) return false;
    final domain = email.split('@').last.toLowerCase();
    return _disposableDomains.contains(domain);
  }

  // ---------------------------------------------------------------------------
  // Validadores de Formulário (retornam String? de erro)
  // Usados principalmente nos FormFields da UI.
  // ---------------------------------------------------------------------------

  /// Validador para campos de formulário que são obrigatórios.
  ///
  /// Retorna uma mensagem de erro se o campo for nulo ou vazio, caso contrário, retorna `null`.
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    return null;
  }

  /// Validador para campos de email.
  ///
  /// Combina a verificação `required` com a validação de formato `isValidEmail`.
  /// Retorna a mensagem de erro apropriada ou `null` se válido.
  static String? email(String? value) {
    final requiredError = required(value);
    if (requiredError != null) {
      // Personaliza a mensagem para o campo de email.
      return 'Email é obrigatório';
    }
    if (!isValidEmail(value!)) {
      return 'Formato de email inválido';
    }
    return null;
  }

  /// Validador para campos de senha.
  ///
  /// Verifica se a senha atende aos critérios de força:
  /// - Campo obrigatório
  /// - Mínimo de 8 caracteres
  /// - Pelo menos uma letra maiúscula
  /// - Pelo menos uma letra minúscula
  /// - Pelo menos um número
  ///
  /// Retorna a mensagem de erro apropriada ou `null` se a senha for forte.
  static String? password(String? value) {
    final requiredError = required(value);
    if (requiredError != null) {
      return 'Senha é obrigatória';
    }
    if (value!.length < 8) {
      return 'Senha deve ter no mínimo 8 caracteres';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Precisa ter uma letra maiúscula';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Precisa ter uma letra minúscula';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Precisa ter um número';
    }
    return null;
  }
}
