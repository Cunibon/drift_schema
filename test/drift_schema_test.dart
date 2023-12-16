import 'dart:convert';

import 'package:drift_schema/schema_db.dart';
import 'package:drift_schema/schema_table.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<SchemaDb> setUpTestDb() async {
    WidgetsFlutterBinding.ensureInitialized();

    final String test1String = await rootBundle.loadString(
      'assets/test_json/test1.json',
    );
    final String test2String = await rootBundle.loadString(
      'assets/test_json/test2.json',
    );

    final test1Data = jsonDecode(test1String);
    final test2Data = jsonDecode(test2String);

    final jsonLookup = {
      "test1": test1Data,
      "test2": test2Data,
    };

    final schemaDb = SchemaDb(jsonLookup);

    await schemaDb.init();

    return schemaDb;
  }

  test('Test custom DB creation based on schema', () async {
    final schemaDb = await setUpTestDb();

    expect(schemaDb.db.allTables.length, 2);
    expect(schemaDb.db.allTables[0].$columns.length, 7);
    expect(schemaDb.db.allTables[1].$columns.length, 4);
  });

  test('Test insert and query data from SchemaDB', () async {
    final schemaDb = await setUpTestDb();

    final String featureString = await rootBundle.loadString(
      'assets/test_json/feature.json',
    );

    final feature = jsonDecode(featureString) as Map<String, dynamic>;

    final indexs = await schemaDb.insertData(
      featureDatas: [Map.fromEntries(feature.entries)],
      schemaName: "test1",
    );

    final queriedFeature = await schemaDb.queryDataForIndex(
      rowIndex: indexs.firstOrNull!,
      schemaName: "test1",
    );

    expect(queriedFeature, feature);

    final bigQuery = await schemaDb.db
        .customSelect(
          "Select * from test1 o left join test2 t on o.reference = t.$dataId",
        )
        .get();

    expect(bigQuery.first.data.length, 13);
  });
}
