import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_table.dart';

class SchemaDb {
  SchemaDb(this.schemas);

  final Map<String, dynamic> schemas;
  final Map<String, SchemaTable> schemaTables = {};

  late CustomDb db;
  late Migrator migrator;

  Future<CustomDb> init() async {
    final List<CustomTable> driftTables = [];
    schemas.forEach((key, value) {
      final schemaTable = SchemaTable(
        tableName: key,
        schema: value,
        schemaDb: this,
      );
      schemaTables[key] = schemaTable;
      driftTables.add(schemaTable.driftTable);
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
