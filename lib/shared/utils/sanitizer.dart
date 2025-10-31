import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sanitizador de inputs
class Sanitizer {
  /// Remove HTML tags e caracteres perigosos
  String sanitizeText(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[<>]'), '') // Remove < >
        .trim();
  }

  /// Sanitiza email
  String sanitizeEmail(String email) {
    return email.toLowerCase().trim();
  }
}

final sanitizerProvider = Provider<Sanitizer>((ref) => Sanitizer());
