import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/credit_card.dart';
import '../../providers/credit_card_providers.dart';

class CardFormScreen extends ConsumerStatefulWidget {
  const CardFormScreen({super.key, this.initialCard});

  final CreditCard? initialCard;

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _holderController;
  late final TextEditingController _numberController;
  late final TextEditingController _expiryController;
  late final TextEditingController _cvvController;

  // Focus nodes for better keyboard navigation
  final _titleFocus = FocusNode();
  final _holderFocus = FocusNode();
  final _numberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();

  bool _isSubmitting = false;
  bool _isDeleting = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isCvvFocused = false;
  Color _cardColor = const Color(0xFF1F4690);
  Color _textColor = Colors.white;

  bool get _isEditing => widget.initialCard != null;

  // Form değişiklik kontrolü için
  bool get _hasChanges {
    final card = widget.initialCard;
    if (card == null) {
      // Yeni kayıt - herhangi bir alan dolduysa değişiklik var
      return _titleController.text.isNotEmpty ||
          _holderController.text.isNotEmpty ||
          _numberController.text.isNotEmpty ||
          _expiryController.text.isNotEmpty ||
          _cvvController.text.isNotEmpty;
    }
    // Düzenleme - orijinalle karşılaştır
    final sanitizedOriginalNumber = card.cardNumber.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final sanitizedCurrentNumber = _numberController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return _titleController.text.trim() != (card.displayName ?? '') ||
        _holderController.text.trim() != card.cardHolderName ||
        sanitizedCurrentNumber != sanitizedOriginalNumber ||
        _expiryController.text.trim() != card.expiryDate ||
        _cvvController.text.trim() != card.cvv;
  }

  static final _cardNumberFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Limit to 19 digits (max card number length)
    final limited = digitsOnly.length > 19
        ? digitsOnly.substring(0, 19)
        : digitsOnly;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  });

  static final _expiryFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    var text = digitsOnly;
    if (digitsOnly.length > 4) {
      text = digitsOnly.substring(0, 4);
    }
    if (text.length >= 3) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });

  @override
  void initState() {
    super.initState();
    final card = widget.initialCard;
    _titleController = TextEditingController(text: card?.displayName ?? '');
    _holderController = TextEditingController(text: card?.cardHolderName ?? '');
    _numberController = TextEditingController(
      text: card != null ? _formatCardNumber(card.cardNumber) : '',
    );
    _expiryController = TextEditingController(text: card?.expiryDate ?? '');
    _cvvController = TextEditingController(text: card?.cvv ?? '');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Listen for changes to trigger rebuild for _hasChanges
    _titleController.addListener(_onFieldChanged);
    _holderController.addListener(_onFieldChanged);
    _numberController.addListener(_onFieldChanged);
    _expiryController.addListener(_onFieldChanged);
    _cvvController.addListener(_onFieldChanged);

    _numberController.addListener(_updateCardColor);
    _updateCardColor();
  }

  void _onFieldChanged() {
    // Trigger rebuild to update _hasChanges
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.removeListener(_onFieldChanged);
    _holderController.removeListener(_onFieldChanged);
    _numberController.removeListener(_onFieldChanged);
    _expiryController.removeListener(_onFieldChanged);
    _cvvController.removeListener(_onFieldChanged);

    _titleController.dispose();
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();

    _titleFocus.dispose();
    _holderFocus.dispose();
    _numberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_isSubmitting || _isDeleting) return false;
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48),
        title: const Text('Değişiklikleri kaydetmediniz'),
        content: const Text(
          'Kaydedilmemiş değişiklikleriniz var. Çıkmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Düzenlemeye devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Kaydetmeden çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges && !_isSubmitting && !_isDeleting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isEditing ? Icons.edit_rounded : Icons.add_card_rounded,
                  color: theme.colorScheme.tertiary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(_isEditing ? 'Kartı düzenle' : 'Yeni kart'),
            ],
          ),
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Kartı sil',
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                onPressed: _isDeleting ? null : _confirmDelete,
              ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // Card Preview
                  _buildPreview(theme),

                  const SizedBox(height: 24),

                  // Card Name Section
                  _buildSectionHeader(
                    icon: Icons.label_outline,
                    title: 'Kart Adı',
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),

                  _buildInputCard(
                    children: [
                      _buildInputField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        label: 'Kart adı (isteğe bağlı)',
                        hint: 'Örn. İş kartı, Bonus, Maximum',
                        icon: Icons.credit_card_rounded,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _holderFocus.requestFocus(),
                        onTap: _flipToFront,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Card Details Section
                  _buildSectionHeader(
                    icon: Icons.credit_card_rounded,
                    title: 'Kart Bilgileri',
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 12),

                  _buildInputCard(
                    children: [
                      _buildInputField(
                        controller: _holderController,
                        focusNode: _holderFocus,
                        label: 'Kart sahibi',
                        hint: 'AD SOYAD',
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZğüşöçıİĞÜŞÖÇ\s]"),
                          ),
                          LengthLimitingTextInputFormatter(50),
                        ],
                        onSubmitted: (_) => _numberFocus.requestFocus(),
                        onTap: _flipToFront,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Kart sahibi adı zorunludur';
                          }
                          if (value.trim().length < 3) {
                            return 'En az 3 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const _InputDivider(),
                      _buildInputField(
                        controller: _numberController,
                        focusNode: _numberFocus,
                        label: 'Kart numarası',
                        hint: '0000 0000 0000 0000',
                        icon: Icons.dialpad_rounded,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _cardNumberFormatter,
                        ],
                        onSubmitted: (_) => _expiryFocus.requestFocus(),
                        onTap: _flipToFront,
                        validator: (value) {
                          final digits =
                              value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                          if (digits.isEmpty) {
                            return 'Kart numarası zorunludur';
                          }
                          if (digits.length < 13) {
                            return 'En az 13 haneli olmalı';
                          }
                          if (digits.length > 19) {
                            return 'En fazla 19 haneli olabilir';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Expiry and CVV Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInputCard(
                          children: [
                            _buildInputField(
                              controller: _expiryController,
                              focusNode: _expiryFocus,
                              label: 'Son kullanma',
                              hint: 'AA/YY',
                              icon: Icons.calendar_today_rounded,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _expiryFormatter,
                              ],
                              onSubmitted: (_) {
                                _cvvFocus.requestFocus();
                                _flipToBack();
                              },
                              onTap: _flipToFront,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'SKT zorunludur';
                                }
                                final parts = value.split('/');
                                if (parts.length != 2) {
                                  return 'AA/YY formatında olmalı';
                                }
                                final month = int.tryParse(parts[0]);
                                final year = int.tryParse(parts[1]);
                                if (month == null || month < 1 || month > 12) {
                                  return 'Ay 01-12 olmalı';
                                }
                                if (year == null) {
                                  return 'Yıl geçersiz';
                                }
                                // Check if card is expired
                                final now = DateTime.now();
                                final currentYear = now.year % 100;
                                final currentMonth = now.month;
                                if (year < currentYear ||
                                    (year == currentYear &&
                                        month < currentMonth)) {
                                  return 'Kartın süresi dolmuş';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInputCard(
                          children: [
                            _buildInputField(
                              controller: _cvvController,
                              focusNode: _cvvFocus,
                              label: 'CVV',
                              hint: '•••',
                              icon: Icons.lock_outline,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              onTap: _flipToBack,
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                                _flipToFront();
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'CVV zorunludur';
                                }
                                final cardType = _getCardType(
                                  _numberController.text,
                                );
                                // AMEX uses 4 digit CVV, others use 3
                                final requiredLength = cardType == CardType.amex
                                    ? 4
                                    : 3;
                                if (value.trim().length < requiredLength) {
                                  return '$requiredLength haneli olmalı';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  _buildSaveButton(),

                  // Spacer for keyboard
                  SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 200
                        : 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(icon, size: 22),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorStyle: const TextStyle(height: 0.8),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.visibility_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Canlı önizleme',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                if (_isCvvFocused) {
                  _flipToFront();
                } else {
                  _flipToBack();
                }
              },
              icon: const Icon(Icons.flip_rounded, size: 18),
              label: Text(_isCvvFocused ? 'Ön yüz' : 'Arka yüz'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity!.abs() > 100) {
              if (_isCvvFocused) {
                _flipToFront();
              } else {
                _flipToBack();
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
                  margin: const EdgeInsets.symmetric(horizontal: 8),
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
        ),
      ],
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
                _titleController.text.isNotEmpty
                    ? _titleController.text.toUpperCase()
                    : _getCardBankName(),
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
          Text(
            _numberController.text.isEmpty
                ? '•••• •••• •••• ••••'
                : _numberController.text,
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
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
                    Text(
                      _holderController.text.isNotEmpty
                          ? _holderController.text.toUpperCase()
                          : 'AD SOYAD',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
                  Text(
                    _expiryController.text.isNotEmpty
                        ? _expiryController.text
                        : 'AA/YY',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _cvvController.text.isEmpty ? '•••' : _cvvController.text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildSaveButton() {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: _isSubmitting ? null : _handleSubmit,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isSubmitting
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Değişiklikleri kaydet' : 'Kartı kaydet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  void _updateCardColor() {
    final cardType = _getCardType(_numberController.text);
    switch (cardType) {
      case CardType.visa:
        _cardColor = const Color(0xFF1A1F71);
        _textColor = Colors.white;
        break;
      case CardType.mastercard:
        _cardColor = const Color(0xFF2B2B2B);
        _textColor = Colors.white;
        break;
      case CardType.amex:
        _cardColor = const Color(0xFF006FCF);
        _textColor = Colors.white;
        break;
      case CardType.discover:
        _cardColor = const Color(0xFFFF6600);
        _textColor = Colors.white;
        break;
      default:
        _cardColor = const Color(0xFF1F4690);
        _textColor = Colors.white;
    }
    if (mounted) {
      setState(() {});
    }
  }

  CardType _getCardType(String cardNumber) {
    cardNumber = cardNumber.replaceAll(RegExp(r'\s|-'), '');

    if (cardNumber.isEmpty) {
      return CardType.other;
    }

    if (cardNumber.startsWith('4')) {
      return CardType.visa;
    } else if ((cardNumber.startsWith(RegExp(r'5[1-5]'))) ||
        (cardNumber.length >= 4 &&
            int.tryParse(cardNumber.substring(0, 4)) != null &&
            int.parse(cardNumber.substring(0, 4)) >= 2221 &&
            int.parse(cardNumber.substring(0, 4)) <= 2720)) {
      return CardType.mastercard;
    } else if (cardNumber.startsWith('34') || cardNumber.startsWith('37')) {
      return CardType.amex;
    } else if (cardNumber.startsWith('6011') ||
        cardNumber.startsWith('65') ||
        (cardNumber.startsWith('644') ||
            cardNumber.startsWith('645') ||
            cardNumber.startsWith('646') ||
            cardNumber.startsWith('647') ||
            cardNumber.startsWith('648') ||
            cardNumber.startsWith('649')) ||
        (cardNumber.length >= 6 &&
            int.tryParse(cardNumber.substring(0, 6)) != null &&
            int.parse(cardNumber.substring(0, 6)) >= 622126 &&
            int.parse(cardNumber.substring(0, 6)) <= 622925)) {
      return CardType.discover;
    }

    return CardType.other;
  }

  Widget _getCardTypeLogo() {
    final cardType = _getCardType(_numberController.text);
    switch (cardType) {
      case CardType.visa:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'VISA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F71),
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case CardType.mastercard:
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
      case CardType.amex:
        return const Text(
          'AMEX',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      case CardType.discover:
        return const Text(
          'DISCOVER',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      default:
        return const Text(
          'CARD',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
    }
  }

  String _getCardBankName() {
    final cardType = _getCardType(_numberController.text);
    switch (cardType) {
      case CardType.visa:
        return 'VISA';
      case CardType.mastercard:
        return 'MASTERCARD';
      case CardType.amex:
        return 'AMERICAN EXPRESS';
      case CardType.discover:
        return 'DISCOVER';
      default:
        return 'BANKA';
    }
  }

  void _flipToFront() {
    if (_isCvvFocused) {
      setState(() {
        _isCvvFocused = false;
        _animationController.reverse();
      });
    }
  }

  void _flipToBack() {
    if (!_isCvvFocused) {
      setState(() {
        _isCvvFocused = true;
        _animationController.forward();
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(creditCardListProvider.notifier);

    try {
      final sanitizedNumber = _numberController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final card = CreditCard(
        id: widget.initialCard?.id,
        displayName: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        cardHolderName: _holderController.text.trim().toUpperCase(),
        cardNumber: sanitizedNumber,
        expiryDate: _expiryController.text.trim(),
        cvv: _cvvController.text.trim(),
      );

      if (_isEditing) {
        final success = await notifier.updateCard(card);
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kart güncellenemedi.')),
            );
          }
          return;
        }
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).pop(CardFormResult(status: CardFormStatus.updated, card: card));
      } else {
        final saved = await notifier.addCard(card);
        if (saved == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Kart eklenemedi.')));
          }
          return;
        }
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).pop(CardFormResult(status: CardFormStatus.created, card: saved));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),
          title: const Text('Kartı sil'),
          content: const Text(
            'Bu kart kaydını kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isDeleting = true);
    final notifier = ref.read(creditCardListProvider.notifier);

    try {
      final id = widget.initialCard?.id;
      if (id == null) {
        return;
      }
      final deleted = await notifier.deleteCard(id);
      if (deleted) {
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).pop(const CardFormResult(status: CardFormStatus.deleted));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kart silinemedi.')));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  String _formatCardNumber(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }
    return buffer.toString();
  }
}

class _InputDivider extends StatelessWidget {
  const _InputDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}

enum CardType { visa, mastercard, amex, discover, other, invalid }

class CardFormResult {
  const CardFormResult({required this.status, this.card});

  final CardFormStatus status;
  final CreditCard? card;
}

enum CardFormStatus { created, updated, deleted }
