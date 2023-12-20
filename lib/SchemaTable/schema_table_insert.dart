import 'package:drift/drift.dart';
import 'package:drift_schema/SchemaTable/schema_table.dart';

extension InsertTable on SchemaTable {
  ///Inserts the given data
  ///References will be inserted to their corresponding table and replaced with the corresponding Id
  ///
  ///Returns the rowId of the first effected row
  Future<int> insertData({
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

    late int rowId;

    for (int i = 0; i < variables.length; i++) {
      final int row = await schemaDb.db.customInsert(
        'INSERT INTO $tableName ($queryColumnNames) VALUES ($queryInsertPlaceholder)',
        variables: variables[i],
      );
      if (i == 0) {
        rowId = row;
      }
    }

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

      if (data != null) {
        for (final entry in data.entries) {
          final List<Map<String, dynamic>?> parsedRefData = [];
          parseData(entry.value, parsedRefData);
          await schemaDb.schemaTables[references[entry.key]]!
              .insertData(featureDatas: parsedRefData);
        }
      }
    }

    return rowId;
  }
}
