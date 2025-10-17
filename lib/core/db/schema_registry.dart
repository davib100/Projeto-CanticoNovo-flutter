// core/db/schema_registry.dart
import 'package:drift/drift.dart';

class SchemaRegistry {
  static final Map<String, TableInfo> _tables = {};
  static final Map<String, ViewInfo> _views = {};
  static final Map<String, Index> _indexes = {};

  /// Registra uma tabela no schema
  static void registerTable(TableInfo table) {
    _tables[table.actualTableName] = table;
  }

  /// Registra uma view no schema
  static void registerView(ViewInfo view) {
    _views[view.entityName] = view;
  }

  /// Registra um índice no schema
  static void registerIndex(String name, Index index) {
    _indexes[name] = index;
  }

  /// Obtém todas as tabelas registradas
  static List<TableInfo> getAllTables() {
    return _tables.values.toList();
  }

  /// Obtém todas as views registradas
  static List<ViewInfo> getAllViews() {
    return _views.values.toList();
  }

  /// Obtém todos os índices registrados
  static Map<String, Index> getAllIndexes() {
    return Map.unmodifiable(_indexes);
  }

  /// Obtém uma tabela pelo nome
  static TableInfo? getTable(String tableName) {
    return _tables[tableName];
  }

  /// Obtém uma view pelo nome
  static ViewInfo? getView(String viewName) {
    return _views[viewName];
  }

  /// Valida a integridade do schema
  static SchemaValidationResult validateSchema() {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar tabelas
    for (final table in _tables.values) {
      if (table.primaryKey.isEmpty) {
        errors.add('Table ${table.actualTableName} has no primary key');
      }

      // Validar colunas
      for (final column in table.$columns) {
        if (column.name.isEmpty) {
          errors.add('Table ${table.actualTableName} has column with empty name');
        }
      }
    }

    // Validar views
    for (final view in _views.values) {
      if (view.$columns.isEmpty) {
        warnings.add('View ${view.entityName} has no columns defined');
      }
    }

    return SchemaValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /*
  // TODO: This DDL generation logic is commented out because it relies on Drift's internal APIs
  // which are not guaranteed to be stable. Manually generating DDL is brittle and error-prone.
  // The recommended approach is to rely on Drift's built-in migration system 
  // (see `migration_manager.dart`) to handle all schema creation and evolution.

  /// Gera DDL SQL para todas as tabelas
  static String generateDDL(GeneratedDatabase db) {
    final buffer = StringBuffer();
    // final generationContext = GenerationContext(db.options, db);

    // Gerar CREATE TABLE statements
    for (final table in _tables.values) {
      buffer.writeln('-- Table: ${table.actualTableName}');
      // buffer.writeln(_generateTableDDL(table, generationContext));
      buffer.writeln();
    }
    
    // Gerar CREATE INDEX statements
    for (final entry in _indexes.entries) {
      buffer.writeln('-- Index: ${entry.key}');
      buffer.writeln(_generateIndexDDL(entry.key, entry.value));
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  static String _generateTableDDL(TableInfo table, dynamic context) { // Using dynamic to avoid compile error
    final columns = table.$columns.map((col) {
      final nullable = col.requiredDuringInsert ? 'NOT NULL' : 'NULL';
      // The following line is the root of the problem, as sqlTypeName requires a context
      // that is not publicly exposed in a stable way.
      // return '  ${col.name} ${col.type.sqlTypeName(context)} $nullable';
    }).join(',\n');
    
    final pk = table.primaryKey.isNotEmpty
      ? ',\n  PRIMARY KEY (${table.primaryKey.map((c) => c.name).join(', ')})'
      : '';
    
    return 'CREATE TABLE ${table.actualTableName} (\n$columns$pk\n);';
  }

  static String _generateIndexDDL(String name, Index index) {
    return 'CREATE INDEX $name ON ${index.table} (${index.columns.join(', ')});';
  }
  */

  /// Limpa todos os registros (útil para testes)
  static void clear() {
    _tables.clear();
    _views.clear();
    _indexes.clear();
  }
}

/// Resultado da validação do schema
class SchemaValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  SchemaValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Schema Validation: ${isValid ? "PASSED" : "FAILED"}');

    if (errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (final error in errors) {
        buffer.writeln('  ❌ $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  ⚠️  $warning');
      }
    }

    return buffer.toString();
  }
}

/// Definição de índice
class Index {
  final String table;
  final List<String> columns;
  final bool unique;

  Index({
    required this.table,
    required this.columns,
    this.unique = false,
  });
}
