import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../services/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  static const _themeModeKey = 'theme_mode';

  Future<ThemeMode?> loadThemeMode() async {
    final db = await _database.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: const [_themeModeKey],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final value = result.first['value'] as String?;
    if (value == null) {
      return null;
    }

    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final db = await _database.database;
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };

    await db.insert('settings', {
      'key': _themeModeKey,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
