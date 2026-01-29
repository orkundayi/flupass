import 'package:flutter/material.dart';

/// Tema farkındalıklı uygulama ikonu widget'ı
/// Light ve dark mode için farklı görünüm sağlar
class ThemedAppIcon extends StatelessWidget {
  const ThemedAppIcon({
    super.key,
    this.size = 48,
    this.showGlow = false,
    this.borderRadius = 12,
  });

  final double size;
  final bool showGlow;
  final double borderRadius;

  static const String _lightIcon = 'assets/appicon/flupass.png';
  static const String _darkIcon = 'assets/appicon/flupass_dark.png';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Dark mode'da flupass_dark.png, yoksa flupass.png kullan
    final iconPath = isDarkMode ? _darkIcon : _lightIcon;

    Widget icon = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        iconPath,
        width: size,
        height: size,
        // Dark ikon yoksa hata almamak için fallback
        errorBuilder: (context, error, stackTrace) {
          // Dark ikon bulunamazsa light ikonu kullan
          return Image.asset(_lightIcon, width: size, height: size);
        },
      ),
    );

    if (isDarkMode && showGlow) {
      // Dark mode'da glow efekti ekle
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius + 2),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: icon,
      );
    }

    return icon;
  }
}

/// AppBar'da kullanılacak küçük ikon versiyonu
class ThemedAppIconSmall extends StatelessWidget {
  const ThemedAppIconSmall({super.key, this.showGlow = false});

  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return ThemedAppIcon(size: 28, borderRadius: 6, showGlow: showGlow);
  }
}

/// Dialog ve kartlarda kullanılacak orta boy ikon versiyonu
class ThemedAppIconMedium extends StatelessWidget {
  const ThemedAppIconMedium({super.key, this.showGlow = false});

  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return ThemedAppIcon(size: 48, borderRadius: 8, showGlow: showGlow);
  }
}

/// Welcome dialog'da kullanılacak büyük ikon versiyonu
class ThemedAppIconLarge extends StatelessWidget {
  const ThemedAppIconLarge({super.key, this.showGlow = false});

  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return ThemedAppIcon(size: 64, borderRadius: 12, showGlow: showGlow);
  }
}
