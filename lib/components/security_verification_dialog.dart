import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../services/security_service.dart';

class SecurityVerificationDialog extends ConsumerStatefulWidget {
  const SecurityVerificationDialog({
    super.key,
    this.title = 'Kimlik doğrulama',
    this.message = 'Devam etmek için kimliğinizi doğrulayın',
  });

  final String title;
  final String message;

  @override
  ConsumerState<SecurityVerificationDialog> createState() =>
      _SecurityVerificationDialogState();
}

class _SecurityVerificationDialogState
    extends ConsumerState<SecurityVerificationDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String? _errorMessage;
  bool _showPinInput = false;
  bool _isBiometricAvailable = false;
  bool _isProcessing = false;
  Timer? _autoFocusTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveOptions());
  }

  @override
  void dispose() {
    _autoFocusTimer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      Color.lerp(
                            colorScheme.primary,
                            colorScheme.surface,
                            0.2,
                          ) ??
                          colorScheme.primary,
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 32,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.message,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      _buildProcessingState(colorScheme, textTheme)
                    else if (_showPinInput)
                      _buildPinEntry(theme)
                    else if (_isBiometricAvailable)
                      _buildBiometricPrompt(colorScheme, textTheme)
                    else
                      _buildNoSecurityInfo(textTheme),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    if (_showPinInput)
                      Expanded(
                        child: FilledButton(
                          onPressed: _isProcessing ? null : _verifyPin,
                          child: Text(
                            _isProcessing ? 'Doğrulanıyor...' : 'Doğrula',
                          ),
                        ),
                      )
                    else if (_isBiometricAvailable)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : _authenticateWithBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(
                            _isProcessing
                                ? 'Doğrulanıyor...'
                                : 'Biyometrik doğrula',
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('İptal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState(ColorScheme colors, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            color: colors.primary,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Doğrulama yapılıyor...',
          style: textTheme.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricPrompt(ColorScheme colors, TextTheme textTheme) {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.fingerprint, size: 56, color: colors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Biyometrik kimlik doğrulaması',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Devam etmek için biyometrik yöntemi kullanın.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (ref.read(securityControllerProvider).isPinEnabled)
          TextButton(
            onPressed: _isProcessing
                ? null
                : () {
                    setState(() {
                      _showPinInput = true;
                      _errorMessage = null;
                    });
                    _scheduleAutofocus();
                  },
            child: const Text('PIN ile doğrula'),
          ),
      ],
    );
  }

  Widget _buildPinEntry(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PIN kodu ile doğrulama',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          focusNode: _pinFocusNode,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            labelText: 'PIN kodu',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onSubmitted: (_) => _verifyPin(),
        ),
        const SizedBox(height: 8),
        if (ref.read(securityControllerProvider).isBiometricEnabled)
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    setState(() {
                      _showPinInput = false;
                      _errorMessage = null;
                    });
                  },
            icon: const Icon(Icons.fingerprint),
            label: const Text('Biyometrik doğrulamaya dön'),
          ),
      ],
    );
  }

  Widget _buildNoSecurityInfo(TextTheme textTheme) {
    return Column(
      children: [
        Icon(Icons.verified_user, size: 48, color: Colors.grey.shade500),
        const SizedBox(height: 12),
        Text('Güvenlik yöntemi etkin değil.', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Devam etmek için onaylayın.'),
      ],
    );
  }

  Future<void> _resolveOptions() async {
    final securityState = ref.read(securityControllerProvider);
    if (!securityState.isSecurityEnabled) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() {
      _isBiometricAvailable = securityState.isBiometricEnabled;
      _showPinInput =
          !securityState.isBiometricEnabled && securityState.isPinEnabled;
    });

    if (_showPinInput) {
      _scheduleAutofocus();
    }
  }

  void _scheduleAutofocus() {
    _autoFocusTimer?.cancel();
    _autoFocusTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }
      _pinFocusNode.requestFocus();
    });
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'PIN kodu gerekli.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final success = await ref
        .read(securityControllerProvider.notifier)
        .verifyPin(_pinController.text.trim());

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'PIN doğrulanamadı.';
        _pinController
          ..clear()
          ..selection = const TextSelection.collapsed(offset: 0);
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final success = await ref
          .read(securityControllerProvider.notifier)
          .authenticateWithBiometrics(inlineAuth: true);
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else if (ref.read(securityControllerProvider).isPinEnabled) {
        setState(() {
          _showPinInput = true;
          _errorMessage = 'Biyometrik doğrulama başarısız. PIN deneyin.';
        });
        _scheduleAutofocus();
      } else {
        setState(() {
          _errorMessage = 'Biyometrik doğrulama başarısız oldu.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _errorMessage = _mapBiometricError(error);
        if (ref.read(securityControllerProvider).isPinEnabled) {
          _showPinInput = true;
          _scheduleAutofocus();
        }
      });
    }
  }

  String _mapBiometricError(Object error) {
    if (error is LocalAuthException) {
      switch (error.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          return 'Cihazınızda biyometrik yöntem tanımlı değil.';
        case LocalAuthExceptionCode.biometricLockout:
          return 'Çok fazla başarısız deneme yapıldı. Daha sonra tekrar deneyin.';
        default:
          return 'Biyometrik doğrulama tamamlanamadı.';
      }
    }
    return 'Biyometrik doğrulama tamamlanamadı.';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
