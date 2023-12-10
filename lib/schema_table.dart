import 'package:drift/drift.dart';

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
    required this.tables,
    required this.tableName,
    required this.data,
  }) : columns = [
          GeneratedColumn(
            "id",
            tableName,
            false,
            type: DriftSqlType.int,
            hasAutoIncrement: true,
          ),
        ];

  final List<SchemaTable> tables;

  final String tableName;
  final Map<String, dynamic> data;
  final List<GeneratedColumn> columns;

  void init() {
    if (data["properties"] != null) {
      schemaBasedColumns(data);
    } else {
      propertiesBasedColumns(properties: data);
    }
  }

  void schemaBasedColumns(
    Map<String, dynamic> schema,
  ) {
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
      final ref = value["\$ref"];
      final allOf = value["allOf"] as List<dynamic>?;

      if (allOf != null) {
        for (int i = 0; i < allOf.length; i++) {
          tables.add(
            SchemaTable(
              tableName: "$tableName $key[$i]",
              tables: tables,
              data: allOf[i],
            )..init(),
          );
        }
      } else {
        columns.add(
          GeneratedColumn(
            key,
            tableName,
            !(requiredProperties?.contains(key) ?? false),
            type: _typeLookup[value["type"]]!,
            defaultConstraints: (genContext) {
              if (ref != null) {
                genContext.buffer.write(' REFERENCES $ref(id)');
              }
            },
          ),
        );
      }
    });
  }
}
