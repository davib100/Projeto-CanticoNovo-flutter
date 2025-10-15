/// Exceção customizada para erros de módulo
class ModuleException implements Exception {
  final String message;
  final String module;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const ModuleException(
    this.message, {
    required this.module,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'ModuleException [$module]: $message'
        '${originalError != null ? '\nOriginal error: $originalError' : ''}';
  }
}
