import 'package:drift_schema/SchemaTable/schema_table.dart';
import 'package:drift_schema/schema_db.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> test1Json = {
  "type": "object",
  "properties": {
    "string": {"type": "string"},
    "number": {"type": "number"},
    "reference": {"\$ref": "test2", "type": "string"},
    "arrayProperty": {
      "type": "array",
      "items": {"type": "string"}
    },
    "allOf": [
      {
        "allOfString1": {"type": "string"}
      },
      {
        "allOfString2": {"type": "string"},
        "allOfNumber": {"type": "number"}
      }
    ]
  }
};

Map<String, dynamic> test2Json = {
  "type": "object",
  "properties": {
    "string2": {"type": "string"},
    "number2": {"type": "number"},
    "dateTime": {"type": "date-time"}
  }
};

Map<String, dynamic> feature = {
  "string": "Hello, World!",
  "number": 42,
  "reference": {
    "string2": "Another string value",
    "number2": 123,
    "dateTime": "2023-12-10T08:30:00Z"
  },
  "arrayProperty": ["so", "many", "strings"],
  "allOfString1": "This is a string",
  "allOfString2": "Another string",
  "allOfNumber": 3.14
};

void main() {
  Future<SchemaDb> setUpTestDb() async {
    final jsonLookup = {
      "test1": test1Json,
      "test2": test2Json,
    };

    final schemaDb = SchemaDb(jsonLookup);

    await schemaDb.init();

    return schemaDb;
  }

  test('Test: custom DB creation based on schema', () async {
    final schemaDb = await setUpTestDb();

    expect(schemaDb.db.allTables.length, 2);
    expect(schemaDb.db.allTables[0].$columns.length, 7);
    expect(schemaDb.db.allTables[1].$columns.length, 4);
  });

  test('Test: insert and query data from SchemaDB', () async {
    final schemaDb = await setUpTestDb();

    final index = await schemaDb.insertData(
      featureDatas: [Map.from(feature)],
      schemaName: "test1",
    );

    final queriedFeature = await schemaDb.queryDataForIndex(
      rowIndex: index,
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

  test('Test: transaction data safety', () async {
    test1Json["fakeRef"] = {"\$ref": "fake", "type": "string"};

    final jsonLookup = {
      "test1": test1Json,
      "test2": test2Json,
    };

    final schemaDb = SchemaDb(jsonLookup);

    await schemaDb.init();

    feature["fakeRef"] = {"string": "Should not make it to database"};

    await schemaDb.insertData(
      featureDatas: [Map.from(feature)],
      schemaName: "test1",
    );

    final query = await schemaDb.db
        .customSelect(
          "Select * from test1 o left join test2 t on o.reference = t.$dataId",
        )
        .get();

    expect(query.isEmpty, true);
  });
}
