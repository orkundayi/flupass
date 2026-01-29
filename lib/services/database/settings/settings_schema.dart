import 'package:sqflite/sqflite.dart';

import '../core/migration_step.dart';
import '../core/table_schema.dart';

class SettingsSchema extends TableSchema {
  const SettingsSchema();

  @override
  String get tableName => 'settings';

  @override
  List<MigrationStep> get migrations => const [MigrationStep(1, _createV1)];

  static Future<void> _createV1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
