import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  static const _welcomeShownKey = 'welcome_dialog_shown';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_welcomeShownKey) ?? false);
  }

  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeShownKey, true);
  }

  static Future<void> show(BuildContext context) async {
    final shouldShowDialog = await shouldShow();
    if (!shouldShowDialog || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const WelcomeDialog(),
    );

    await markAsShown();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/appicon/flupass.png',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FluPass\'a Hoş Geldiniz!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Güvenli ve gizlilik odaklı şifre yöneticiniz',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _FeatureItem(
                      icon: Icons.phone_android_rounded,
                      iconColor: theme.colorScheme.primary,
                      title: '100% Yerel Depolama',
                      description:
                          'Tüm verileriniz yalnızca cihazınızda saklanır. Sunucularımıza hiçbir veri gönderilmez.',
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.lock_rounded,
                      iconColor: theme.colorScheme.tertiary,
                      title: 'Güçlü Şifreleme',
                      description:
                          'Şifreleriniz AES-256 endüstri standardı şifreleme ile korunur.',
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.wifi_off_rounded,
                      iconColor: theme.colorScheme.secondary,
                      title: 'İnternet Gerektirmez',
                      description:
                          'Uçak modunda bile çalışır. İnternet bağlantısı olmadan tüm şifrelerinize erişin.',
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.fingerprint_rounded,
                      iconColor: theme.colorScheme.error,
                      title: 'Biyometrik Koruma',
                      description:
                          'Face ID, Touch ID veya PIN ile şifrelerinizi koruyun.',
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.visibility_off_rounded,
                      iconColor: Colors.deepPurple,
                      title: 'Gizlilik Öncelikli',
                      description:
                          'Analitik yok, takip yok, reklam yok. Verileriniz sadece sizin.',
                    ),
                  ],
                ),
              ),
            ),

            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Başlayalım',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
