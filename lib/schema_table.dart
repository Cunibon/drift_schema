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

  ///Inserts the given data
  ///References will be inserted to their corresponding table and replaced with the corresponding Id
  ///
  ///Returns the rowId of the first effected row
  Future<List<int?>> insertData({
    required List<Map<String, dynamic>?> featureDatas,
  }) async {
    final cleanFeatureDatas = featureDatas.nonNulls.toList();

    final List<List<Variable>> variables = [];
    final Map<int, Map<String, dynamic>> refData = {};

    for (int i = 0; i < cleanFeatureDatas.length; i++) {
      final featureData = cleanFeatureDatas[i];
      for (final entry in references.entries) {
        refData.putIfAbsent(i, () => {})[entry.key] = featureData[entry.key];

        featureData.remove(entry.key);
      }

      final schemaColumns =
          addedSchemaColumns.map((e) => featureData.remove(e));

      final List<Variable> currentVariables = [];

      currentVariables.addAll([
        ...schemaColumns.map((e) => Variable(e)),
        ...featureData.values.map((e) => Variable(e)),
      ]);

      variables.add(currentVariables);
    }

    int rowId = await () async {
      late int firstInsert;
      for (int i = 0; i < variables.length; i++) {
        final int row = await schemaDb.db.customInsert(
          'INSERT INTO $tableName ($queryColumnNames) VALUES ($queryInsertPlaceholder)',
          variables: variables[i],
        );
        if (i == 0) {
          firstInsert = row;
        }
      }
      return firstInsert;
    }();

    for (int i = 0; i < cleanFeatureDatas.length; i++) {
      final data = refData[i];

      void parseData(
        dynamic element,
        List<Map<String, dynamic>?> parsedRefData,
      ) {
        if (element is List) {
          for (final element in element) {
            parseData(element, parsedRefData);
          }
        } else if (element is Map<String, dynamic>) {
          element[foreignSchema] = tableName;
          element[foreignDataId] = rowId + i;
          parsedRefData.add(element);
        } else {
          parseData({"items": element}, parsedRefData);
        }
      }

      data?.forEach((key, value) {
        final List<Map<String, dynamic>?> parsedRefData = [];
        parseData(value, parsedRefData);
        schemaDb.schemaTables[references[key]]!
            .insertData(featureDatas: parsedRefData);
      });
    }

    return List.generate(featureDatas.length, (index) {
      int? value;

      if (featureDatas[index] != null) {
        value = rowId;
        rowId++;
      }

      return value;
    });
  }

  ///Returns the expanded data for the feature at index
  Future<Map<String, dynamic>?> queryDataForIndex({
    required int rowIndex,
    bool removeSchemaColumns = true,
  }) async {
    final featureData = (await schemaDb.db.customSelect(
      "Select * from $tableName where $dataId = ?1",
      variables: [Variable(rowIndex)],
    ).get());

    if (featureData.isEmpty) {
      return null;
    }

    return expandData(
      featureData: featureData.first.data,
      removeSchemaColumns: removeSchemaColumns,
    );
  }

  ///Returns the feature with all its references filled in with the corresponding data
  Future<Map<String, dynamic>> expandData({
    required Map<String, dynamic> featureData,
    bool removeSchemaColumns = true,
  }) async {
    final currentDataId = featureData[dataId];

    for (final entry in references.entries) {
      final refData =
          await schemaDb.schemaTables[entry.value]!.queryDataForReference(
        fDataId: currentDataId,
        fSchema: tableName,
        removeSchemaColumns: removeSchemaColumns,
      );

      featureData[entry.key] = refData;
    }

    if (removeSchemaColumns) {
      featureData.removeWhere((key, value) => addedSchemaColumns.contains(key));
    }

    return featureData;
  }

  ///Returns the data for a given reference
  Future<dynamic> queryDataForReference({
    required int fDataId,
    required String fSchema,
    bool removeSchemaColumns = true,
  }) async {
    final featureData = (await schemaDb.db.customSelect(
      "Select * from $tableName where $foreignDataId = ?1 and $foreignSchema = ?2",
      variables: [
        Variable(fDataId),
        Variable(fSchema),
      ],
    ).get());

    if (featureData.isEmpty) {
      return null;
    } else if (featureData.length == 1) {
      return expandData(
        featureData: featureData.first.data,
        removeSchemaColumns: removeSchemaColumns,
      );
    } else {
      final futures = featureData
          .map((e) => expandData(
                featureData: e.data,
                removeSchemaColumns: removeSchemaColumns,
              ))
          .toList();

      return (await Future.wait(futures)).map((e) => e["items"]);
    }
  }
}
