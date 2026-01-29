import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credit_card.dart';
import '../repositories/credit_card_repository.dart';
import 'app_providers.dart';

final creditCardListProvider =
    AsyncNotifierProvider<CreditCardListController, List<CreditCard>>(
      CreditCardListController.new,
    );

class CreditCardListController extends AsyncNotifier<List<CreditCard>> {
  CreditCardRepository get _repository =>
      ref.read(creditCardRepositoryProvider);

  @override
  Future<List<CreditCard>> build() async {
    final cards = await _repository.fetchAll();
    return cards;
  }

  Future<CreditCard?> addCard(CreditCard card) async {
    final id = await _repository.insert(card);
    final saved = card.copyWith(id: id);
    _updateState((items) => [saved, ...items]);
    return saved;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_repository.fetchAll);
    state = result;
  }

  Future<bool> updateCard(CreditCard card) async {
    if (card.id == null) {
      return false;
    }
    final rowsAffected = await _repository.update(card);
    if (rowsAffected > 0) {
      _updateState((items) {
        return items.map((item) => item.id == card.id ? card : item).toList();
      });
      return true;
    }
    return false;
  }

  Future<bool> deleteCard(int id) async {
    final deleted = await _repository.delete(id);
    if (deleted > 0) {
      _updateState((items) => items.where((item) => item.id != id).toList());
      return true;
    }
    return false;
  }

  void _updateState(List<CreditCard> Function(List<CreditCard>) updater) {
    final current = state.value ?? <CreditCard>[];
    final updated = updater(current);
    state = AsyncValue.data(updated);
  }
}
