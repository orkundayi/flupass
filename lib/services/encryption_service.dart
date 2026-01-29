import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  factory EncryptionService() => _instance;

  EncryptionService._internal();

  static final EncryptionService _instance = EncryptionService._internal();

  static const String _cipherPrefix = 'flupass:v1';
  static const String _deviceSecretKey = 'flupass_device_secret';
  static const int _keyLength = 32;
  static const int _ivLength = 16;

  final String _masterKeyEnv = const String.fromEnvironment(
    'FLUPASS_MASTER_KEY',
    defaultValue: '',
  );
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  enc.Encrypter? _encrypter;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  bool isCipherText(String value) {
    return value.startsWith('$_cipherPrefix:');
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final masterKey = _resolveMasterKey();
    final deviceSecret = await _readOrCreateDeviceSecret();
    final derivedKey = _deriveKey(masterKey, deviceSecret);

    _encrypter = enc.Encrypter(
      enc.AES(enc.Key(derivedKey), mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );

    _isInitialized = true;
  }

  void reset() {
    _encrypter = null;
    _isInitialized = false;
  }

  String encrypt(String value) {
    if (!_isInitialized || value.isEmpty) {
      return value;
    }
    if (isCipherText(value)) {
      return value;
    }

    final ivBytes = _randomBytes(_ivLength);
    final iv = enc.IV(ivBytes);
    final encrypted = _encrypter!.encrypt(value, iv: iv);
    final ivBase64 = base64Encode(ivBytes);

    return '$_cipherPrefix:$ivBase64:${encrypted.base64}';
  }

  String decrypt(String value) {
    if (!_isInitialized || value.isEmpty) {
      return value;
    }

    if (!isCipherText(value)) {
      return value;
    }

    final parts = value.split(':');
    if (parts.length != 4) {
      return value;
    }

    try {
      final ivBytes = base64Decode(parts[2]);
      final cipherText = parts[3];
      final iv = enc.IV(ivBytes);
      return _encrypter!.decrypt64(cipherText, iv: iv);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Decryption failed: $error');
      }
      return value;
    }
  }

  Uint8List _deriveKey(String masterKey, String deviceSecret) {
    final hmac = Hmac(sha256, utf8.encode(masterKey));
    final digest = hmac.convert(utf8.encode(deviceSecret));
    return Uint8List.fromList(digest.bytes);
  }

  String _resolveMasterKey() {
    final normalized = _masterKeyEnv.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }

    if (kDebugMode) {
      debugPrint(
        'FLUPASS_MASTER_KEY is not defined. Using debug fallback key. Do not use in production.',
      );
      return 'FLUPASS_DEBUG_MASTER_KEY';
    }

    throw StateError(
      'FLUPASS_MASTER_KEY is not defined. Provide it via --dart-define.',
    );
  }

  Future<String> _readOrCreateDeviceSecret() async {
    var secret = await _secureStorage.read(key: _deviceSecretKey);
    if (secret != null && secret.isNotEmpty) {
      return secret;
    }

    final randomBytes = _randomBytes(_keyLength);
    secret = base64Encode(randomBytes);
    await _secureStorage.write(key: _deviceSecretKey, value: secret);
    return secret;
  }

  Uint8List _randomBytes(int length) {
    final secureRandom = Random.secure();
    final bytes = List<int>.generate(length, (_) => secureRandom.nextInt(256));
    return Uint8List.fromList(bytes);
  }
}
