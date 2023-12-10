import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_table.dart';

class SchemaDbCreator {
  SchemaDbCreator(this.schemas);

  final Map<String, dynamic> schemas;
  final List<SchemaTable> tables = [];

  late CustomDb db;

  Future<CustomDb> init() async {
    schemas.forEach((key, value) async {
      tables.add(
        SchemaTable(
          tableName: key,
          tables: tables,
          data: value,
        )..init(),
      );
    });

    final driftTables = tables
        .map((schemaTable) => CustomTable(
              schemaTable.columns,
              null,
              schemaTable.tableName,
            ))
        .toList();

    db = CustomDb(
      NativeDatabase.memory(logStatements: true),
      driftTables,
    );
    final migrator = Migrator(db);

    for (final table in driftTables) {
      table.attachedDatabase = db;
      await migrator.createTable(table);
    }

    return db;
  }
}
