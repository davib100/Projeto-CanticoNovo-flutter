
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Uri? uri;

  ApiException(this.message, {this.statusCode, this.uri});

  @override
  String toString() {
    return 'ApiException: $message (Status code: $statusCode, URI: $uri)';
  }
}
