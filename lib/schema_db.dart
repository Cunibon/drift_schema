import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_table.dart';

class SchemaDb {
  SchemaDb(this.schemas);

  final Map<String, dynamic> schemas;
  Map<String, SchemaTable> schemaTables = {};
  Map<String, CustomTable> driftTables = {};

  late CustomDb db;

  Future<CustomDb> init() async {
    schemas.forEach((key, value) {
      schemaTables[key] = SchemaTable(
        tableName: key,
        schema: value,
        schemaTables: schemaTables,
      );
    });

    driftTables = schemaTables.map(
      (key, schemaTable) => MapEntry(
        key,
        CustomTable(
          schemaTable.columns,
          null,
          schemaTable.tableName,
        ),
      ),
    );

    db = CustomDb(
      NativeDatabase.memory(logStatements: true),
      driftTables.values.toList(),
    );
    final migrator = Migrator(db);

    for (final table in driftTables.values) {
      table.attachedDatabase = db;
      await migrator.createTable(table);
    }

    return db;
  }

  Future<int> insertData({
    required Map<String, dynamic> featureData,
    required String schemaName,
  }) async {
    return schemaTables[schemaName]!.insertData(
      featureData: featureData,
      db: db,
    );
  }

  Future<Map<String, dynamic>> queryDataForIndex({
    required int rowIndex,
    required String schemaName,
  }) async {
    return schemaTables[schemaName]!.queryDataForIndex(
      rowIndex: rowIndex,
      db: db,
    );
  }
}
