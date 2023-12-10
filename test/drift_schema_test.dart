import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_db.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test custom Db creation', () async {
    final table = CustomTable(
      [
        GeneratedColumn(
          'id',
          'foo',
          false,
          type: DriftSqlType.int,
          hasAutoIncrement: true,
        ),
      ],
      null,
      'foo',
    );

    final db = CustomDb(NativeDatabase.memory(logStatements: true), [table]);
    table.attachedDatabase = db;

    final migrator = Migrator(db);
    await migrator.createTable(table);
  });

  test('Test custom DB creation based on schema', () async {
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

    expect(schemaDb.db.allTables.length, 2);
    expect(schemaDb.db.allTables[0].$columns.length, 7);
    expect(schemaDb.db.allTables[1].$columns.length, 4);

    final String featureString = await rootBundle.loadString(
      'assets/test_json/feature.json',
    );

    final feature = jsonDecode(featureString) as Map<String, dynamic>;

    final index = await schemaDb.insertData(
      featureData: Map.fromEntries(feature.entries),
      schemaName: jsonLookup.keys.first,
    );

    final queriedFeature = await schemaDb.queryDataForIndex(
      rowIndex: index,
      schemaName: jsonLookup.keys.first,
    );

    queriedFeature.remove("id");
    queriedFeature["reference"].remove("id");

    expect(queriedFeature, feature);
  });
}
