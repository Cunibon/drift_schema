import 'package:drift/drift.dart';
import 'package:drift_schema/SchemaTable/schema_table.dart';

extension QueryTable on SchemaTable {
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
