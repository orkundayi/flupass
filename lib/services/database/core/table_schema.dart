import 'package:sqflite/sqflite.dart';

import 'migration_step.dart';

/// Defines the contract for table-specific schema management.
abstract class TableSchema {
  const TableSchema();

  /// Name of the table managed by this schema.
  String get tableName;

  /// Ordered migration steps required to build and evolve the table.
  List<MigrationStep> get migrations;

  /// Optional hook for table-specific configuration.
  Future<void> onConfigure(Database db) async {}
}
