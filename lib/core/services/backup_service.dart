
// core/services/backup_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/core/db/database_adapter.dart';
import 'package:myapp/core/security/encryption_service.dart';
import 'package:cryptography/cryptography.dart';


class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class BackupService {
  final GoogleSignIn _googleSignIn;
  final DatabaseAdapter _db;
  final EncryptionService _encryption;

  BackupService(this._googleSignIn, this._db, this._encryption);

  Future<void> createBackup() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google Sign-In failed');
    }
    final auth = await account.authentication;
    final authHeaders = {
      'Authorization': 'Bearer ${auth.accessToken}',
      'X-Goog-AuthUser': '0',
    };
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    // Exportar banco de dados
    final dbFile = await _db.export();

    // Criptografar com AES-256
    final internalKey = await _getInternalKey();
    final secretKey = SecretKey(internalKey);
    final encryptedData = await _encryption.encrypt(dbFile.readAsBytesSync(), customKey: secretKey);

    // Comprimir
    final compressed = GZipEncoder().encode(encryptedData.toBytes());

    // Upload para Google Drive
    final driveFile = drive.File()
      ..name = 'cantico_novo_backup_${DateTime.now().millisecondsSinceEpoch}.db.enc'
      ..parents = ['appDataFolder'];

    await driveApi.files.create(driveFile,
        uploadMedia: drive.Media(Stream.value(compressed!), compressed.length));
  }

  Future<void> restoreBackup(String fileId) async {
    final account = await _googleSignIn.signIn();
     if (account == null) {
      throw Exception('Google Sign-In failed');
    }
    final auth = await account.authentication;
    final authHeaders = {
      'Authorization': 'Bearer ${auth.accessToken}',
      'X-Goog-AuthUser': '0',
    };
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    // Download do arquivo
    final response = await driveApi.files
        .get(fileId, downloadOptions: drive.DownloadOptions.fullMedia)
        as drive.Media;

    final dataBytes = await _streamToBytes(response.stream);

    // Descomprimir
    final decompressed = GZipDecoder().decodeBytes(dataBytes);
    final encryptedData = EncryptedData.fromBytes(Uint8List.fromList(decompressed));

    // Descriptografar
    final internalKey = await _getInternalKey();
    final secretKey = SecretKey(internalKey);
    final decrypted = await _encryption.decrypt(encryptedData, customKey: secretKey);

    // Restaurar banco
    await _db.restore(decrypted);
  }

  Future<List<int>> _getInternalKey() async {
    // Em um cenário real, esta chave seria derivada de uma senha do usuário ou
    // armazenada de forma segura.
    return utf8.encode("a_super_secret_and_long_enough_key");
  }

  Future<List<int>> _streamToBytes(Stream<List<int>> stream) {
    final completer = Completer<List<int>>();
    final sink = ByteConversionSink.withCallback(
        (bytes) => completer.complete(bytes));
    stream.listen(sink.add, onError: completer.completeError, onDone: sink.close);
    return completer.future;
  }
}
