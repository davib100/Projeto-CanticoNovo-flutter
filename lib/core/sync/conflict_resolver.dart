// core/sync/conflict_resolver.dart

/// Interface para resolvedores de conflito
abstract class ConflictResolver {
  Future<ConflictResolution> resolve(ConflictContext context);
}

/// Contexto de conflito
class ConflictContext {
  final dynamic localData;
  final Map<String, dynamic> serverData;
  final ConflictResolutionStrategy strategy;

  ConflictContext({
    required this.localData,
    required this.serverData,
    required this.strategy,
  });
}

/// Resultado da resolução de conflito
class ConflictResolution {
  final bool isResolved;
  final bool requiresManualResolution;
  final Map<String, dynamic> resolvedData;
  final ConflictResolutionStrategy strategy;
  final ConflictWinner winner;
  final ConflictContext context;

  ConflictResolution({
    required this.isResolved,
    required this.requiresManualResolution,
    required this.resolvedData,
    required this.strategy,
    required this.winner,
    required this.context,
  });
}

/// Estratégias de resolução de conflito
enum ConflictResolutionStrategy {
  lastWriteWins,
  serverWins,
  clientWins,
  manual,
  threeWayMerge,
}

/// Vencedor do conflito
enum ConflictWinner { client, server, merged, none }

/// Resolvedor padrão
class DefaultConflictResolver implements ConflictResolver {
  @override
  Future<ConflictResolution> resolve(ConflictContext context) async {
    switch (context.strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        return _lastWriteWins(context);
      case ConflictResolutionStrategy.serverWins:
        return _serverWins(context);
      case ConflictResolutionStrategy.clientWins:
        return _clientWins(context);
      default:
        return ConflictResolution(
          isResolved: false,
          requiresManualResolution: true,
          resolvedData: {},
          strategy: context.strategy,
          winner: ConflictWinner.none,
          context: context,
        );
    }
  }

  ConflictResolution _lastWriteWins(ConflictContext context) {
    final localTimestamp = DateTime.parse(
      context.localData['updated_at'] ?? DateTime.now().toIso8601String(),
    );
    final serverTimestamp = DateTime.parse(
      context.serverData['updated_at'] ?? DateTime.now().toIso8601String(),
    );

    if (serverTimestamp.isAfter(localTimestamp)) {
      return ConflictResolution(
        isResolved: true,
        requiresManualResolution: false,
        resolvedData: context.serverData,
        strategy: ConflictResolutionStrategy.lastWriteWins,
        winner: ConflictWinner.server,
        context: context,
      );
    } else {
      return ConflictResolution(
        isResolved: true,
        requiresManualResolution: false,
        resolvedData: context.localData,
        strategy: ConflictResolutionStrategy.lastWriteWins,
        winner: ConflictWinner.client,
        context: context,
      );
    }
  }

  ConflictResolution _serverWins(ConflictContext context) {
    return ConflictResolution(
      isResolved: true,
      requiresManualResolution: false,
      resolvedData: context.serverData,
      strategy: ConflictResolutionStrategy.serverWins,
      winner: ConflictWinner.server,
      context: context,
    );
  }

  ConflictResolution _clientWins(ConflictContext context) {
    return ConflictResolution(
      isResolved: true,
      requiresManualResolution: false,
      resolvedData: context.localData,
      strategy: ConflictResolutionStrategy.clientWins,
      winner: ConflictWinner.client,
      context: context,
    );
  }
}

/// Resolvedor para Songs
class SongConflictResolver extends DefaultConflictResolver {
  // Implementação específica para conflitos de músicas
}

/// Resolvedor para Categories
class CategoryConflictResolver extends DefaultConflictResolver {
  // Implementação específica para conflitos de categorias
}
