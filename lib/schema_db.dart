import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_table.dart';

class SchemaDb {
  SchemaDb(this.schemas);

  final Map<String, dynamic> schemas;
  final Map<String, SchemaTable> schemaTables = {};
  final List<CustomTable> driftTables = [];

  late CustomDb db;
  late Migrator migrator;

  void addSchemaTable(SchemaTable schemaTable, String tableName) {
    schemaTables[tableName] = schemaTable;
    driftTables.add(schemaTable.driftTable);
  }

  Future<CustomDb> init() async {
    schemas.forEach((key, value) {
      final schemaTable = SchemaTable(
        tableName: key,
        schema: value,
        schemaDb: this,
      );
      addSchemaTable(
        schemaTable,
        key,
      );
    });

    db = CustomDb(
      NativeDatabase.memory(logStatements: true),
      driftTables,
    );

    migrator = Migrator(db);

    for (final table in driftTables) {
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
    );
  }

  Future<Map<String, dynamic>?> queryDataForIndex({
    required int rowIndex,
    required String schemaName,
  }) async {
    return schemaTables[schemaName]!.queryDataForIndex(
      rowIndex: rowIndex,
    );
  }
}
