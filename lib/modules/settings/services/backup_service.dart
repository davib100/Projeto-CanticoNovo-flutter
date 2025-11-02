
// /modules/settings/services/backup_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../../core/observability/logger.dart';

class BackupService {
  final AppLogger _logger;
  static const String _encryptionKey = 'c4nt1c0N0v0S3cr3tK3y2025!@#\$'; // 32 chars

  BackupService({required AppLogger logger}) : _logger = logger;

  /// Cria backup local criptografado
  Future<File> createLocalBackup(Map<String, dynamic> data) async {
    try {
      _logger.info('BackupService', '📦 Criando backup local');

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/backup_$timestamp.enc');

      // Criptografa os dados
      final encryptedData = _encryptData(jsonEncode(data));
      
      await file.writeAsString(encryptedData);

      _logger.success('BackupService', '✅ Backup local criado: ${file.path}');
      return file;
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Erro ao criar backup local', e, stackTrace);
      rethrow;
    }
  }

  /// Restaura backup local
  Future<Map<String, dynamic>> restoreLocalBackup(File file) async {
    try {
      _logger.info('BackupService', '📥 Restaurando backup local');

      final encryptedData = await file.readAsString();
      final decryptedData = _decryptData(encryptedData);
      
      _logger.success('BackupService', '✅ Backup restaurado com sucesso');
      return jsonDecode(decryptedData);
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Erro ao restaurar backup', e, stackTrace);
      rethrow;
    }
  }

  /// Envia backup para Google Drive
  Future<void> uploadToGoogleDrive(File backupFile) async {
    try {
      _logger.info('BackupService', '☁️ Enviando backup para Google Drive');

      final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
      final account = await googleSignIn.signIn();
      
      if (account == null) {
        throw Exception('Login no Google cancelado');
      }

      final authHeaders = await account.authHeaders;
      final authenticateClient = _GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final driveFile = drive.File()
        ..name = backupFile.path.split('/').last
        ..parents = ['appDataFolder'];

      final media = drive.Media(backupFile.openRead(), await backupFile.length());
      
      await driveApi.files.create(driveFile, uploadMedia: media);

      _logger.success('BackupService', '✅ Backup enviado para Google Drive');
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Erro ao enviar para Google Drive', e, stackTrace);
      rethrow;
    }
  }

  /// Criptografa dados com AES-256
  String _encryptData(String plainText) {
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  /// Descriptografa dados
  String _decryptData(String encryptedText) {
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    return encrypter.decrypt64(encryptedText, iv: iv);
  }
}

/// Cliente HTTP autenticado para Google APIs
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
