import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/credential.dart';

/// Autofill senkronizasyon sonucu
class AutofillSyncResult {
  final bool success;
  final String? errorMessage;
  final int syncedCount;

  const AutofillSyncResult({
    required this.success,
    this.errorMessage,
    this.syncedCount = 0,
  });

  factory AutofillSyncResult.success(int count) =>
      AutofillSyncResult(success: true, syncedCount: count);

  factory AutofillSyncResult.failure(String message) =>
      AutofillSyncResult(success: false, errorMessage: message);
}

class AutofillSyncService {
  AutofillSyncService();

  static const _channel = MethodChannel('com.flutech.flupass/autofill');

  /// Son senkronizasyon sonucu
  AutofillSyncResult? _lastCredentialSyncResult;

  AutofillSyncResult? get lastCredentialSyncResult => _lastCredentialSyncResult;

  /// Şifreleri autofill sistemine senkronize et
  Future<AutofillSyncResult> syncCredentials(
    List<Credential> credentials,
  ) async {
    if (!_isSupportedPlatform) {
      return AutofillSyncResult.failure('Platform desteklenmiyor');
    }

    final entries = credentials
        .where(
          (credential) =>
              credential.username.isNotEmpty && credential.password.isNotEmpty,
        )
        .map((credential) {
          return {
            'id': credential.id,
            'title': credential.title,
            'username': credential.username,
            'password': credential.password,
            'website': credential.website ?? '',
          };
        })
        .toList(growable: false);

    try {
      await _channel.invokeMethod<void>('syncCredentials', {
        'entries': entries,
      });
      _lastCredentialSyncResult = AutofillSyncResult.success(entries.length);
      if (kDebugMode) {
        debugPrint('Autofill: ${entries.length} şifre senkronize edildi');
      }
      return _lastCredentialSyncResult!;
    } on PlatformException catch (error) {
      final message = error.message ?? 'Bilinmeyen hata';
      _lastCredentialSyncResult = AutofillSyncResult.failure(message);
      if (kDebugMode) {
        debugPrint('Autofill sync failed: $error');
      }
      return _lastCredentialSyncResult!;
    } catch (error) {
      final message = error.toString();
      _lastCredentialSyncResult = AutofillSyncResult.failure(message);
      if (kDebugMode) {
        debugPrint('Autofill sync failed: $error');
      }
      return _lastCredentialSyncResult!;
    }
  }

  /// Autofill ayarlarını aç
  Future<bool> openAutofillSettings() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('openAutofillSettings');
      return result ?? false;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Autofill settings redirect failed: $error');
      }
      return false;
    }
  }

  /// Autofill biometrik doğrulamayı aç/kapat (sadece iOS)
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (!_isSupportedPlatform) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('setBiometricEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Biometric setting failed: $error');
      }
      return false;
    }
  }

  /// Autofill biometrik doğrulama durumunu al (sadece iOS)
  Future<bool> isBiometricEnabled() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isBiometricEnabled');
      return result ?? true;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Get biometric setting failed: $error');
      }
      return true;
    }
  }

  /// Autofill verilerini temizle
  Future<bool> clearAutofillData() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    try {
      await _channel.invokeMethod<void>('clearAutofillData');
      _lastCredentialSyncResult = null;
      return true;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Clear autofill data failed: $error');
      }
      return false;
    }
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
