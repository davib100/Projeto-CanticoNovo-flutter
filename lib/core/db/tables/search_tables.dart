import 'package:drift/drift.dart';

@DataClassName('SearchHistoryRecord')
class SearchHistoryTable extends Table {
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {query};
}
