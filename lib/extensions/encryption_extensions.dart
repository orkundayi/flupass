import 'package:flutter/foundation.dart';

import '../services/encryption_service.dart';

extension EncryptionHelpers on EncryptionService {
  String encryptNullable(String? value) {
    if (value == null || value.isEmpty) {
      return value ?? '';
    }
    return encrypt(value);
  }

  String? decryptToNullable(String value) {
    if (value.isEmpty) {
      return null;
    }
    final decrypted = decrypt(value);
    return decrypted.isEmpty ? null : decrypted;
  }

  String decryptForSearch(String value) {
    try {
      return decrypt(value);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Decrypt for search failed: $error');
      }
      return value;
    }
  }
}
