import 'package:sqflite/sqflite.dart';

import '../core/migration_step.dart';
import '../core/table_schema.dart';

class CredentialSchema extends TableSchema {
  const CredentialSchema();

  @override
  String get tableName => 'credentials';

  @override
  List<MigrationStep> get migrations => const [MigrationStep(1, _createV1)];

  static Future<void> _createV1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credentials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        website TEXT,
        notes TEXT,
        tags TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
