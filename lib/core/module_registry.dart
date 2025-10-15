// core/module_registry.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'db/database_adapter.dart';
import 'queue/queue_manager.dart';
import 'observability/observability_service.dart';

/// Registry central para gerenciar todos os módulos da aplicação
class ModuleRegistry {
  static final ModuleRegistry _instance = ModuleRegistry._internal();
  factory ModuleRegistry() => _instance;
  ModuleRegistry._internal();
  
  final GetIt _locator = GetIt.instance;
  final Map<Type, AppModule> _modules = {};
  final Map<Type, ModuleMetadata> _metadata = {};
  final List<ModuleLifecycleObserver> _observers = [];
  
  bool _isInitialized = false;
  
  /// Obtém o locator interno (GetIt)
  GetIt get locator => _locator;
  
  /// Verifica se o registry foi inicializado
  bool get isInitialized => _isInitialized;
  
  /// Registra um módulo
  void register<T extends AppModule>(
    T module, {
    ModulePriority priority = ModulePriority.normal,
    List<Type>? dependencies,
    bool lazy = false,
  }) {
    if (_modules.containsKey(T)) {
      throw ModuleAlreadyRegisteredException(
        'Module ${T.toString()} is already registered'
      );
    }
    
    _modules[T] = module;
    _metadata[T] = ModuleMetadata(
      type: T,
      priority: priority,
      dependencies: dependencies ?? [],
      lazy: lazy,
      registeredAt: DateTime.now(),
    );
    
    // Notificar observers
    for (final observer in _observers) {
      observer.onModuleRegistered(module);
    }
    
    if (kDebugMode) {
      print('📦 Module registered: ${module.name} [Priority: ${priority.name}]');
    }
  }
  
  /// Registra múltiplos módulos de uma vez
  void registerAll(List<AppModule> modules) {
    for (final module in modules) {
      register(module);
    }
  }
  
  /// Inicializa todos os módulos registrados
  Future<void> initializeAll({
    required DatabaseAdapter db,
    required QueueManager queue,
    required ObservabilityService observability,
  }) async {
    if (_isInitialized) {
      throw ModuleRegistryException('Modules already initialized');
    }
    
    // Registrar serviços core no GetIt
    _registerCoreServices(db, queue, observability);
    
    // Ordenar módulos por prioridade e dependências
    final sortedModules = _sortModulesByDependencies();
    
    // Inicializar cada módulo
    for (final module in sortedModules) {
      await _initializeModule(module, db, queue, observability);
    }
    
    _isInitialized = true;
    
    if (kDebugMode) {
      print('✅ All modules initialized successfully');
    }
  }
  
  /// Registra serviços core no GetIt
  void _registerCoreServices(
    DatabaseAdapter db,
    QueueManager queue,
    ObservabilityService observability,
  ) {
    _locator.registerSingleton<DatabaseAdapter>(db);
    _locator.registerSingleton<QueueManager>(queue);
    _locator.registerSingleton<ObservabilityService>(observability);
    
    if (kDebugMode) {
      print('🔧 Core services registered in GetIt');
    }
  }
  
  /// Inicializa um módulo individual
  Future<void> _initializeModule(
    AppModule module,
    DatabaseAdapter db,
    QueueManager queue,
    ObservabilityService observability,
  ) async {
    final metadata = _metadata[module.runtimeType]!;
    
    // Verificar se é lazy e não deve ser inicializado agora
    if (metadata.lazy) {
      if (kDebugMode) {
        print('⏭️  Skipping lazy module: ${module.name}');
      }
      return;
    }
    
    final startTime = DateTime.now();
    
    try {
      // Notificar observers - antes da inicialização
      for (final observer in _observers) {
        observer.onModuleInitializing(module);
      }
      
      // Inicializar o módulo
      await module.initialize(db, queue);
      
      // Registrar no GetIt
      _locator.registerSingleton(module, instanceName: module.name);
      
      // Atualizar metadata
      metadata.isInitialized = true;
      metadata.initializationTime = DateTime.now().difference(startTime);
      
      // Notificar observers - após inicialização
      for (final observer in _observers) {
        observer.onModuleInitialized(module);
      }
      
      // Log de observabilidade
      observability.logBoot(
        timestamp: startTime,
        module: module.name,
        persistence: module.useQueue ? 'Fila (QueueManager)' : 'Direto (DB)',
        action: module.mainAction,
        status: '✅ Sucesso',
      );
      
      if (kDebugMode) {
        print('✅ Module initialized: ${module.name} '
              '(${metadata.initializationTime?.inMilliseconds}ms)');
      }
      
    } catch (e, stackTrace) {
      // Log de erro
      observability.logBoot(
        timestamp: startTime,
        module: module.name,
        persistence: module.useQueue ? 'Fila (QueueManager)' : 'Direto (DB)',
        action: module.mainAction,
        status: '❌ Falha',
      );
      
      observability.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'module.initialization',
      );
      
      // Notificar observers - erro
      for (final observer in _observers) {
        observer.onModuleError(module, e, stackTrace);
      }
      
      throw ModuleInitializationException(
        'Failed to initialize module ${module.name}: $e',
        module: module,
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Inicializa um módulo lazy sob demanda
  Future<void> initializeLazy<T extends AppModule>() async {
    final module = _modules[T];
    if (module == null) {
      throw ModuleNotFoundException('Module ${T.toString()} not found');
    }
    
    final metadata = _metadata[T]!;
    if (metadata.isInitialized) {
      if (kDebugMode) {
        print('⚠️  Module ${module.name} already initialized');
      }
      return;
    }
    
    final db = _locator<DatabaseAdapter>();
    final queue = _locator<QueueManager>();
    final observability = _locator<ObservabilityService>();
    
    await _initializeModule(module, db, queue, observability);
  }
  
  /// Obtém um módulo registrado
  T get<T extends AppModule>() {
    final module = _modules[T];
    if (module == null) {
      throw ModuleNotFoundException('Module ${T.toString()} not registered');
    }
    
    final metadata = _metadata[T]!;
    if (!metadata.isInitialized && metadata.lazy) {
      throw ModuleNotInitializedException(
        'Module ${module.name} is lazy and not initialized yet. '
        'Call initializeLazy<${T.toString()}>() first.'
      );
    }
    
    return module as T;
  }
  
  /// Tenta obter um módulo (retorna null se não encontrado)
  T? tryGet<T extends AppModule>() {
    try {
      return get<T>();
    } on ModuleNotFoundException {
      return null;
    } on ModuleNotInitializedException {
      return null;
    }
  }
  
  /// Obtém metadados de um módulo
  ModuleMetadata? getMetadata<T extends AppModule>() {
    return _metadata[T];
  }
  
  /// Obtém todos os módulos registrados
  List<AppModule> getRegisteredModules() {
    return _modules.values.toList();
  }
  
  /// Obtém módulos inicializados
  List<AppModule> getInitializedModules() {
    return _modules.entries
        .where((entry) => _metadata[entry.key]?.isInitialized ?? false)
        .map((entry) => entry.value)
        .toList();
  }
  
  /// Obtém módulos lazy não inicializados
  List<AppModule> getLazyModules() {
    return _modules.entries
        .where((entry) => 
          _metadata[entry.key]?.lazy == true &&
          _metadata[entry.key]?.isInitialized == false
        )
        .map((entry) => entry.value)
        .toList();
  }
  
  /// Ordena módulos por dependências e prioridade
  List<AppModule> _sortModulesByDependencies() {
    final sorted = <AppModule>[];
    final visited = <Type>{};
    final visiting = <Type>{};
    
    void visit(Type type) {
      if (visited.contains(type)) return;
      
      if (visiting.contains(type)) {
        throw CircularDependencyException(
          'Circular dependency detected involving module: ${type.toString()}'
        );
      }
      
      visiting.add(type);
      
      final metadata = _metadata[type];
      if (metadata != null) {
        // Visitar dependências primeiro
        for (final dependency in metadata.dependencies) {
          if (_modules.containsKey(dependency)) {
            visit(dependency);
          }
        }
      }
      
      visiting.remove(type);
      visited.add(type);
      
      final module = _modules[type];
      if (module != null) {
        sorted.add(module);
      }
    }
    
    // Visitar todos os módulos
    for (final type in _modules.keys) {
      visit(type);
    }
    
    // Ordenar por prioridade dentro da ordem de dependências
    sorted.sort((a, b) {
      final priorityA = _metadata[a.runtimeType]!.priority;
      final priorityB = _metadata[b.runtimeType]!.priority;
      return priorityB.value.compareTo(priorityA.value);
    });
    
    return sorted;
  }
  
  /// Adiciona um observer de ciclo de vida
  void addLifecycleObserver(ModuleLifecycleObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }
  
  /// Remove um observer de ciclo de vida
  void removeLifecycleObserver(ModuleLifecycleObserver observer) {
    _observers.remove(observer);
  }
  
  /// Destrói um módulo específico
  Future<void> dispose<T extends AppModule>() async {
    final module = _modules[T];
    if (module == null) return;
    
    try {
      await module.dispose();
      
      // Remover do GetIt
      if (_locator.isRegistered<T>(instanceName: module.name)) {
        await _locator.unregister<T>(instanceName: module.name);
      }
      
      // Atualizar metadata
      final metadata = _metadata[T];
      if (metadata != null) {
        metadata.isInitialized = false;
      }
      
      // Notificar observers
      for (final observer in _observers) {
        observer.onModuleDisposed(module);
      }
      
      if (kDebugMode) {
        print('🗑️  Module disposed: ${module.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disposing module ${module.name}: $e');
      }
      rethrow;
    }
  }
  
  /// Destrói todos os módulos
  Future<void> disposeAll() async {
    for (final module in _modules.values.toList().reversed) {
      try {
        await module.dispose();
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error disposing module ${module.name}: $e');
        }
      }
    }
    
    _modules.clear();
    _metadata.clear();
    _isInitialized = false;
    
    await _locator.reset();
    
    if (kDebugMode) {
      print('🗑️  All modules disposed');
    }
  }
  
  /// Gera relatório de status dos módulos
  ModuleRegistryReport generateReport() {
    return ModuleRegistryReport(
      totalModules: _modules.length,
      initializedModules: getInitializedModules().length,
      lazyModules: getLazyModules().length,
      metadata: Map.unmodifiable(_metadata),
      isHealthy: _checkHealth(),
    );
  }
  
  /// Verifica saúde do registry
  bool _checkHealth() {
    for (final metadata in _metadata.values) {
      if (!metadata.lazy && !metadata.isInitialized) {
        return false;
      }
    }
    return true;
  }
  
  /// Limpa o registry (útil para testes)
  @visibleForTesting
  void clear() {
    _modules.clear();
    _metadata.clear();
    _observers.clear();
    _isInitialized = false;
  }
}

/// Interface base para módulos da aplicação
@immutable
abstract class AppModule {
  /// Nome do módulo
  String get name;
  
  /// Se o módulo usa fila para persistência
  bool get useQueue;
  
  /// Ação principal do módulo (para logging)
  String get mainAction;
  
  /// Inicializa o módulo
  Future<void> initialize(DatabaseAdapter db, QueueManager queue);
  
  /// Libera recursos do módulo
  Future<void> dispose();
}

/// Metadata de um módulo
class ModuleMetadata {
  final Type type;
  final ModulePriority priority;
  final List<Type> dependencies;
  final bool lazy;
  final DateTime registeredAt;
  
  bool isInitialized = false;
  Duration? initializationTime;
  
  ModuleMetadata({
    required this.type,
    required this.priority,
    required this.dependencies,
    required this.lazy,
    required this.registeredAt,
  });
  
  @override
  String toString() {
    return 'ModuleMetadata('
           'type: $type, '
           'priority: ${priority.name}, '
           'initialized: $isInitialized, '
           'lazy: $lazy, '
           'dependencies: ${dependencies.length}'
           ')';
  }
}

/// Prioridade de inicialização do módulo
enum ModulePriority {
  critical(100),   // Módulos críticos (Auth, Database)
  high(75),        // Módulos importantes (Sync, Security)
  normal(50),      // Módulos padrão (Library, Lyrics)
  low(25),         // Módulos secundários (Settings, UI)
  background(0);   // Módulos de background (Analytics, Logs)
  
  final int value;
  const ModulePriority(this.value);
}

/// Observer de ciclo de vida dos módulos
abstract class ModuleLifecycleObserver {
  void onModuleRegistered(AppModule module) {}
  void onModuleInitializing(AppModule module) {}
  void onModuleInitialized(AppModule module) {}
  void onModuleError(AppModule module, dynamic error, StackTrace stackTrace) {}
  void onModuleDisposed(AppModule module) {}
}

/// Relatório do registry
class ModuleRegistryReport {
  final int totalModules;
  final int initializedModules;
  final int lazyModules;
  final Map<Type, ModuleMetadata> metadata;
  final bool isHealthy;
  
  ModuleRegistryReport({
    required this.totalModules,
    required this.initializedModules,
    required this.lazyModules,
    required this.metadata,
    required this.isHealthy,
  });
  
  int get uninitializedModules => totalModules - initializedModules;
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('     MODULE REGISTRY REPORT');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Total Modules:        $totalModules');
    buffer.writeln('Initialized:          $initializedModules');
    buffer.writeln('Lazy (Not Init):      $lazyModules');
    buffer.writeln('Uninitialized:        $uninitializedModules');
    buffer.writeln('Health Status:        ${isHealthy ? "✅ HEALTHY" : "❌ UNHEALTHY"}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('\nModule Details:');
    buffer.writeln('───────────────────────────────────────');
    
    for (final entry in metadata.entries) {
      final meta = entry.value;
      buffer.writeln('${meta.isInitialized ? "✅" : "⏸️ "} ${entry.key.toString()}');
      buffer.writeln('   Priority: ${meta.priority.name}');
      buffer.writeln('   Lazy: ${meta.lazy}');
      if (meta.initializationTime != null) {
        buffer.writeln('   Init Time: ${meta.initializationTime!.inMilliseconds}ms');
      }
      if (meta.dependencies.isNotEmpty) {
        buffer.writeln('   Dependencies: ${meta.dependencies.length}');
      }
      buffer.writeln('───────────────────────────────────────');
    }
    
    return buffer.toString();
  }
}

// ══════════════════════════════════════════
// EXCEÇÕES
// ══════════════════════════════════════════

class ModuleRegistryException implements Exception {
  final String message;
  ModuleRegistryException(this.message);
  
  @override
  String toString() => 'ModuleRegistryException: $message';
}

class ModuleAlreadyRegisteredException extends ModuleRegistryException {
  ModuleAlreadyRegisteredException(super.message);
}

class ModuleNotFoundException extends ModuleRegistryException {
  ModuleNotFoundException(super.message);
}

class ModuleNotInitializedException extends ModuleRegistryException {
  ModuleNotInitializedException(super.message);
}

class ModuleInitializationException extends ModuleRegistryException {
  final AppModule module;
  final dynamic originalException;
  final StackTrace? stackTrace;
  
  ModuleInitializationException(
    super.message, {
    required this.module,
    this.originalException,
    this.stackTrace,
  });
  
  @override
  String toString() {
    return 'ModuleInitializationException: $message\n'
           'Module: ${module.name}\n'
           'Original: $originalException';
  }
}

class CircularDependencyException extends ModuleRegistryException {
  CircularDependencyException(super.message);
}
