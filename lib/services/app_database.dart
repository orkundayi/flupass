import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database/core/database_initializer.dart';
import 'database/credentials/credential_schema.dart';
import 'database/credit_cards/credit_card_schema.dart';
import 'database/settings/settings_schema.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseFileName = 'flupass.db';

  final DatabaseInitializer _initializer = DatabaseInitializer(const [
    CredentialSchema(),
    CreditCardSchema(),
    SettingsSchema(),
  ]);

  Database? _database;
  Completer<Database>? _openCompleter;

  Future<Database> get database => open();

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    if (_openCompleter != null) {
      return _openCompleter!.future;
    }

    final completer = Completer<Database>();
    _openCompleter = completer;

    try {
      final path = await _resolvePath();
      final db = await openDatabase(path);
      await _initializer.initialize(db);
      _database = db;
      completer.complete(db);
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      _openCompleter = null;
      rethrow;
    }

    return completer.future;
  }

  bool get isOpen => _database != null;

  Future<void> close() async {
    if (_database == null) {
      return;
    }

    await _database!.close();
    _database = null;
    _openCompleter = null;
  }

  Future<void> delete() async {
    final databasePath = await _resolvePath();
    await close();
    await deleteDatabase(databasePath);
  }

  Future<String> _resolvePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, _databaseFileName);
  }
}
