import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/credit_card.dart';
import '../services/app_database.dart';
import '../services/encryption_service.dart';

class CreditCardRepository {
  CreditCardRepository(this._database, this._encryptionService);

  final AppDatabase _database;
  final EncryptionService _encryptionService;

  Future<List<CreditCard>> fetchAll() async {
    final db = await _database.database;
    final maps = await db.query(CreditCard.tableName, orderBy: 'id DESC');
    return _decryptCardRows(maps, db);
  }

  Future<int> insert(CreditCard card) async {
    final db = await _database.database;
    return db.insert(
      CreditCard.tableName,
      _encryptCard(card).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(CreditCard card) async {
    if (card.id == null) {
      throw ArgumentError('Cannot update a credit card without an id');
    }
    final db = await _database.database;
    return db.update(
      CreditCard.tableName,
      _encryptCard(card).toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return db.delete(CreditCard.tableName, where: 'id = ?', whereArgs: [id]);
  }

  CreditCard _encryptCard(CreditCard card) {
    return card.copyWith(
      cardHolderName: _encryptionService.encrypt(card.cardHolderName),
      cardNumber: _encryptionService.encrypt(card.cardNumber),
      expiryDate: _encryptionService.encrypt(card.expiryDate),
      cvv: _encryptionService.encrypt(card.cvv),
    );
  }

  CreditCard _mapEncryptedCard(Map<String, dynamic> map) {
    final raw = CreditCard.fromMap(map);
    return raw.copyWith(
      cardHolderName: _encryptionService.decrypt(raw.cardHolderName),
      cardNumber: _encryptionService.decrypt(raw.cardNumber),
      expiryDate: _encryptionService.decrypt(raw.expiryDate),
      cvv: _encryptionService.decrypt(raw.cvv),
    );
  }

  Future<List<CreditCard>> _decryptCardRows(
    List<Map<String, dynamic>> rows,
    DatabaseExecutor db,
  ) async {
    final cards = <CreditCard>[];
    for (final row in rows) {
      await _ensureCardEncrypted(db, row);
      cards.add(_mapEncryptedCard(row));
    }
    return cards;
  }

  Future<void> _ensureCardEncrypted(
    DatabaseExecutor db,
    Map<String, dynamic> row,
  ) async {
    final holder = row['card_holder_name'] as String?;
    final number = row['card_number'] as String?;
    final expiry = row['expiry_date'] as String?;
    final cvv = row['cvv'] as String?;

    final needsMigration = [holder, number, expiry, cvv].any((value) {
      if (value == null || value.isEmpty) {
        return false;
      }
      return !_encryptionService.isCipherText(value);
    });

    if (!needsMigration) {
      return;
    }

    try {
      final legacy = CreditCard.fromMap(row);
      final encrypted = _encryptCard(legacy);
      if (legacy.id == null) {
        return;
      }
      await db.update(
        CreditCard.tableName,
        encrypted.toMap(),
        where: 'id = ?',
        whereArgs: [legacy.id],
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Credit card encryption migration failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }
}
