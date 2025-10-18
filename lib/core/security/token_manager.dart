import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myapp/core/security/encryption_service.dart';
import 'package:myapp/core/observability/observability_service.dart';

class TokenManager {
  final FlutterSecureStorage _secureStorage;
  final EncryptionService _encryptionService;
  final ObservabilityService _observabilityService;

  TokenManager({
    required FlutterSecureStorage secureStorage,
    required EncryptionService encryptionService,
    required ObservabilityService observabilityService,
  }) : _secureStorage = secureStorage,
       _encryptionService = encryptionService,
       _observabilityService = observabilityService;

  Future<void> storeAccessToken(String token) async {
    try {
      final encryptedToken = await _encryptionService.encryptString(token);
      await _secureStorage.write(key: 'access_token', value: encryptedToken);
      _observabilityService.addBreadcrumb('Access token stored successfully');
    } catch (e) {
      _observabilityService.captureException(e, stackTrace: StackTrace.current);
      throw Exception('Failed to store access token');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final encryptedToken = await _secureStorage.read(key: 'access_token');
      if (encryptedToken == null) {
        return null;
      }
      final token = await _encryptionService.decryptString(encryptedToken);
      _observabilityService.addBreadcrumb(
        'Access token retrieved successfully',
      );
      return token;
    } catch (e) {
      _observabilityService.captureException(e, stackTrace: StackTrace.current);
      return null;
    }
  }

  Future<void> deleteAccessToken() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      _observabilityService.addBreadcrumb('Access token deleted successfully');
    } catch (e) {
      _observabilityService.captureException(e, stackTrace: StackTrace.current);
      throw Exception('Failed to delete access token');
    }
  }
}
