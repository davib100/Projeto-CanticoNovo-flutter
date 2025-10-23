
class Validators {
  Validators._();

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo é obrigatório';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email é obrigatório';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória';
    }

    if (value.length < 8) {
      return 'Senha deve ter pelo menos 8 caracteres';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Senha deve conter letras minúsculas';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Senha deve conter letras maiúsculas';
    }

    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Senha deve conter números';
    }

    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome é obrigatório';
    }

    if (value.trim().length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }

    return null;
  }
}
