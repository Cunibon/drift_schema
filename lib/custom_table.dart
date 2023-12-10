import 'package:drift/drift.dart';

class CustomTable extends Table with TableInfo {
  @override
  final List<GeneratedColumn> $columns;

  final String? alias;

  @override
  final String actualTableName;

  @override
  late final GeneratedDatabase attachedDatabase;

  CustomTable(
    this.$columns,
    this.alias,
    this.actualTableName,
  );

  @override
  Table get asDslTable => this;

  @override
  CustomTable createAlias(String alias) {
    return CustomTable($columns, alias, actualTableName)
      ..attachedDatabase = attachedDatabase;
  }

  @override
  DataClass map(Map<String, dynamic> data, {String? tablePrefix}) {
    // drift uses this for selects
    throw 'todo';
  }
}
