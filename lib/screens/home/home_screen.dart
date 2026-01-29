import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/credential_providers.dart';
import '../../providers/credit_card_providers.dart';
import '../../services/security_service.dart';
import '../../widgets/themed_app_icon.dart';
import '../cards/cards_screen.dart';
import '../passwords/passwords_screen.dart';
import '../passwords/password_form_screen.dart';
import '../cards/card_form_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/welcome_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isFabOpen = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );

    // İlk açılışta hoş geldiniz dialog'unu göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialogIfNeeded();
    });
  }

  Future<void> _showWelcomeDialogIfNeeded() async {
    await WelcomeDialog.show(context);
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(credentialListProvider.notifier).refresh(),
      ref.read(creditCardListProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credentialsValue = ref.watch(credentialListProvider);
    final creditCardsValue = ref.watch(creditCardListProvider);
    final securityState = ref.watch(securityControllerProvider);

    final credentialCount = credentialsValue.maybeWhen(
      data: (data) => data.length,
      orElse: () => 0,
    );

    final favoriteCount = credentialsValue.maybeWhen(
      data: (data) => data.where((item) => item.isFavorite).length,
      orElse: () => 0,
    );

    final creditCardCount = creditCardsValue.maybeWhen(
      data: (data) => data.length,
      orElse: () => 0,
    );

    final isSecurityActive =
        securityState.isBiometricEnabled || securityState.isPinEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: const ThemedAppIconSmall(showGlow: true),
            ),
            const SizedBox(width: 12),
            Text(
              'FluPass',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Tema değiştir',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                ref.watch(themeControllerProvider).isDarkMode(context)
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                size: 20,
              ),
            ),
            onPressed: () {
              ref.read(themeControllerProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_outlined, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                // Security Warning Banner
                if (!isSecurityActive) ...[
                  _SecurityWarningBanner(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Stats Cards
                _StatsSection(
                  credentialCount: credentialCount,
                  favoriteCount: favoriteCount,
                  creditCardCount: creditCardCount,
                  isSecurityActive: isSecurityActive,
                  securityState: securityState,
                ),

                const SizedBox(height: 28),

                // Quick Actions
                _QuickActionsSection(
                  onPasswordsTap: () => _openPasswords(context),
                  onCardsTap: () => _openCards(context),
                  onAddPasswordTap: () => _openAddPassword(context),
                  onAddCardTap: () => _openAddCard(context),
                ),

                const SizedBox(height: 28),

                // Recent Passwords
                credentialsValue.when(
                  data: (items) => _RecentSection(
                    title: 'Son Şifreler',
                    icon: Icons.lock_outline,
                    emptyMessage: 'Henüz şifre eklemediniz',
                    emptyIcon: Icons.add_circle_outline,
                    onEmptyTap: () => _openAddPassword(context),
                    items: items.take(4).map((credential) {
                      return _RecentItem(
                        title: credential.title,
                        subtitle: credential.username,
                        isFavorite: credential.isFavorite,
                      );
                    }).toList(),
                    onViewAllTap: () => _openPasswords(context),
                    onItemTap: (index) => _openPasswords(context),
                  ),
                  loading: () => const _SectionLoader(),
                  error: (error, _) => _SectionError(message: error.toString()),
                ),

                const SizedBox(height: 24),

                // Recent Cards
                creditCardsValue.when(
                  data: (items) => _RecentSection(
                    title: 'Son Kartlar',
                    icon: Icons.credit_card_outlined,
                    emptyMessage: 'Henüz kart eklemediniz',
                    emptyIcon: Icons.add_card,
                    onEmptyTap: () => _openAddCard(context),
                    items: items.take(3).map((card) {
                      final masked = card.cardNumber.length >= 4
                          ? '•••• ${card.cardNumber.substring(card.cardNumber.length - 4)}'
                          : card.cardNumber;
                      return _RecentItem(
                        title: card.displayName ?? card.cardHolderName,
                        subtitle: masked,
                        isFavorite: false,
                      );
                    }).toList(),
                    onViewAllTap: () => _openCards(context),
                    onItemTap: (index) => _openCards(context),
                  ),
                  loading: () => const _SectionLoader(),
                  error: (error, _) => _SectionError(message: error.toString()),
                ),
              ],
            ),
          ),

          // FAB Overlay
          if (_isFabOpen)
            GestureDetector(
              onTap: _toggleFab,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildFab(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs
        if (_isFabOpen) ...[
          // Add Card
          ScaleTransition(
            scale: _fabAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Kart ekle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    heroTag: 'card',
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    onPressed: () {
                      _toggleFab();
                      _openAddCard(context);
                    },
                    child: const Icon(Icons.credit_card),
                  ),
                ],
              ),
            ),
          ),
          // Add Password
          ScaleTransition(
            scale: _fabAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Şifre ekle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    heroTag: 'password',
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    onPressed: () {
                      _toggleFab();
                      _openAddPassword(context);
                    },
                    child: const Icon(Icons.lock_outline),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: _isFabOpen
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primary,
          foregroundColor: _isFabOpen
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onPrimary,
          child: AnimatedRotation(
            turns: _isFabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isFabOpen ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }

  void _openPasswords(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PasswordsScreen()));
  }

  void _openCards(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CardsScreen()));
  }

  void _openAddPassword(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PasswordFormScreen()));
  }

  void _openAddCard(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CardFormScreen()));
  }
}

// ===== Security Warning Banner =====

class _SecurityWarningBanner extends StatelessWidget {
  const _SecurityWarningBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Koyu ve açık temada iyi görünen sabit renkler
    final warningRed = isDark
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFDC3545);
    final bgColor = isDark ? const Color(0xFF2D1F1F) : const Color(0xFFFEECEC);
    final borderColor = isDark
        ? const Color(0xFF5C3333)
        : const Color(0xFFFFCDD2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: warningRed.withValues(alpha: isDark ? 0.2 : 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Animasyonlu uyarı ikonu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [warningRed, warningRed.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: warningRed.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: warningRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Güvenlik Aktif Değil',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: warningRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verilerinizi korumak için biyometrik veya PIN etkinleştirin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white70
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warningRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: warningRed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Stats Section =====

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.credentialCount,
    required this.favoriteCount,
    required this.creditCardCount,
    required this.isSecurityActive,
    required this.securityState,
  });

  final int credentialCount;
  final int favoriteCount;
  final int creditCardCount;
  final bool isSecurityActive;
  final SecurityState securityState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting
        Text(
          _getGreeting(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isSecurityActive ? Icons.verified_user : Icons.shield_outlined,
              size: 16,
              color: isSecurityActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 6),
            Text(
              isSecurityActive
                  ? (securityState.isBiometricEnabled
                        ? 'Biyometrik ile korunuyor'
                        : 'PIN ile korunuyor')
                  : 'Koruma aktif değil',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSecurityActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Stats Row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.star_rounded,
                value: favoriteCount,
                label: 'Favori',
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.lock_outline,
                value: credentialCount,
                label: 'Şifre',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.credit_card,
                value: creditCardCount,
                label: 'Kart',
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi geceler';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Quick Actions Section =====

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.onPasswordsTap,
    required this.onCardsTap,
    required this.onAddPasswordTap,
    required this.onAddCardTap,
  });

  final VoidCallback onPasswordsTap;
  final VoidCallback onCardsTap;
  final VoidCallback onAddPasswordTap;
  final VoidCallback onAddCardTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı Erişim',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                icon: Icons.lock_outline,
                label: 'Şifreler',
                color: theme.colorScheme.primary,
                onTap: onPasswordsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.credit_card,
                label: 'Kartlar',
                color: theme.colorScheme.secondary,
                onTap: onCardsTap,
              ),
            ),
            /* const SizedBox(width: 12),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.add,
                label: 'Ekle',
                color: theme.colorScheme.tertiary,
                onTap: onAddPasswordTap,
              ),
            ), */
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Recent Section =====

class _RecentItem {
  final String title;
  final String subtitle;
  final bool isFavorite;

  _RecentItem({
    required this.title,
    required this.subtitle,
    this.isFavorite = false,
  });
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onEmptyTap,
    required this.items,
    required this.onViewAllTap,
    required this.onItemTap,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback onEmptyTap;
  final List<_RecentItem> items;
  final VoidCallback onViewAllTap;
  final void Function(int index) onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              TextButton(
                onPressed: onViewAllTap,
                child: const Text('Tümünü gör'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _EmptyStateCard(
            message: emptyMessage,
            icon: emptyIcon,
            onTap: onEmptyTap,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;

                return Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onItemTap(index),
                        borderRadius: BorderRadius.vertical(
                          top: index == 0
                              ? const Radius.circular(16)
                              : Radius.zero,
                          bottom: isLast
                              ? const Radius.circular(16)
                              : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  icon,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (item.isFavorite)
                                          Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.message,
    required this.icon,
    required this.onTap,
  });

  final String message;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Loaders & Errors =====

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Yükleniyor...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
