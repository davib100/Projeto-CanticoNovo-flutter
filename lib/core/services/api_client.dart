
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myapp/core/security/token_manager.dart';
import 'package:myapp/core/observability/observability_service.dart';

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

  Future<http.Response> get(String endpoint) async {
    final span = _observabilityService.startChild('http.get', description: endpoint);
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
      return response;
    } catch (e) {
      span?.status = const SpanStatus.internalError();
      span?.throwable = e;
      rethrow;
    } finally {
      await span?.finish();
    }
  }

  Future<http.Response> post(String endpoint, dynamic body) async {
    final span = _observabilityService.startChild('http.post', description: endpoint);
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        body: json.encode(body),
        headers: headers,
      );
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
      return response;
    } catch (e) {
      span?.status = const SpanStatus.internalError();
      span?.throwable = e;
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
}
