import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'screens/auth/app_life_cycle_observer.dart';
import 'screens/home/home_screen.dart';
import 'services/security_overlay_service.dart';
import 'services/security_service.dart';
import 'services/encryption_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EncryptionService().initialize();

  runApp(const ProviderScope(child: FluPassApp()));
}

class FluPassApp extends ConsumerStatefulWidget {
  const FluPassApp({super.key});

  @override
  ConsumerState<FluPassApp> createState() => _FluPassAppState();
}

class _FluPassAppState extends ConsumerState<FluPassApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(securityControllerProvider.notifier).initialize(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final securityState = ref.watch(securityControllerProvider);

    ref.listen<SecurityState>(securityControllerProvider, (previous, next) {
      _handleSecurityState(next);
    });

    _handleSecurityState(securityState);

    return AppLifecycleObserver(
      child: MaterialApp(
        title: 'FluPass',
        debugShowCheckedModeBanner: false,
        navigatorKey: SecurityOverlayManager().navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const HomeScreen(),
      ),
    );
  }

  void _handleSecurityState(SecurityState state) {
    if (!mounted || !state.isInitialized) {
      return;
    }

    final overlayManager = SecurityOverlayManager();
    final shouldRequireAuth =
        state.isSecurityEnabled &&
        state.isSecurityActive &&
        !state.isAuthenticated;

    if (shouldRequireAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (!overlayManager.isShowingOverlay) {
          final overlayContext =
              overlayManager.navigatorKey.currentContext ?? context;
          overlayManager.showSecurityOverlay(overlayContext);
        }
      });
      return;
    }

    if (!state.isSecurityActive && overlayManager.isShowingOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        overlayManager.hideSecurityOverlay();
      });
    }
  }
}
