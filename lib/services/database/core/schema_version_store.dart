import 'package:sqflite/sqflite.dart';

/// Persists per-table schema versions inside the main database.
class SchemaVersionStore {
  const SchemaVersionStore();

  static const String tableName = '_schema_versions';

  Future<void> ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        table_name TEXT PRIMARY KEY,
        version INTEGER NOT NULL
      )
    ''');
  }

  Future<int> readVersion(DatabaseExecutor executor, String table) async {
    final result = await executor.rawQuery(
      'SELECT version FROM $tableName WHERE table_name = ? LIMIT 1',
      [table],
    );

    if (result.isEmpty) {
      return 0;
    }

    final value = result.first['version'];
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  Future<void> writeVersion(
    DatabaseExecutor executor,
    String table,
    int version,
  ) async {
    await executor.rawInsert(
      'INSERT OR REPLACE INTO $tableName (table_name, version) VALUES (?, ?)',
      [table, version],
    );
  }
}
