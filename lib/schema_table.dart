import 'package:drift/drift.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_db.dart';
import 'package:drift_schema/schema_table_creation.dart';

const String dataId = "_dataId";
const String foreignSchema = "_foreignSchema";
const String foreignDataId = "_foreignDataId";

const List<String> addedSchemaColumns = [
  dataId,
  foreignSchema,
  foreignDataId,
];

class SchemaTable {
  SchemaTable({
    required this.tableName,
    required this.schemaDb,
    required this.schema,
    Set<GeneratedColumn>? overridePrimaryKey,
  }) : columns = [
          GeneratedColumn(
            dataId,
            tableName,
            true,
            type: DriftSqlType.int,
          ),
          GeneratedColumn(
            foreignSchema,
            tableName,
            true,
            type: DriftSqlType.string,
          ),
          GeneratedColumn(
            foreignDataId,
            tableName,
            true,
            type: DriftSqlType.int,
          ),
        ] {
    build(schema);

    queryColumnNames = "";
    queryInsertPlaceholder = "";

    final columnNames = columns.map((e) => e.name).toList();
    columnNames.removeWhere((element) => references.containsKey(element));

    for (int i = 0; i < columnNames.length; i++) {
      final columnName = columnNames[i];

      queryColumnNames += columnName;
      queryInsertPlaceholder += "?${i + 1}";

      if (i != columnNames.length - 1) {
        queryColumnNames += ", ";
        queryInsertPlaceholder += ", ";
      }
    }

    driftTable = CustomTable(
      $columns: columns,
      actualTableName: tableName,
      overridePrimaryKey: overridePrimaryKey ?? {columns.first},
    );
  }

  final String tableName;
  final SchemaDb schemaDb;
  final Map<String, dynamic> schema;
  final Map<String, String> references = {};

  late CustomTable driftTable;

  final List<GeneratedColumn> columns;
  String queryColumnNames = "";
  String queryInsertPlaceholder = "";
}
