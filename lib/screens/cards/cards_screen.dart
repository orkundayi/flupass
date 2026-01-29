import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/security_verification_dialog.dart';
import '../../models/credit_card.dart';
import '../../providers/credit_card_providers.dart';
import '../../services/security_service.dart';
import 'card_form_screen.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(creditCardListProvider.notifier).refresh();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardsAsync = ref.watch(creditCardListProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.credit_card_rounded,
                color: theme.colorScheme.tertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Kartlarım'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Search Bar
                  _ModernSearchField(
                    controller: _searchController,
                    hintText: 'Kartlarda ara...',
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),

                  const SizedBox(height: 20),

                  // Content
                  cardsAsync.when(
                    data: (items) {
                      final filtered = _filterCards(items);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Row
                          _StatsRow(
                            total: items.length,
                            filtered: filtered.length,
                            isFiltered: _query.isNotEmpty,
                          ),

                          const SizedBox(height: 20),

                          // List or Empty State
                          if (filtered.isEmpty)
                            _ModernEmptyState(
                              icon: Icons.credit_card_off_rounded,
                              title: 'Kart bulunamadı',
                              description: _query.isNotEmpty
                                  ? 'Arama kriterlerini değiştirmeyi deneyin'
                                  : 'İlk kartınızı ekleyin',
                              actionLabel: _query.isEmpty ? 'Kart Ekle' : null,
                              onAction: _query.isEmpty
                                  ? () => _openForm(context)
                                  : null,
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final card = filtered[index];
                                return _CreditCardItem(
                                  card: card,
                                  onEdit: () => _openForm(context, card: card),
                                );
                              },
                            ),
                        ],
                      );
                    },
                    error: (error, _) => _ModernErrorState(
                      message: error.toString(),
                      onRetry: _refresh,
                    ),
                    loading: () => const _ModernLoadingState(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Kart'),
      ),
    );
  }

  List<CreditCard> _filterCards(List<CreditCard> items) {
    if (_query.isEmpty) return items;
    final queryLower = _query.toLowerCase();
    return items.where((card) {
      return card.cardHolderName.toLowerCase().contains(queryLower) ||
          card.cardNumber.contains(_query) ||
          (card.displayName?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }

  Future<void> _openForm(BuildContext context, {CreditCard? card}) async {
    final result = await Navigator.of(context).push<CardFormResult>(
      MaterialPageRoute(builder: (_) => CardFormScreen(initialCard: card)),
    );

    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case CardFormStatus.created:
        messenger.showSnackBar(
          const SnackBar(content: Text('Yeni kart kaydedildi.')),
        );
        break;
      case CardFormStatus.updated:
        messenger.showSnackBar(
          const SnackBar(content: Text('Kart bilgileri güncellendi.')),
        );
        break;
      case CardFormStatus.deleted:
        messenger.showSnackBar(
          const SnackBar(content: Text('Kart kaydı silindi.')),
        );
        break;
    }
  }
}

// ===== Modern Search Field =====

class _ModernSearchField extends StatelessWidget {
  const _ModernSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ===== Stats Row =====

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.filtered,
    required this.isFiltered,
  });

  final int total;
  final int filtered;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.credit_card_rounded,
            value: total.toString(),
            label: 'Toplam',
            color: theme.colorScheme.tertiary,
          ),
          if (isFiltered) ...[
            Container(
              width: 1,
              height: 40,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _StatItem(
              icon: Icons.filter_list_rounded,
              value: filtered.toString(),
              label: 'Sonuç',
              color: theme.colorScheme.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
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
        ],
      ),
    );
  }
}

// ===== Empty State =====

class _ModernEmptyState extends StatelessWidget {
  const _ModernEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: theme.colorScheme.tertiary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===== Loading State =====

class _ModernLoadingState extends StatelessWidget {
  const _ModernLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 16),
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

// ===== Error State =====

class _ModernErrorState extends StatelessWidget {
  const _ModernErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'Bir hata oluştu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
              side: BorderSide(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Credit Card Item =====

class _CreditCardItem extends ConsumerStatefulWidget {
  const _CreditCardItem({required this.card, required this.onEdit});

  final CreditCard card;
  final VoidCallback onEdit;

  @override
  ConsumerState<_CreditCardItem> createState() => _CreditCardItemState();
}

class _CreditCardItemState extends ConsumerState<_CreditCardItem>
    with SingleTickerProviderStateMixin {
  bool _isFrontVisible = true;
  bool _isShowingSensitiveData = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  Color _cardColor = const Color(0xFF1F4690);
  Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _updateCardColor();
    _isShowingSensitiveData = false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final securityState = ref.watch(securityControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Visual
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildSwipeableCard(),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Toggle Visibility
                Expanded(
                  child: _ModernActionButton(
                    icon: _isShowingSensitiveData
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    label: _isShowingSensitiveData ? 'Gizle' : 'Göster',
                    color: theme.colorScheme.primary,
                    showDot: securityState.isSecurityEnabled,
                    onPressed: _toggleSensitiveData,
                  ),
                ),
                const SizedBox(width: 8),
                // Flip Card
                Expanded(
                  child: _ModernActionButton(
                    icon: Icons.flip_rounded,
                    label: 'Çevir',
                    color: theme.colorScheme.secondary,
                    onPressed: _flipCard,
                  ),
                ),
                const SizedBox(width: 8),
                // Edit
                Expanded(
                  child: _ModernActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Düzenle',
                    color: theme.colorScheme.tertiary,
                    onPressed: _handleEdit,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete
                Expanded(
                  child: _ModernActionButton(
                    icon: Icons.delete_rounded,
                    label: 'Sil',
                    color: theme.colorScheme.error,
                    onPressed: _handleDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeableCard() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0 || details.primaryVelocity! < 0) {
            _flipCard();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          final frontVisible = _animation.value <= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _cardColor.withValues(alpha: 0.4),
                    spreadRadius: 1,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _cardColor,
                    Color.lerp(_cardColor, Colors.black, 0.25)!,
                  ],
                ),
              ),
              child: frontVisible
                  ? _buildFrontCard()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildBackCard(),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getBankName(),
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _getCardTypeLogo(),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.credit_card_outlined,
                  size: 32,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _isShowingSensitiveData
                ? () => _copyToClipboard(widget.card.cardNumber)
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatCardNumberDisplay(
                        widget.card.cardNumber,
                        _isShowingSensitiveData,
                      ),
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (_isShowingSensitiveData)
                    Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: _textColor.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KART SAHİBİ',
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _copyToClipboard(widget.card.cardHolderName),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.card.cardHolderName.toUpperCase(),
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: _textColor.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SON KULLANIM',
                    style: TextStyle(
                      color: _textColor.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _copyToClipboard(widget.card.expiryDate),
                    child: Row(
                      children: [
                        Text(
                          widget.card.expiryDate,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: _textColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(height: 40, color: Colors.black),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 70,
                      height: 20,
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      child: const Text(
                        '          ',
                        style: TextStyle(
                          color: Colors.black,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: _isShowingSensitiveData
                      ? () => _copyToClipboard(widget.card.cvv)
                      : null,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isShowingSensitiveData
                              ? widget.card.cvv
                              : _obfuscateCVV(widget.card.cvv),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isShowingSensitiveData) const SizedBox(width: 4),
                        if (_isShowingSensitiveData)
                          const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Colors.black54,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.centerRight,
            child: _getCardTypeLogo(),
          ),
        ),
      ],
    );
  }

  void _toggleSensitiveData() async {
    if (_isShowingSensitiveData) {
      setState(() => _isShowingSensitiveData = false);
      return;
    }

    final securityState = ref.read(securityControllerProvider);
    if (!securityState.isSecurityEnabled) {
      setState(() => _isShowingSensitiveData = true);
      return;
    }

    // Biyometrik doğrulamayı doğrudan çağır (inlineAuth: true ile lifecycle observer'ı bypass et)
    if (securityState.isBiometricEnabled) {
      try {
        final success = await ref
            .read(securityControllerProvider.notifier)
            .authenticateWithBiometrics(inlineAuth: true);

        if (!mounted) return;

        if (success) {
          setState(() => _isShowingSensitiveData = true);
        } else {
          // Biyometrik başarısız olursa PIN dialog'u göster
          if (securityState.isPinEnabled) {
            _showPinDialog();
          } else {
            _showErrorSnackBar('Biyometrik doğrulama başarısız oldu.');
          }
        }
      } catch (e) {
        if (!mounted) return;
        // Hata durumunda PIN'e geç
        if (securityState.isPinEnabled) {
          _showPinDialog();
        } else {
          _showErrorSnackBar('Doğrulama yapılamadı.');
        }
      }
    } else if (securityState.isPinEnabled) {
      _showPinDialog();
    }
  }

  void _showPinDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const SecurityVerificationDialog(
        title: "PIN ile Doğrulama",
        message: "Kart bilgilerini görüntülemek için PIN kodunuzu girin",
      ),
    );
    if (result == true && mounted) {
      setState(() => _isShowingSensitiveData = true);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _flipCard() {
    setState(() {
      _isFrontVisible = !_isFrontVisible;
      if (_isFrontVisible) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
    });
  }

  Future<void> _handleEdit() async {
    if (_isShowingSensitiveData) {
      widget.onEdit();
      return;
    }

    final securityState = ref.read(securityControllerProvider);
    if (!securityState.isSecurityEnabled) {
      widget.onEdit();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const SecurityVerificationDialog(
        title: 'Kart Bilgisi Düzenleme',
        message: 'Kart bilgilerini düzenlemek için kimliğinizi doğrulayın.',
      ),
    );

    if (result == true && mounted) {
      setState(() => _isShowingSensitiveData = true);
      widget.onEdit();
    }
  }

  Future<void> _handleDelete() async {
    final id = widget.card.id;
    if (id == null) return;

    final theme = Theme.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Kartı sil'),
              content: Text(
                '"${widget.card.displayName ?? widget.card.cardHolderName}" kartını silmek istediğinize emin misiniz?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Sil'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final notifier = ref.read(creditCardListProvider.notifier);
    final deleted = await notifier.deleteCard(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'Kart kaydı silindi.' : 'Kart silinemedi.'),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Panoya kopyalandı'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _updateCardColor() {
    final type = _getCardType(widget.card.cardNumber);
    switch (type) {
      case 'visa':
        _cardColor = const Color(0xFF172571);
        break;
      case 'mastercard':
        _cardColor = const Color(0xFF1A1F71);
        break;
      case 'amex':
        _cardColor = const Color(0xFF0F6EB3);
        break;
      case 'discover':
        _cardColor = const Color(0xFFEE6000);
        break;
      default:
        _cardColor = const Color(0xFF1F4690);
    }
    _textColor = Colors.white;
  }

  String _formatCardNumberDisplay(String cardNumber, bool showFull) {
    cardNumber = cardNumber.replaceAll(' ', '');
    if (showFull) {
      String formatted = '';
      for (int i = 0; i < cardNumber.length; i++) {
        if (i > 0 && i % 4 == 0) formatted += ' ';
        formatted += cardNumber[i];
      }
      return formatted;
    } else {
      if (cardNumber.length <= 8) {
        return cardNumber.replaceAll(RegExp(r'.'), '•');
      }
      final firstFour = cardNumber.substring(0, 4);
      final lastFour = cardNumber.substring(cardNumber.length - 4);
      final middleLength = cardNumber.length - 8;
      String maskedMiddle = '';
      for (int i = 0; i < middleLength; i++) {
        maskedMiddle += '•';
        if ((i + 4) % 4 == 3 && i < middleLength - 1) {
          maskedMiddle += ' ';
        }
      }
      return "$firstFour $maskedMiddle $lastFour";
    }
  }

  String _getCardType(String cardNumber) {
    cardNumber = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (cardNumber.isEmpty) return 'other';
    if (cardNumber.startsWith('4')) return 'visa';
    if ((cardNumber.startsWith(RegExp(r'5[1-5]'))) ||
        (cardNumber.length >= 4 &&
            int.tryParse(cardNumber.substring(0, 4))! >= 2221 &&
            int.tryParse(cardNumber.substring(0, 4))! <= 2720)) {
      return 'mastercard';
    }
    if (cardNumber.startsWith('34') || cardNumber.startsWith('37')) {
      return 'amex';
    }
    if (cardNumber.startsWith('6011') ||
        cardNumber.startsWith('65') ||
        cardNumber.startsWith(RegExp(r'64[4-9]')) ||
        (cardNumber.length >= 6 &&
            int.tryParse(cardNumber.substring(0, 6))! >= 622126 &&
            int.tryParse(cardNumber.substring(0, 6))! <= 622925)) {
      return 'discover';
    }
    return 'other';
  }

  Widget _getCardTypeLogo() {
    final cardType = _getCardType(widget.card.cardNumber);
    switch (cardType) {
      case 'visa':
        return Text(
          'VISA',
          style: TextStyle(
            color: _textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        );
      case 'mastercard':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      case 'amex':
        return Text(
          'AMEX',
          style: TextStyle(
            color: _textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        );
      case 'discover':
        return Text(
          'DISCOVER',
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      default:
        return Text(
          'CARD',
          style: TextStyle(
            color: _textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        );
    }
  }

  String _getBankName() {
    if (widget.card.displayName != null &&
        widget.card.displayName!.isNotEmpty) {
      return widget.card.displayName!.toUpperCase();
    }
    switch (_getCardType(widget.card.cardNumber)) {
      case 'visa':
      case 'mastercard':
        return 'BANKA';
      case 'amex':
        return 'AMERICAN EXPRESS';
      case 'discover':
        return 'DISCOVER';
      default:
        return 'BANKA';
    }
  }

  String _obfuscateCVV(String cvv) => '*' * cvv.length;
}

// ===== Modern Action Button =====

class _ModernActionButton extends StatelessWidget {
  const _ModernActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (showDot)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
