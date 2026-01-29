import 'package:sqflite/sqflite.dart';

import '../core/migration_step.dart';
import '../core/table_schema.dart';

class CreditCardSchema extends TableSchema {
  const CreditCardSchema();

  @override
  String get tableName => 'credit_cards';

  @override
  List<MigrationStep> get migrations => const [MigrationStep(1, _createV1)];

  static Future<void> _createV1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_holder_name TEXT NOT NULL,
        card_number TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        cvv TEXT NOT NULL,
        display_name TEXT
      )
    ''');
  }
}
