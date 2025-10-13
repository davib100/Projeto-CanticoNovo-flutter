import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_orchestrator.dart';
import '../../core/module_registry.dart';
import 'data/repositories/terms_repository_impl.dart';
import 'domain/repositories/terms_repository.dart';

@AppModule(
  name: 'TermsModule',
  persistenceType: PersistenceType.direct, // Escrita direta - não crítico para sync
  route: '/terms',
)
class TermsModule {
  static void register() {
    final registry = ModuleRegistry.instance;
    
    registry.registerModule(
      name: 'TermsModule',
      persistenceType: PersistenceType.direct,
      initializer: () async {
        // Registro do repositório
        registry.registerProvider<TermsRepository>(
          TermsRepositoryImpl(),
        );
        
        return true;
      },
    );
  }
}

// Providers globais do módulo
final termsRepositoryProvider = Provider<TermsRepository>((ref) {
  return TermsRepositoryImpl();
});
