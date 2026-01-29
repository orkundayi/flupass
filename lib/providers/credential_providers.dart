import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';
import '../services/autofill_sync_service.dart';
import 'app_providers.dart';

final credentialListProvider =
    AsyncNotifierProvider<CredentialListController, List<Credential>>(
      CredentialListController.new,
    );

class CredentialListController extends AsyncNotifier<List<Credential>> {
  CredentialRepository get _repository =>
      ref.read(credentialRepositoryProvider);
  AutofillSyncService get _autofillSyncService =>
      ref.read(autofillSyncServiceProvider);

  @override
  Future<List<Credential>> build() async {
    final credentials = await _repository.fetchAll();
    _syncAutofill(credentials);
    return credentials;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _repository.fetchAll());
    state = result;
    result.whenData(_syncAutofill);
  }

  Future<Credential?> addCredential(Credential credential) async {
    final now = DateTime.now();
    final toInsert = credential.copyWith(updatedAt: now);

    final id = await _repository.insert(toInsert);
    final saved = toInsert.copyWith(id: id);
    _updateState((items) => [saved, ...items]);
    return saved;
  }

  Future<bool> updateCredential(Credential credential) async {
    if (credential.id == null) {
      return false;
    }

    final updatedCredential = credential.copyWith(updatedAt: DateTime.now());
    final rowsAffected = await _repository.update(updatedCredential);
    if (rowsAffected > 0) {
      _updateState((items) {
        return items
            .map(
              (item) =>
                  item.id == updatedCredential.id ? updatedCredential : item,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
      return true;
    }
    return false;
  }

  Future<bool> deleteCredential(int id) async {
    final deleted = await _repository.delete(id);
    if (deleted > 0) {
      _updateState((items) => items.where((item) => item.id != id).toList());
      return true;
    }
    return false;
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    await _repository.toggleFavorite(id, isFavorite);
    _updateState((items) {
      return items.map((item) {
        if (item.id == id) {
          return item.copyWith(
            isFavorite: isFavorite,
            updatedAt: DateTime.now(),
          );
        }
        return item;
      }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<List<Credential>> search(String query) {
    return _repository.search(query);
  }

  void _updateState(List<Credential> Function(List<Credential>) updater) {
    final current = state.value ?? <Credential>[];
    final updated = updater(current);
    state = AsyncValue.data(updated);
    _syncAutofill(updated);
  }

  void _syncAutofill(List<Credential> credentials) {
    unawaited(_autofillSyncService.syncCredentials(credentials));
  }
}
