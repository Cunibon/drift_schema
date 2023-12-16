import 'package:drift/drift.dart';

class CustomTable extends Table with TableInfo {
  @override
  final List<GeneratedColumn> $columns;

  final String? alias;

  @override
  final String actualTableName;

  final Set<GeneratedColumn>? overridePrimaryKey;

  @override
  Set<GeneratedColumn> get $primaryKey => overridePrimaryKey ?? {};

  @override
  late final GeneratedDatabase attachedDatabase;

  CustomTable({
    required this.$columns,
    required this.actualTableName,
    this.alias,
    this.overridePrimaryKey,
  });

  @override
  Table get asDslTable => this;

  @override
  CustomTable createAlias(String alias) {
    return CustomTable(
      $columns: $columns,
      alias: alias,
      actualTableName: actualTableName,
      overridePrimaryKey: overridePrimaryKey,
    )..attachedDatabase = attachedDatabase;
  }

  @override
  DataClass map(Map<String, dynamic> data, {String? tablePrefix}) {
    // drift uses this for selects
    throw 'todo';
  }
}
