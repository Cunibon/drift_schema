import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';

class SchemaDbCreator {
  final Map<String, DriftSqlType> _typeLookup = {
    "boolean": DriftSqlType.bool,
    "integer": DriftSqlType.int,
    "number": DriftSqlType.double,
    "string": DriftSqlType.string,
    "date-time": DriftSqlType.dateTime,
    "blob": DriftSqlType.blob,
  };

  late CustomDb db;

  Future<CustomDb> schemaBasedDb(
    Map<String, dynamic> schemas,
  ) async {
    final List<CustomTable> tables = [];

    schemas.forEach((key, value) async {
      final schema = value["schema"];
      final properties = schema["properties"] as Map<String, dynamic>;

      final requiredProperties = schema["required"] as List<String>;

      final List<GeneratedColumn> columns = [];

      properties.forEach((key, value) {
        final ref = value["\$ref"];
        ColumnBuilder().nullable();

        columns.add(
          GeneratedColumn(
            key,
            key,
            !requiredProperties.contains(key),
            type: _typeLookup[value["type"]]!,
            hasAutoIncrement: true,
            $customConstraints: 'REFERENCES categories(id)',
          ),
        );
      });

      final table = CustomTable(
        columns,
        null,
        key,
      );

      tables.add(table);
    });

    db = CustomDb(
      NativeDatabase.memory(logStatements: true),
      tables,
    );
    final migrator = Migrator(db);

    for (final table in tables) {
      table.attachedDatabase = db;
      await migrator.createTable(table);
    }

    return db;
  }
}
