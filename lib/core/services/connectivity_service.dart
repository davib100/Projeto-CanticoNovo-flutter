import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

/// Service para verificar conectividade de rede
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final BehaviorSubject<bool> _isConnectedController = 
      BehaviorSubject.seeded(true);

  Stream<bool> get isConnected$ => _isConnectedController.stream;
  bool get isConnected => _isConnectedController.value;

  /// Inicializa listener de conectividade
  void initialize() {
    _connectivity.onConnectivityChanged.listen((result) {
      final hasConnection = result != ConnectivityResult.none;
      _isConnectedController.add(hasConnection);
    });

    // Verifica conectividade inicial
    checkConnection();
  }

  /// Verifica conectividade atual
  Future<bool> hasConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final connected = result != ConnectivityResult.none;
      _isConnectedController.add(connected);
      return connected;
    } catch (e) {
      return false;
    }
  }

  /// Verifica conectividade atual (método alternativo)
  Future<void> checkConnection() async {
    await hasConnection();
  }

  void dispose() {
    _isConnectedController.close();
  }
}
