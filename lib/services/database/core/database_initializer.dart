import 'package:sqflite/sqflite.dart';

import 'schema_version_store.dart';
import 'table_schema.dart';

/// Coordinates database-wide initialization and per-table migrations.
class DatabaseInitializer {
  DatabaseInitializer(this._schemas);

  final List<TableSchema> _schemas;
  final SchemaVersionStore _versionStore = const SchemaVersionStore();

  Future<void> initialize(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await _versionStore.ensureTable(db);

    for (final schema in _schemas) {
      await schema.onConfigure(db);
      await _applyMigrations(db, schema);
    }
  }

  Future<void> _applyMigrations(Database db, TableSchema schema) async {
    if (schema.migrations.isEmpty) {
      return;
    }

    // Sort to guarantee execution order regardless of declaration.
    final ordered = [...schema.migrations]
      ..sort((a, b) => a.version.compareTo(b.version));

    await db.transaction((txn) async {
      final currentVersion = await _versionStore.readVersion(
        txn,
        schema.tableName,
      );

      for (final step in ordered) {
        if (step.version <= currentVersion) {
          continue;
        }

        await step.runner(txn);
        await _versionStore.writeVersion(txn, schema.tableName, step.version);
      }
    });
  }
}
