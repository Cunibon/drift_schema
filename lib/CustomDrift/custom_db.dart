import 'package:drift/drift.dart';

class CustomDb extends GeneratedDatabase {
  CustomDb(super.e, this.allTables);

  @override
  final List<TableInfo> allTables;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) async {/* do nothing*/});

  @override
  int get schemaVersion => 1;
}
