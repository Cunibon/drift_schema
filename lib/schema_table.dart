import 'package:drift/drift.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_db.dart';

const Map<String, DriftSqlType> _typeLookup = {
  "boolean": DriftSqlType.bool,
  "integer": DriftSqlType.int,
  "number": DriftSqlType.double,
  "string": DriftSqlType.string,
  "date-time": DriftSqlType.dateTime,
  "blob": DriftSqlType.blob,
};

const String schemaDataId = "_schemaDataId";

class SchemaTable {
  SchemaTable({
    required this.tableName,
    required this.schemaDb,
    required Map<String, dynamic> schema,
    Set<GeneratedColumn>? overridePrimaryKey,
  }) : columns = [
          GeneratedColumn(
            schemaDataId,
            tableName,
            true,
            type: DriftSqlType.int,
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

    driftTable = CustomTable(
      $columns: columns,
      actualTableName: tableName,
      overridePrimaryKey: overridePrimaryKey ?? {columns.first},
    );
  }

  final String tableName;
  final List<GeneratedColumn> columns;
  final SchemaDb schemaDb;

  late CustomTable driftTable;

  String insertQuery = "";
  final Map<String, String> references = {};
  final Map<String, String> arrays = {};

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
          arrays[key] = arrayTableName;

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

  ///Inserts the given data
  ///References will be inserted to their corresponding table and replaced with the corresponding Id
  ///
  ///Returns the rowId of the operation
  Future<int> insertData({
    required List<Map<String, dynamic>?> featureDatas,
  }) async {
    final List<Map<String, dynamic>?> refData = [];
    for (final featureData in featureDatas) {
      for (final entry in references.entries) {
        refData.add(featureData?[entry.key]);
      }
    }

    for (final entry in references.entries) {
      final rowId = await schemaDb.schemaTables[entry.value]!.insertData(
        featureDatas: refData,
      );

      for (int i = 0; i < featureDatas.length; i++) {
        featureDatas[i]?[entry.key] = rowId + i;
      }
    }

    return schemaDb.db.customInsert(
      insertQuery,
      variables: [
        const Variable(null),
        ...featureDatas.values.map((e) => Variable(e)),
      ],
    );
  }

  ///Returns the expanded data for the feature at index
  Future<Map<String, dynamic>?> queryDataForIndex({
    required int rowIndex,
    bool removeSchemaTableId = true,
  }) async {
    final featureData = (await schemaDb.db
        .customSelect(
          "Select * from $tableName where $schemaDataId = $rowIndex",
        )
        .get());

    if (featureData.isEmpty) {
      return null;
    }

    return expandData(
      featureData: featureData.first.data,
      removeSchemaTableId: removeSchemaTableId,
    );
  }

  ///Returns the feature with all its references filled in with the corresponding data
  Future<Map<String, dynamic>> expandData({
    required Map<String, dynamic> featureData,
    bool removeSchemaTableId = true,
  }) async {
    for (final entry in references.entries) {
      final refIndex = featureData[entry.key];
      if (refIndex != null) {
        final refData =
            await schemaDb.schemaTables[entry.value]!.queryDataForIndex(
          rowIndex: refIndex,
        );

        featureData[entry.key] = refData;
      }
    }

    if (removeSchemaTableId) {
      featureData.remove(schemaDataId);
    }

    return featureData;
  }
}
