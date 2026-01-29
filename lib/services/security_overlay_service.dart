import 'package:flutter/material.dart';

import '../screens/auth/auth_check_screen.dart';

class SecurityOverlayManager {
  SecurityOverlayManager._internal();

  static final SecurityOverlayManager _instance =
      SecurityOverlayManager._internal();

  factory SecurityOverlayManager() => _instance;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  OverlayEntry? _overlayEntry;

  bool get isShowingOverlay => _overlayEntry != null;

  void showSecurityOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      return;
    }

    final overlayState =
        Overlay.maybeOf(context, rootOverlay: true) ??
        navigatorKey.currentState?.overlay;

    if (overlayState == null) {
      assert(() {
        debugPrint(
          'SecurityOverlayManager: OverlayState not available, skipping auth overlay.',
        );
        return true;
      }());
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: const Color.fromRGBO(0, 0, 0, 0.7),
        child: AuthCheckScreen(
          forceCheck: true,
          onAuthSuccess: hideSecurityOverlay,
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  void hideSecurityOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
