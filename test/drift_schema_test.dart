import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_schema/custom_db.dart';
import 'package:drift_schema/custom_table.dart';
import 'package:drift_schema/schema_db_creator.dart';
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

    final dbCreator = SchemaDbCreator(jsonLookup);

    final db = await dbCreator.init();

    expect(db.allTables.length, 2);
    expect(db.allTables.first.$columns.length, 3);
    expect(db.allTables.last.$columns.length, 3);
  });
}
