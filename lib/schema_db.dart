import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/CustomDrift/custom_db.dart';
import 'package:drift_schema/CustomDrift/custom_table.dart';
import 'package:drift_schema/SchemaTable/schema_table.dart';
import 'package:drift_schema/SchemaTable/schema_table_insert.dart';
import 'package:drift_schema/SchemaTable/schema_table_query.dart';

class SchemaDb {
  SchemaDb(this.schemas);

  final Map<String, dynamic> schemas;
  final Map<String, SchemaTable> schemaTables = {};
  final List<CustomTable> driftTables = [];

  late CustomDb db;
  late Migrator migrator;

  void addSchemaTable(SchemaTable schemaTable) {
    schemaTables[schemaTable.tableName] = schemaTable;
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
    required List<Map<String, dynamic>> featureDatas,
    required String schemaName,
  }) async {
    try {
      return await db.transaction(
        () async => await schemaTables[schemaName]!.insertData(
          featureDatas: featureDatas,
        ),
      );
    } catch (e) {
      return 0;
    }
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
