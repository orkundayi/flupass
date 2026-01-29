import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final securityControllerProvider =
    NotifierProvider<SecurityController, SecurityState>(SecurityController.new);

enum AuthMethod { none, pin, biometric }

/// Biyometrik kurulum sonuçları
enum BiometricSetupResult {
  success, // Başarılı
  notSupported, // Cihaz biyometrik desteklemiyor
  notEnrolled, // Parmak izi/Face ID kayıtlı değil
  permissionDenied, // Kullanıcı izni reddetti (kalıcı)
  lockedOut, // Çok fazla başarısız deneme
  cancelled, // Kullanıcı iptal etti
  failed, // Genel hata
}

class SecurityState {
  const SecurityState({
    required this.isAuthenticated,
    required this.isPinEnabled,
    required this.isBiometricEnabled,
    required this.isSecurityEnabled,
    required this.isInitialized,
    required this.isSecurityActive,
    required this.isInlineAuthInProgress,
  });

  factory SecurityState.initial() {
    return const SecurityState(
      isAuthenticated: false,
      isPinEnabled: false,
      isBiometricEnabled: false,
      isSecurityEnabled: false,
      isInitialized: false,
      isSecurityActive: false,
      isInlineAuthInProgress: false,
    );
  }

  final bool isAuthenticated;
  final bool isPinEnabled;
  final bool isBiometricEnabled;
  final bool isSecurityEnabled;
  final bool isInitialized;
  final bool isSecurityActive;
  final bool isInlineAuthInProgress;

  SecurityState copyWith({
    bool? isAuthenticated,
    bool? isPinEnabled,
    bool? isBiometricEnabled,
    bool? isSecurityEnabled,
    bool? isInitialized,
    bool? isSecurityActive,
    bool? isInlineAuthInProgress,
  }) {
    return SecurityState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isSecurityEnabled: isSecurityEnabled ?? this.isSecurityEnabled,
      isInitialized: isInitialized ?? this.isInitialized,
      isSecurityActive: isSecurityActive ?? this.isSecurityActive,
      isInlineAuthInProgress:
          isInlineAuthInProgress ?? this.isInlineAuthInProgress,
    );
  }
}

class SecurityController extends Notifier<SecurityState> {
  static const _pinEnabledKey = 'pin_enabled';
  static const _pinHashKey = 'pin_hash';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _securityEnabledKey = 'security_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();
  SharedPreferences? _prefs;

  // Auth başarılı olduktan sonra kısa süre lockApp çağrılmasını engelle
  DateTime? _lastAuthSuccessTime;
  static const _authGracePeriod = Duration(seconds: 2);

  @override
  SecurityState build() {
    return SecurityState.initial();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      final pinEnabled = prefs.getBool(_pinEnabledKey) ?? false;
      var biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      final securityEnabled = prefs.getBool(_securityEnabledKey) ?? false;

      var isSecurityActive = securityEnabled;

      if (biometricEnabled) {
        try {
          final canCheckBiometrics = await _localAuth.canCheckBiometrics;
          final isDeviceSupported = await _localAuth.isDeviceSupported();

          if (!canCheckBiometrics || !isDeviceSupported) {
            biometricEnabled = false;
            await prefs.setBool(_biometricEnabledKey, false);
          }
        } catch (error) {
          biometricEnabled = false;
          await prefs.setBool(_biometricEnabledKey, false);
          if (kDebugMode) {
            print('Biometric capability check failed: $error');
          }
        }
      }

      final isAuthenticated = !securityEnabled;

      state = state.copyWith(
        isPinEnabled: pinEnabled,
        isBiometricEnabled: biometricEnabled,
        isSecurityEnabled: securityEnabled,
        isSecurityActive: isSecurityActive,
        isAuthenticated: isAuthenticated,
        isInitialized: true,
      );
    } catch (error) {
      if (kDebugMode) {
        print('Security initialization failed: $error');
      }
      state = state.copyWith(
        isAuthenticated: false,
        isInitialized: true,
        isSecurityEnabled: false,
        isSecurityActive: false,
        isPinEnabled: false,
        isBiometricEnabled: false,
      );
    }
  }

  bool authenticationRequired() {
    return state.isSecurityEnabled && !state.isAuthenticated;
  }

  Future<bool> setPin(String pin) async {
    try {
      final prefs = await _ensurePrefs();
      final pinHash = pin.hashCode.toString();

      await prefs.setString(_pinHashKey, pinHash);
      await prefs.setBool(_pinEnabledKey, true);
      await prefs.setBool(_securityEnabledKey, true);

      state = state.copyWith(
        isPinEnabled: true,
        isSecurityEnabled: true,
        isSecurityActive: true,
        isAuthenticated: false,
      );
      return true;
    } catch (error) {
      if (kDebugMode) {
        print('Error while setting PIN: $error');
      }
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await _ensurePrefs();
      final storedPinHash = prefs.getString(_pinHashKey);
      final inputPinHash = pin.hashCode.toString();

      final isValid = storedPinHash == inputPinHash;
      if (isValid) {
        _lastAuthSuccessTime = DateTime.now();
        state = state.copyWith(isAuthenticated: true, isSecurityActive: false);
      }
      return isValid;
    } catch (error) {
      if (kDebugMode) {
        print('Error while verifying PIN: $error');
      }
      return false;
    }
  }

  Future<BiometricSetupResult> setupBiometricAuth() async {
    state = state.copyWith(isInlineAuthInProgress: true);
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        return BiometricSetupResult.notSupported;
      }

      // NOT: iOS'ta Face ID izni reddedildiğinde getAvailableBiometrics() boş döner.
      // Bu yüzden önce authenticate() çağrısı yapıp hata kodundan sonucu belirliyoruz.
      // Android'de bu sorun yok.

      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Biyometrik kimlik doğrulamayı etkinleştirmek için doğrulama yapın',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );

      if (!authenticated) {
        return BiometricSetupResult.cancelled;
      }

      final prefs = await _ensurePrefs();
      await prefs.setBool(_biometricEnabledKey, true);
      await prefs.setBool(_securityEnabledKey, true);

      state = state.copyWith(
        isBiometricEnabled: true,
        isSecurityEnabled: true,
        isAuthenticated: true,
        isSecurityActive: false,
        isInlineAuthInProgress: false,
      );
      return BiometricSetupResult.success;
    } on LocalAuthException catch (error) {
      if (kDebugMode) {
        print('Biometric setup failed: ${error.code}');
      }

      // local_auth 3.0.0 LocalAuthExceptionCode enum kullanıyor
      // NOT: iOS'ta Face ID izni reddedildiğinde noBiometricHardware hatası
      // dönebiliyor. Bu yüzden çoğu hatayı permissionDenied olarak işliyoruz
      // ve kullanıcıya ayarlara gitme seçeneği sunuyoruz.
      switch (error.code) {
        case LocalAuthExceptionCode.biometricLockout:
          return BiometricSetupResult.lockedOut;
        case LocalAuthExceptionCode.userCanceled:
          return BiometricSetupResult.cancelled;
        default:
          // iOS'ta izin reddi, hardware yok, kayıtlı değil gibi durumların
          // hepsi benzer hatalar veriyor. Kullanıcıya genel bir mesaj gösterip
          // ayarlara yönlendirmek en iyi yaklaşım.
          return BiometricSetupResult.permissionDenied;
      }
    } catch (_) {
      return BiometricSetupResult.failed;
    } finally {
      state = state.copyWith(isInlineAuthInProgress: false);
    }
  }

  Future<bool> authenticateWithBiometrics({bool inlineAuth = false}) async {
    if (inlineAuth) {
      state = state.copyWith(isInlineAuthInProgress: true);
    }
    try {
      if (!state.isBiometricEnabled) {
        return false;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheckBiometrics || !isDeviceSupported) {
        await removeBiometricAuth();
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Uygulamaya erişmek için biyometrik doğrulama gerekli',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );

      if (authenticated) {
        _lastAuthSuccessTime = DateTime.now();
        state = state.copyWith(isAuthenticated: true, isSecurityActive: false);
        return true;
      }
      return false;
    } on LocalAuthException catch (error) {
      if (kDebugMode) {
        print('Biometric auth failed: ${error.code}');
      }

      // Biyometrik artık kullanılamıyorsa kaldır
      const removalCodes = {
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.noCredentialsSet,
        LocalAuthExceptionCode.noBiometricHardware,
      };

      if (removalCodes.contains(error.code)) {
        await removeBiometricAuth();
      }

      return false;
    } catch (_) {
      return false;
    } finally {
      if (inlineAuth) {
        state = state.copyWith(isInlineAuthInProgress: false);
      }
    }
  }

  Future<bool> removeBiometricAuth() async {
    try {
      final prefs = await _ensurePrefs();
      await prefs.setBool(_biometricEnabledKey, false);

      var securityEnabled = state.isSecurityEnabled;
      var securityActive = state.isSecurityActive;

      if (!state.isPinEnabled) {
        await prefs.setBool(_securityEnabledKey, false);
        securityEnabled = false;
        securityActive = false;
      }

      state = state.copyWith(
        isBiometricEnabled: false,
        isSecurityEnabled: securityEnabled,
        isSecurityActive: securityActive,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateAndRemoveBiometricAuth() async {
    try {
      final authenticated = await authenticateWithBiometrics(inlineAuth: true);
      if (authenticated) {
        return removeBiometricAuth();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disablePin() async {
    try {
      final prefs = await _ensurePrefs();
      await prefs.setBool(_pinEnabledKey, false);

      var securityEnabled = state.isSecurityEnabled;
      var securityActive = state.isSecurityActive;

      if (!state.isBiometricEnabled) {
        await prefs.setBool(_securityEnabledKey, false);
        securityEnabled = false;
        securityActive = false;
      }

      state = state.copyWith(
        isPinEnabled: false,
        isSecurityEnabled: securityEnabled,
        isSecurityActive: securityActive,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateAndRemovePin(String pin) async {
    try {
      final authenticated = await verifyPin(pin);
      if (authenticated) {
        return disablePin();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void disableSecurityForSession() {
    if (state.isSecurityActive) {
      state = state.copyWith(isSecurityActive: false, isAuthenticated: true);
    }
  }

  void lockApp() {
    if (kDebugMode) {
      print('[Security] lockApp() called');
      print('  - isSecurityEnabled: ${state.isSecurityEnabled}');
      print('  - isInlineAuthInProgress: ${state.isInlineAuthInProgress}');
      print('  - _lastAuthSuccessTime: $_lastAuthSuccessTime');
    }

    if (state.isSecurityEnabled && !state.isInlineAuthInProgress) {
      // Auth başarılı olduktan hemen sonra lockApp çağrılmasını engelle
      // (iOS biyometrik dialog kapandıktan sonra lifecycle events tetikleniyor)
      if (_lastAuthSuccessTime != null) {
        final elapsed = DateTime.now().difference(_lastAuthSuccessTime!);
        if (kDebugMode) {
          print('  - elapsed: ${elapsed.inMilliseconds}ms');
          print('  - gracePeriod: ${_authGracePeriod.inMilliseconds}ms');
        }
        if (elapsed < _authGracePeriod) {
          if (kDebugMode) {
            print('[Security] ⏭️ lockApp() SKIPPED - within grace period');
          }
          return;
        }
      }

      if (kDebugMode) {
        print('[Security] 🔒 lockApp() EXECUTING - locking app');
      }
      state = state.copyWith(isAuthenticated: false, isSecurityActive: true);
    } else {
      if (kDebugMode) {
        print('[Security] ⏭️ lockApp() SKIPPED - conditions not met');
      }
    }
  }

  bool shouldShowAuthScreen() {
    return state.isSecurityEnabled && !state.isAuthenticated;
  }

  AuthMethod getPreferredAuthMethod() {
    if (state.isBiometricEnabled) {
      return AuthMethod.biometric;
    }
    if (state.isPinEnabled) {
      return AuthMethod.pin;
    }
    return AuthMethod.none;
  }

  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs != null) {
      return _prefs!;
    }
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }
}
