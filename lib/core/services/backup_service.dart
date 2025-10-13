// core/services/backup_service.dart
class BackupService {
  final GoogleSignIn _googleSignIn;
  final DatabaseAdapter _db;
  final EncryptionService _encryption;
  
  Future<void> createBackup() async {
    final account = await _googleSignIn.signIn();
    final authHeaders = await account!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);
    
    // Exportar banco de dados
    final dbFile = await _db.export();
    
    // Criptografar com AES-256
    final encryptedData = await _encryption.encrypt(
      dbFile,
      key: _getInternalKey()
    );
    
    // Comprimir
    final compressed = GZipEncoder().encode(encryptedData);
    
    // Upload para Google Drive
    final driveFile = drive.File()
      ..name = 'cantico_novo_backup_${DateTime.now().millisecondsSinceEpoch}.db.enc'
      ..parents = ['appDataFolder'];
    
    await driveApi.files.create(
      driveFile,
      uploadMedia: drive.Media(Stream.value(compressed!), compressed.length)
    );
  }
  
  Future<void> restoreBackup(String fileId) async {
    final account = await _googleSignIn.signIn();
    final authHeaders = await account!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);
    
    // Download do arquivo
    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia
    ) as drive.Media;
    
    final dataBytes = await _streamToBytes(response.stream);
    
    // Descomprimir
    final decompressed = GZipDecoder().decodeBytes(dataBytes);
    
    // Descriptografar
    final decrypted = await _encryption.decrypt(
      decompressed,
      key: _getInternalKey()
    );
    
    // Restaurar banco
    await _db.restore(decrypted);
  }
}
