import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/credential_repository.dart';
import '../repositories/credit_card_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/app_database.dart';
import '../services/encryption_service.dart';
import '../services/credential_transfer_service.dart';
import '../services/autofill_sync_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.instance;
  ref.onDispose(database.close);
  return database;
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final service = EncryptionService();
  ref.onDispose(service.reset);
  return service;
});

final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  final database = ref.read(appDatabaseProvider);
  final encryption = ref.read(encryptionServiceProvider);
  return CredentialRepository(database, encryption);
});

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  final database = ref.read(appDatabaseProvider);
  final encryption = ref.read(encryptionServiceProvider);
  return CreditCardRepository(database, encryption);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final database = ref.read(appDatabaseProvider);
  return SettingsRepository(database);
});

final credentialTransferServiceProvider = Provider<CredentialTransferService>((
  ref,
) {
  final repository = ref.read(credentialRepositoryProvider);
  return CredentialTransferService(repository);
});

final autofillSyncServiceProvider = Provider<AutofillSyncService>((ref) {
  return AutofillSyncService();
});

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  late final SettingsRepository _settingsRepository;
  bool _isInitialized = false;

  @override
  ThemeMode build() {
    _settingsRepository = ref.read(settingsRepositoryProvider);
    _loadThemeMode();
    return ThemeMode.system;
  }

  bool get isInitialized => _isInitialized;

  Future<void> setTheme(ThemeMode mode) async {
    if (state == mode) {
      return;
    }

    state = mode;
    await _settingsRepository.saveThemeMode(mode);
  }

  Future<void> toggleTheme() async {
    // Eğer sistem modundaysak, sistemin mevcut temasına göre geçiş yap
    ThemeMode nextMode;
    if (state == ThemeMode.system) {
      // Sistem modundan çıkıyoruz
      nextMode = ThemeMode.dark;
    } else {
      nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
    await setTheme(nextMode);
  }

  Future<void> _loadThemeMode() async {
    final savedMode = await _settingsRepository.loadThemeMode();
    if (savedMode != null) {
      state = savedMode;
    }
    _isInitialized = true;
  }
}

/// Helper extension to check if current theme is dark mode
extension ThemeModeExtension on ThemeMode {
  /// Returns true if this theme mode results in dark theme
  bool isDarkMode(BuildContext context) {
    switch (this) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }
}
