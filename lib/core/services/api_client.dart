import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myapp/core/security/token_manager.dart';
import 'package:myapp/core/observability/observability_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'api_exception.dart'; // Importa a exceção customizada

class ApiClient {
  final String baseUrl;
  final http.Client _client;
  final TokenManager _tokenManager;
  final ObservabilityService _observabilityService;

  ApiClient({
    required this.baseUrl,
    required http.Client client,
    required TokenManager tokenManager,
    required ObservabilityService observabilityService,
  })  : _client = client,
        _tokenManager = tokenManager,
        _observabilityService = observabilityService;

  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final span = _observabilityService.startChild(
      'http.get',
      description: endpoint,
    );
    final uri =
        Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);

    try {
      final headers = await _getHeaders();
      final response = await _client.get(uri, headers: headers);

      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to load data from $endpoint',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
    } catch (e, stackTrace) {
      span?.status = const SpanStatus.internalError();
      span?.throwable = e;
      _observabilityService.captureException(e,
          stackTrace: stackTrace, endpoint: 'ApiClient.get');
      rethrow;
    } finally {
      await span?.finish();
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, dynamic body) async {
    final span = _observabilityService.startChild(
      'http.post',
      description: endpoint,
    );
    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        uri,
        body: json.encode(body),
        headers: headers,
      );

      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to post data to $endpoint',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
    } catch (e, stackTrace) {
      span?.status = const SpanStatus.internalError();
      span?.throwable = e;
      _observabilityService.captureException(e,
          stackTrace: stackTrace, endpoint: 'ApiClient.post');
      rethrow;
    } finally {
      await span?.finish();
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenManager.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void dispose() {
    _client.close();
  }
}
