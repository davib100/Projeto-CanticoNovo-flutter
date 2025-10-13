// core/services/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../security/auth_service.dart';
import '../observability/observability_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ApiClient {
  final String baseUrl;
  AuthService? _authService;
  final ObservabilityService _observability;
  final http.Client _httpClient;
  
  // Headers padrão
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  ApiClient({
  required this.baseUrl,
  required ObservabilityService observability,
  required AuthService authService,  // add this
  http.Client? httpClient,
})  : _observability = observability,
      _httpClient = httpClient ?? http.Client(),
      _authService = authService;

  void setAuthService(AuthService authService) {
    _authService = authService;
  }
  
  /// GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      'GET',
      endpoint,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }
  
  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      'POST',
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }
  
  /// PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      'PUT',
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }
  
  /// DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      'DELETE',
      endpoint,
      requiresAuth: requiresAuth,
    );
  }
  
  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      'PATCH',
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }
  
  /// Faz a requisição HTTP
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    final transaction = Sentry.startTransaction(
  'http.$method',
  'http.client',
);

    
    try {
      // Construir URL
      final uri = _buildUri(endpoint, queryParams);
      
      // Construir headers
      final headers = await _buildHeaders(requiresAuth);
      
      // Criar span para a requisição
      final span = transaction.startChild(
        'http.request',
        description: '$method $uri',
      );
      
      span.setData('url', uri.toString());
      span.setData('method', method);
      
      // Fazer requisição
      http.Response response;
      
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _httpClient.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await _httpClient.put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
          break;
        case 'PATCH':
          response = await _httpClient.patch(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        default:
          throw UnsupportedError('Method $method not supported');
      }
      
      span.setData('status_code', response.statusCode);
      await span.finish(status: _getSpanStatus(response.statusCode));
      
      // Processar resposta
      return await _handleResponse(response, method, endpoint);
      
    } on SocketException {
      await transaction.finish(status: SpanStatus.unavailable());
      throw ApiException(
        'No internet connection',
        statusCode: 0,
        endpoint: endpoint,
      );
    } on HttpException catch (e) {
      await transaction.finish(status: SpanStatus.internalError());
      throw ApiException(
        e.message,
        statusCode: 0,
        endpoint: endpoint,
      );
    } catch (e) {
      await transaction.finish(status: SpanStatus.unknownError());
      _observability.captureException(e, endpoint: endpoint);
      rethrow;
    } finally {
      await transaction.finish();
    }
  }
  
  /// Constrói a URI completa
  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
  }
  
  /// Constrói os headers da requisição
  Future<Map<String, String>> _buildHeaders(bool requiresAuth) async {
    final headers = Map<String, String>.from(_defaultHeaders);
    
    if (requiresAuth) {
      final token = await _authService?.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  /// Processa a resposta HTTP
  Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
    String method,
    String endpoint,
  ) async {
    final statusCode = response.statusCode;
    
    // Sucesso (2xx)
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException(
          'Invalid JSON response',
          statusCode: statusCode,
          endpoint: endpoint,
        );
      }
    }
    
    // Não autorizado (401)
    if (statusCode == 401) {
      await _authService?.logout();
      throw UnauthorizedException(endpoint);
    }
    
    // Token expirado (403 com refresh)
    if (statusCode == 403) {
      try {
        await _authService!.refreshToken();
        // Retentar requisição original
        return await _makeRequest(method, endpoint);
      } catch (e) {
        throw SessionExpiredException();
      }
    }
    
    // Outros erros
    String errorMessage = 'Request failed';
    try {
      final errorBody = jsonDecode(response.body);
      errorMessage = errorBody['message'] ?? errorMessage;
    } catch (_) {
      errorMessage = response.body.isNotEmpty 
        ? response.body 
        : 'HTTP $statusCode';
    }
    
    throw ApiException(
      errorMessage,
      statusCode: statusCode,
      endpoint: endpoint,
    );
  }
  
  /// Obtém o status do span do Sentry baseado no código HTTP
  SpanStatus _getSpanStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return SpanStatus.ok();
    } else if (statusCode == 401 || statusCode == 403) {
      return SpanStatus.unauthenticated();
    } else if (statusCode == 404) {
      return SpanStatus.notFound();
    } else if (statusCode >= 500) {
      return SpanStatus.internalError();
    } else {
      return SpanStatus.unknownError();
    }
  }
  
  /// Fecha o client HTTP
  void dispose() {
    _httpClient.close();
  }
}

/// Exceção genérica de API
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String endpoint;
  
  ApiException(
    this.message, {
    required this.statusCode,
    required this.endpoint,
  });
  
  @override
  String toString() => 
    'ApiException [$statusCode] at $endpoint: $message';
}

/// Exceção de não autorizado
class UnauthorizedException extends ApiException {
  UnauthorizedException(String endpoint)
    : super(
        'Unauthorized access',
        statusCode: 401,
        endpoint: endpoint,
      );
}

/// Exceção de sessão expirada
class SessionExpiredException implements Exception {
  @override
  String toString() => 'SessionExpiredException: Session has expired';
}
