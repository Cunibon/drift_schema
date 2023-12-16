import 'package:drift/drift.dart';
import 'package:drift_schema/schema_table.dart';

const Map<String, DriftSqlType> _typeLookup = {
  "boolean": DriftSqlType.bool,
  "integer": DriftSqlType.int,
  "number": DriftSqlType.double,
  "string": DriftSqlType.string,
  "date-time": DriftSqlType.dateTime,
  "blob": DriftSqlType.blob,
};

extension CreateTable on SchemaTable {
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
        String? ref = value["\$ref"];
        final type = value["type"];
        late DriftSqlType sqlType;

        if (type == "array") {
          final arrayTableName = "$tableName$type";
          ref = arrayTableName;

          final schemaTable = SchemaTable(
            tableName: arrayTableName,
            schema: (value as Map<String, dynamic>)..remove("type"),
            schemaDb: schemaDb,
          );
          schemaDb.addSchemaTable(
            schemaTable,
          );
        }

        if (ref != null) {
          references[key] = ref;
          sqlType = DriftSqlType.int;
        } else {
          sqlType = _typeLookup[type]!;
        }

        columns.add(
          GeneratedColumn(
            key,
            tableName,
            !(requiredProperties?.contains(key) == true),
            type: sqlType,
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
