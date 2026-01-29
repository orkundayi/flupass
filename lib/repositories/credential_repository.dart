import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/credential.dart';
import '../services/app_database.dart';
import '../services/encryption_service.dart';

class CredentialRepository {
  CredentialRepository(this._database, this._encryptionService);

  final AppDatabase _database;
  final EncryptionService _encryptionService;

  Future<List<Credential>> fetchAll() async {
    final db = await _database.database;
    final maps = await db.query(
      Credential.tableName,
      orderBy: 'updated_at DESC',
    );
    return _decryptCredentialRows(maps, db);
  }

  Future<List<Credential>> search(String query) async {
    final db = await _database.database;
    final maps = await db.query(
      Credential.tableName,
      orderBy: 'updated_at DESC',
    );
    final credentials = await _decryptCredentialRows(maps, db);
    final keyword = query.toLowerCase().trim();
    if (keyword.isEmpty) {
      return credentials;
    }
    return credentials.where((credential) {
      final title = credential.title.toLowerCase();
      final username = credential.username.toLowerCase();
      final website = (credential.website ?? '').toLowerCase();
      return title.contains(keyword) ||
          username.contains(keyword) ||
          website.contains(keyword);
    }).toList();
  }

  Future<int> insert(Credential credential) async {
    final db = await _database.database;
    return db.insert(
      Credential.tableName,
      _encryptCredential(credential).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Credential credential) async {
    if (credential.id == null) {
      throw ArgumentError('Cannot update a credential without an id');
    }
    final db = await _database.database;
    return db.update(
      Credential.tableName,
      _encryptCredential(credential).toMap(),
      where: 'id = ?',
      whereArgs: [credential.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return db.delete(Credential.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> bulkInsert(List<Credential> credentials) async {
    if (credentials.isEmpty) {
      return 0;
    }

    final db = await _database.database;
    return db.transaction((txn) async {
      final batch = txn.batch();
      for (final credential in credentials) {
        batch.insert(
          Credential.tableName,
          _encryptCredential(credential).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      final results = await batch.commit(noResult: false);
      var inserted = 0;
      for (final result in results) {
        if (result is int && result > 0) {
          inserted++;
        }
      }
      return inserted;
    });
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final db = await _database.database;
    await db.update(
      Credential.tableName,
      {
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Credential _encryptCredential(Credential credential) {
    final encryptedPassword = _encryptionService.encrypt(credential.password);
    final encryptedUsername = _encryptionService.encrypt(credential.username);
    final encryptedNotes = credential.notes == null
        ? null
        : _encryptionService.encrypt(credential.notes!);
    final encryptedWebsite = credential.website == null
        ? null
        : _encryptionService.encrypt(credential.website!);
    return credential.copyWith(
      password: encryptedPassword,
      username: encryptedUsername,
      notes: encryptedNotes,
      website: encryptedWebsite,
    );
  }

  Credential _mapEncryptedCredential(Map<String, dynamic> map) {
    final raw = Credential.fromMap(map);
    final decryptedPassword = _encryptionService.decrypt(raw.password);
    final decryptedUsername = _encryptionService.decrypt(raw.username);
    final decryptedNotes = raw.notes == null
        ? null
        : _encryptionService.decrypt(raw.notes!);
    final decryptedWebsite = raw.website == null
        ? null
        : _encryptionService.decrypt(raw.website!);
    return raw.copyWith(
      password: decryptedPassword,
      username: decryptedUsername,
      notes: decryptedNotes,
      website: decryptedWebsite,
    );
  }

  Future<List<Credential>> _decryptCredentialRows(
    List<Map<String, dynamic>> rows,
    DatabaseExecutor db,
  ) async {
    final credentials = <Credential>[];
    for (final row in rows) {
      await _ensureCredentialEncrypted(db, row);
      credentials.add(_mapEncryptedCredential(row));
    }
    return credentials;
  }

  Future<void> _ensureCredentialEncrypted(
    DatabaseExecutor db,
    Map<String, dynamic> row,
  ) async {
    final password = row['password'] as String?;
    final username = row['username'] as String?;
    final website = row['website'] as String?;
    final notes = row['notes'] as String?;

    final needsMigration = [password, username, website, notes].any((value) {
      if (value == null || value.isEmpty) {
        return false;
      }
      return !_encryptionService.isCipherText(value);
    });

    if (!needsMigration) {
      return;
    }

    try {
      final legacy = Credential.fromMap(row);
      final encrypted = _encryptCredential(legacy);
      if (legacy.id == null) {
        return;
      }
      await db.update(
        Credential.tableName,
        encrypted.toMap(),
        where: 'id = ?',
        whereArgs: [legacy.id],
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Credential encryption migration failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }
}
