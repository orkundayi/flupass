import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/security_overlay_service.dart';
import '../../services/security_service.dart';

class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  AppLifecycleState? _lastLifecycleState;
  bool _isLocked = false;

  void _log(String message) {
    if (kDebugMode) {
      print('[AppLifecycle] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final securityNotifier = ref.read(securityControllerProvider.notifier);
    final securityState = ref.read(securityControllerProvider);
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('State changed: $_lastLifecycleState → $state');
    _log('Security state:');
    _log('  - isSecurityEnabled: ${securityState.isSecurityEnabled}');
    _log('  - isSecurityActive: ${securityState.isSecurityActive}');
    _log('  - isAuthenticated: ${securityState.isAuthenticated}');
    _log('  - isInlineAuthInProgress: ${securityState.isInlineAuthInProgress}');
    _log('  - _isLocked: $_isLocked');
    _log('  - isShowingOverlay: ${SecurityOverlayManager().isShowingOverlay}');

    final shouldLock =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        (isIOS && state == AppLifecycleState.inactive) ||
        (isAndroid && state == AppLifecycleState.hidden);

    if (shouldLock) {
      _log('→ shouldLock=true');
      _isLocked = true;
      // Inline auth sırasında lockApp çağırma ama _isLocked'ı true yap
      if (!securityState.isInlineAuthInProgress) {
        _log('→ Calling lockApp()');
        securityNotifier.lockApp();
      } else {
        _log('→ Skipping lockApp() - inlineAuth in progress');
      }
    }

    final resumedFromBackground =
        state == AppLifecycleState.resumed &&
        _isLocked &&
        (_lastLifecycleState == AppLifecycleState.paused ||
            _lastLifecycleState == AppLifecycleState.detached ||
            (isIOS && _lastLifecycleState == AppLifecycleState.inactive) ||
            (isAndroid && _lastLifecycleState == AppLifecycleState.hidden));

    _log('→ resumedFromBackground=$resumedFromBackground');

    if (resumedFromBackground) {
      _isLocked = false;

      // Inline auth devam ediyorsa overlay gösterme
      final currentState = ref.read(securityControllerProvider);
      _log('→ Current state after resume:');
      _log(
        '  - isInlineAuthInProgress: ${currentState.isInlineAuthInProgress}',
      );
      _log('  - isAuthenticated: ${currentState.isAuthenticated}');
      _log('  - isSecurityEnabled: ${currentState.isSecurityEnabled}');
      _log('  - isSecurityActive: ${currentState.isSecurityActive}');

      if (currentState.isInlineAuthInProgress) {
        _log('→ SKIP: inlineAuth in progress');
        _lastLifecycleState = state;
        return;
      }

      // Zaten doğrulanmışsa overlay gösterme
      if (currentState.isAuthenticated) {
        _log('→ SKIP: already authenticated');
        _lastLifecycleState = state;
        return;
      }

      if (currentState.isSecurityEnabled && currentState.isSecurityActive) {
        _log('→ Will show overlay in 300ms');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) {
            _log('→ SKIP: not mounted');
            return;
          }
          // Overlay zaten açıksa tekrar açma
          if (!SecurityOverlayManager().isShowingOverlay) {
            _log('→ Showing security overlay NOW');
            SecurityOverlayManager().showSecurityOverlay(context);
          } else {
            _log('→ SKIP: overlay already showing');
          }
        });
      } else {
        _log('→ SKIP: security not enabled or not active');
      }
    }

    _lastLifecycleState = state;
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
