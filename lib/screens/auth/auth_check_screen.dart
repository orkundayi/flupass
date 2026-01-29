import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/security_service.dart';

void _authLog(String message) {
  if (kDebugMode) {
    print('[AuthCheck] $message');
  }
}

class AuthCheckScreen extends ConsumerStatefulWidget {
  const AuthCheckScreen({
    super.key,
    this.forceCheck = false,
    this.onAuthSuccess,
  });

  final bool forceCheck;
  final VoidCallback? onAuthSuccess;

  @override
  ConsumerState<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends ConsumerState<AuthCheckScreen>
    with SingleTickerProviderStateMixin {
  bool _requestedBiometric = false;
  bool _isProcessing = false;
  bool _usePinFallback = false;
  bool _hasFailed = false; // Gerçekten denendi ve başarısız oldu mu?
  String? _errorMessage;

  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SecurityState>(securityControllerProvider, (previous, next) {
      _authLog('🔔 State listener triggered');
      _authLog('  - previous.isAuthenticated: ${previous?.isAuthenticated}');
      _authLog('  - next.isAuthenticated: ${next.isAuthenticated}');
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      if (!wasAuthenticated && next.isAuthenticated) {
        _authLog('  - Auth state changed to TRUE, calling _handleSuccess');
        _handleSuccess();
      }
    });

    final securityState = ref.watch(securityControllerProvider);
    final securityController = ref.read(securityControllerProvider.notifier);

    _authLog('📱 build() called');
    _authLog('  - isInitialized: ${securityState.isInitialized}');
    _authLog('  - isSecurityEnabled: ${securityState.isSecurityEnabled}');
    _authLog('  - isSecurityActive: ${securityState.isSecurityActive}');
    _authLog('  - isAuthenticated: ${securityState.isAuthenticated}');

    if (!securityState.isInitialized) {
      _authLog('  → Showing loading (not initialized)');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (!securityState.isSecurityEnabled || !securityState.isSecurityActive) {
      _authLog('  → Security disabled/inactive, auto-success');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        securityController.disableSecurityForSession();
        _handleSuccess();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final method = securityController.getPreferredAuthMethod();
    _authLog('  → Preferred method: $method');

    if (method == AuthMethod.biometric && !_usePinFallback) {
      _authLog('  → Showing BiometricAuthView');
      // Otomatik biyometrik tetikleme kaldırıldı - kullanıcı butona bassın
      return _BiometricAuthView(
        isProcessing: _isProcessing,
        hasFailed: _hasFailed,
        errorMessage: _errorMessage,
        pulseAnimation: _pulseAnimation,
        onAuthenticate: () =>
            _tryBiometric(securityController, securityState.isPinEnabled),
        onUsePin: securityState.isPinEnabled
            ? () {
                setState(() {
                  _usePinFallback = true;
                  _errorMessage = null;
                  _hasFailed = false;
                  _requestedBiometric = false;
                });
              }
            : null,
      );
    }

    if (method == AuthMethod.pin || _usePinFallback) {
      return _PinAuthView(
        formKey: _formKey,
        pinController: _pinController,
        isProcessing: _isProcessing,
        errorMessage: _errorMessage,
        onSubmit: () => _verifyPin(securityController),
        onUseBiometric: securityState.isBiometricEnabled && !_usePinFallback
            ? () {
                setState(() {
                  _usePinFallback = false;
                  _errorMessage = null;
                  _hasFailed = false;
                });
              }
            : securityState.isBiometricEnabled
            ? () {
                setState(() {
                  _usePinFallback = false;
                  _errorMessage = null;
                  _hasFailed = false;
                });
                _tryBiometric(securityController, securityState.isPinEnabled);
              }
            : null,
      );
    }

    return _NoSecurityView(
      onContinue: () {
        securityController.disableSecurityForSession();
        _handleSuccess();
      },
    );
  }

  void _handleSuccess() {
    _authLog('✅ _handleSuccess called');
    _authLog('  - forceCheck: ${widget.forceCheck}');
    _authLog('  - canPop: ${Navigator.of(context).canPop()}');
    widget.onAuthSuccess?.call();
    if (!widget.forceCheck && Navigator.of(context).canPop()) {
      _authLog('  - Popping navigator');
      Navigator.of(context).pop();
    }
  }

  Future<void> _tryBiometric(
    SecurityController controller,
    bool hasPinFallback,
  ) async {
    _authLog('🔐 _tryBiometric called');
    if (_isProcessing) {
      _authLog('  - SKIP: already processing');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _hasFailed = false;
    });

    if (!_requestedBiometric) {
      _requestedBiometric = true;
    }

    _authLog('  - Calling authenticateWithBiometrics(inlineAuth: true)');
    // inlineAuth: true ile çağır - lifecycle observer'ın müdahale etmesini engelle
    final success = await controller.authenticateWithBiometrics(
      inlineAuth: true,
    );
    _authLog('  - Result: success=$success');

    if (!mounted) {
      _authLog('  - SKIP: not mounted');
      return;
    }

    final securityState = ref.read(securityControllerProvider);
    _authLog('  - After auth state:');
    _authLog('    - isAuthenticated: ${securityState.isAuthenticated}');
    _authLog('    - isSecurityActive: ${securityState.isSecurityActive}');

    setState(() {
      _isProcessing = false;
      if (!success) {
        _hasFailed = true;
        _errorMessage = 'Doğrulama başarısız. Tekrar deneyin.';
        if (!_usePinFallback && hasPinFallback) {
          _usePinFallback = true;
        }
      }
    });
  }

  Future<void> _verifyPin(SecurityController controller) async {
    if (_isProcessing) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final pin = _pinController.text.trim();
    final success = await controller.verifyPin(pin);

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
      _errorMessage = success ? null : 'PIN hatalı. Lütfen tekrar deneyin.';
    });

    if (!success) {
      _pinController
        ..clear()
        ..selection = const TextSelection.collapsed(offset: 0);
    }
  }
}

class _BiometricAuthView extends StatelessWidget {
  const _BiometricAuthView({
    required this.isProcessing,
    required this.hasFailed,
    required this.errorMessage,
    required this.pulseAnimation,
    required this.onAuthenticate,
    this.onUsePin,
  });

  final bool isProcessing;
  final bool hasFailed;
  final String? errorMessage;
  final Animation<double> pulseAnimation;
  final VoidCallback onAuthenticate;
  final VoidCallback? onUsePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Ana ikon ve animasyon
              ScaleTransition(
                scale: pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primary.withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Başlık
              Text(
                'Hoş Geldiniz',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // Alt başlık - duruma göre değişiyor
              Text(
                isProcessing
                    ? 'Doğrulanıyor...'
                    : hasFailed
                    ? 'Tekrar denemek için butona dokunun'
                    : 'Devam etmek için kimliğinizi doğrulayın',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              // Hata mesajı - sadece gerçek hata varsa göster
              if (hasFailed && errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // Butonlar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: isProcessing ? null : onAuthenticate,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(
                    isProcessing ? 'Doğrulanıyor...' : 'Biyometrik ile Giriş',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              if (onUsePin != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : onUsePin,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.pin_outlined),
                    label: const Text(
                      'PIN ile Giriş',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinAuthView extends StatelessWidget {
  const _PinAuthView({
    required this.formKey,
    required this.pinController,
    required this.isProcessing,
    required this.errorMessage,
    required this.onSubmit,
    this.onUseBiometric,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController pinController;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback? onUseBiometric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Kilit ikonu
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'PIN ile Giriş',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Verilerinize erişmek için PIN kodunuzu girin',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // PIN girişi
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        letterSpacing: 8,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      counterText: '',
                    ),
                    maxLength: 6,
                    onFieldSubmitted: (_) => onSubmit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'PIN kodunu girin';
                      }
                      if (value.trim().length < 4) {
                        return 'En az 4 haneli olmalı';
                      }
                      return null;
                    },
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 20,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Butonlar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: isProcessing ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isProcessing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                if (onUseBiometric != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : onUseBiometric,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text(
                        'Biyometrik ile Giriş',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoSecurityView extends StatelessWidget {
  const _NoSecurityView({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.tertiaryContainer,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: colorScheme.tertiary,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Güvenlik Ayarlanmamış',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Verilerinizi korumak için Ayarlar\'dan\ngüvenlik yöntemi ekleyebilirsiniz.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
