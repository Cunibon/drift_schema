import 'package:drift/drift.dart';
import 'package:drift_schema/custom_db.dart';

final Map<String, DriftSqlType> _typeLookup = {
  "boolean": DriftSqlType.bool,
  "integer": DriftSqlType.int,
  "number": DriftSqlType.double,
  "string": DriftSqlType.string,
  "date-time": DriftSqlType.dateTime,
  "blob": DriftSqlType.blob,
};

class SchemaTable {
  SchemaTable({
    required this.tableName,
    required this.schemaTables,
    required Map<String, dynamic> schema,
  }) : columns = [
          GeneratedColumn(
            "id",
            tableName,
            false,
            type: DriftSqlType.int,
            hasAutoIncrement: true,
          ),
        ] {
    build(schema);

    String columnNames = "";
    String insertPlaceholder = "";

    for (int i = 0; i < columns.length; i++) {
      columnNames += columns[i].name;
      insertPlaceholder += "?${i + 1}";

      if (i != columns.length - 1) {
        columnNames += ", ";
        insertPlaceholder += ", ";
      }
    }

    insertQuery =
        'INSERT INTO $tableName ($columnNames) VALUES ($insertPlaceholder)';
  }

  final String tableName;
  final List<GeneratedColumn> columns;
  final Map<String, SchemaTable> schemaTables;

  String insertQuery = "";
  final Map<String, String> references = {};

  void build(Map<String, dynamic> data) {
    if (data["properties"] != null) {
      schemaBasedColumns(schema: data);
    } else {
      propertiesBasedColumns(properties: data);
    }
  }

  void schemaBasedColumns({
    required Map<String, dynamic> schema,
  }) {
    final properties = schema["properties"] as Map<String, dynamic>;
    final requiredProperties = schema["required"] as List<dynamic>?;

    propertiesBasedColumns(
      properties: properties,
      requiredProperties: requiredProperties,
    );
  }

  void propertiesBasedColumns({
    required Map<String, dynamic> properties,
    List<dynamic>? requiredProperties,
  }) {
    properties.forEach((key, value) {
      final allOf = key == "allOf" ? value as List<dynamic>? : null;

      if (allOf != null) {
        //TODO: This implementation is flawed as it disregards the schema level
        for (int i = 0; i < allOf.length; i++) {
          build(allOf[i]);
        }
      } else {
        final ref = value["\$ref"];

        final type =
            ref != null ? DriftSqlType.int : _typeLookup[value["type"]]!;

        columns.add(
          GeneratedColumn(
            key,
            tableName,
            !(requiredProperties?.contains(key) ?? false),
            type: type,
            defaultConstraints: (genContext) {
              if (ref != null) {
                references[key] = ref;
                genContext.buffer.write(' REFERENCES $ref(id)');
              }
            },
          ),
        );
      }
    });
  }

  Future<int> insertData({
    required Map<String, dynamic> featureData,
    required CustomDb db,
  }) async {
    for (final entry in references.entries) {
      final key = entry.key;
      final value = entry.value;

      final refData = featureData[key];
      if (refData != null) {
        final rowId = await schemaTables[value]!.insertData(
          featureData: refData,
          db: db,
        );

        featureData[key] = rowId;
      }
    }

    final List<Variable> variables = [];

    for (var element in featureData.values) {
      variables.add(Variable(element));
    }

    return db.customInsert(
      insertQuery,
      variables: [
        const Variable(1),
        ...variables,
      ],
    );
  }

  Future<Map<String, dynamic>> queryDataForIndex({
    required int rowIndex,
    required CustomDb db,
  }) async {
    final featureData = (await db
            .customSelect("Select * from $tableName where id = $rowIndex")
            .get())
        .first
        .data;

    for (final entry in references.entries) {
      final key = entry.key;
      final value = entry.value;

      final refIndex = featureData[key];
      if (refIndex != null) {
        final refData = await schemaTables[value]!.queryDataForIndex(
          rowIndex: refIndex,
          db: db,
        );

        featureData[key] = refData;
      }
    }

    return featureData;
  }
}
