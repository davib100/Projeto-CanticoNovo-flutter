import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/api_client.dart';
import '../../../core/security/secure_storage.dart';
import '../models/music_entity.dart';

class SearchApi {
  static const String baseUrl = 'https://app.base44.com/api/apps/689cf551f2c7408b283acfdd';
  static const String apiKey = '9f06ef55eda744d59d8d52a098ac6f0b';
  
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  SearchApi({
    ApiClient? apiClient,
    SecureStorage? secureStorage,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _secureStorage = secureStorage ?? SecureStorage.instance;

  /// Busca músicas por título ou letra
  Future<List<MusicEntity>> searchMusic({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        '$baseUrl/entities/Music',
        headers: {
          'api_key': apiKey,
          'Content-Type': 'application/json',
        },
        queryParameters: {
          'query': query,
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MusicEntity.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Erro ao buscar músicas: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Falha na busca: $e');
    }
  }

  /// Atualiza dados de acesso da música
  Future<void> updateMusicAccess({
    required String musicId,
    required DateTime lastAccessed,
    required int accessCount,
  }) async {
    try {
      final response = await _apiClient.put(
        '$baseUrl/entities/Music/$musicId',
        headers: {
          'api_key': apiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'last_accessed': lastAccessed.toIso8601String(),
          'access_count': accessCount,
        }),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          'Erro ao atualizar acesso: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      // Log silencioso - não bloqueia a experiência do usuário
      print('Erro ao atualizar acesso da música: $e');
    }
  }

  /// Busca sugestões de pesquisa
  Future<List<String>> fetchSuggestions(String query) async {
    try {
      final response = await _apiClient.get(
        '$baseUrl/entities/Music/suggestions',
        headers: {
          'api_key': apiKey,
          'Content-Type': 'application/json',
        },
        queryParameters: {
          'query': query,
          'limit': '5',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item['title'] as String).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar sugestões: $e');
      return [];
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
