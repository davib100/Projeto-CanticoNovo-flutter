// core/security/encryption_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const String _keyStorageKey = 'app_encryption_master_key';
  static const String _ivStorageKey = 'app_encryption_iv';
  final FlutterSecureStorage _secureStorage;
  
  late encrypt.Key _masterKey;
  late encrypt.IV _iv;
  late encrypt.Encrypter _encrypter;
  
  EncryptionService(this._secureStorage);
  
  /// Inicializa o serviço de criptografia
  Future<void> initialize() async {
    await _loadOrGenerateKeys();
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_masterKey, mode: encrypt.AESMode.cbc)
    );
  }
  
  /// Carrega ou gera as chaves de criptografia
  Future<void> _loadOrGenerateKeys() async {
    final storedKey = await _secureStorage.read(key: _keyStorageKey);
    final storedIv = await _secureStorage.read(key: _ivStorageKey);
    
    if (storedKey != null && storedIv != null) {
      _masterKey = encrypt.Key.fromBase64(storedKey);
      _iv = encrypt.IV.fromBase64(storedIv);
    } else {
      await _generateAndStoreKeys();
    }
  }
  
  /// Gera e armazena novas chaves
  Future<void> _generateAndStoreKeys() async {
    _masterKey = encrypt.Key.fromSecureRandom(32); // 256 bits
    _iv = encrypt.IV.fromSecureRandom(16); // 128 bits
    
    await _secureStorage.write(
      key: _keyStorageKey, 
      value: _masterKey.base64
    );
    await _secureStorage.write(
      key: _ivStorageKey, 
      value: _iv.base64
    );
  }
  
  /// Criptografa dados usando AES-256-CBC
  Future<Uint8List> encrypt(
    Uint8List plainData, 
    {String? key}
  ) async {
    try {
      final encrypter = key != null 
        ? encrypt.Encrypter(encrypt.AES(
            _deriveKeyFromPassword(key),
            mode: encrypt.AESMode.cbc
          ))
        : _encrypter;
      
      final encrypted = encrypter.encryptBytes(
        plainData, 
        iv: _iv
      );
      
      return encrypted.bytes;
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }
  
  /// Descriptografa dados usando AES-256-CBC
  Future<Uint8List> decrypt(
    Uint8List encryptedData, 
    {String? key}
  ) async {
    try {
      final encrypter = key != null 
        ? encrypt.Encrypter(encrypt.AES(
            _deriveKeyFromPassword(key),
            mode: encrypt.AESMode.cbc
          ))
        : _encrypter;
      
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedData),
        iv: _iv
      );
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw DecryptionException('Failed to decrypt data: $e');
    }
  }
  
  /// Criptografa string
  Future<String> encryptString(String plainText, {String? key}) async {
    final bytes = utf8.encode(plainText);
    final encrypted = await encrypt(Uint8List.fromList(bytes), key: key);
    return base64.encode(encrypted);
  }
  
  /// Descriptografa string
  Future<String> decryptString(String encryptedText, {String? key}) async {
    final bytes = base64.decode(encryptedText);
    final decrypted = await decrypt(bytes, key: key);
    return utf8.decode(decrypted);
  }
  
  /// Deriva uma chave de 256 bits a partir de uma senha
  encrypt.Key _deriveKeyFromPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }
  
  /// Gera hash SHA-256 de dados
  String hashData(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }
  
  /// Gera hash SHA-256 de string
  String hashString(String text) {
    final bytes = utf8.encode(text);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verifica se um hash corresponde aos dados
  bool verifyHash(Uint8List data, String hash) {
    return hashData(data) == hash;
  }
  
  /// Rotaciona as chaves de criptografia
  Future<void> rotateKeys() async {
    final oldKey = _masterKey;
    final oldIv = _iv;
    
    await _generateAndStoreKeys();
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_masterKey, mode: encrypt.AESMode.cbc)
    );
    
    // Armazenar chaves antigas para possível rollback
    await _secureStorage.write(
      key: '${_keyStorageKey}_backup',
      value: oldKey.base64
    );
    await _secureStorage.write(
      key: '${_ivStorageKey}_backup',
      value: oldIv.base64
    );
  }
  
  /// Remove todas as chaves armazenadas
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    await _secureStorage.delete(key: '${_keyStorageKey}_backup');
    await _secureStorage.delete(key: '${_ivStorageKey}_backup');
  }
}

/// Exceção de criptografia
class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}

/// Exceção de descriptografia
class DecryptionException implements Exception {
  final String message;
  DecryptionException(this.message);
  
  @override
  String toString() => 'DecryptionException: $message';
}
