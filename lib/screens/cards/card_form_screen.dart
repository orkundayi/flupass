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

  bool _isSubmitting = false;
  bool _isDeleting = false;
  late final List<TextEditingController> _previewControllers;

  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isCvvFocused = false;
  Color _cardColor = const Color(0xFF1F4690);
  Color _textColor = Colors.white;

  bool get _isEditing => widget.initialCard != null;

  static final _cardNumberFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
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

    _previewControllers = [
      _titleController,
      _holderController,
      _numberController,
      _expiryController,
      _cvvController,
    ];
    for (final controller in _previewControllers) {
      controller.addListener(_onPreviewChanged);
    }

    _numberController.addListener(_updateCardColor);
    _updateCardColor();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final controller in _previewControllers) {
      controller.removeListener(_onPreviewChanged);
    }
    _titleController.dispose();
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Kartı düzenle' : 'Kart ekle'),
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
                  : const Icon(Icons.delete_outline),
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              _buildPreview(theme),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Kart bilgileri',
                children: [
                  _buildField(
                    controller: _titleController,
                    label: 'Kart adı (isteğe bağlı)',
                    hintText: 'Örn. İş kartı',
                    textInputAction: TextInputAction.next,
                    onTap: _flipToFront,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _holderController,
                    label: 'Kart sahibi',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kart sahibi adı zorunludur';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-ZğüşöçıİĞÜŞÖÇ\s]"),
                      ),
                    ],
                    onTap: _flipToFront,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _numberController,
                    label: 'Kart numarası',
                    hintText: '0000 0000 0000 0000',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final digits =
                          value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                      if (digits.length < 12) {
                        return 'Geçerli bir kart numarası girin';
                      }
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _cardNumberFormatter,
                    ],
                    onTap: _flipToFront,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _expiryController,
                          label: 'SKT (AA/YY)',
                          hintText: '12/28',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Son kullanma tarihi zorunludur';
                            }
                            final parts = value.split('/');
                            if (parts.length != 2) {
                              return 'Geçerli bir tarih girin';
                            }
                            final month = int.tryParse(parts[0]);
                            final year = int.tryParse(parts[1]);
                            if (month == null || month < 1 || month > 12) {
                              return 'Ay 01-12 aralığında olmalı';
                            }
                            if (year == null || year < 0) {
                              return 'Yılı kontrol edin';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _expiryFormatter,
                          ],
                          onTap: _flipToFront,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildField(
                          controller: _cvvController,
                          label: 'CVV',
                          hintText: '123',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'CVV zorunludur';
                            }
                            if (value.trim().length < 3) {
                              return 'CVV 3 veya 4 haneli olmalıdır';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onTap: () {
                            setState(() {
                              _isCvvFocused = true;
                              _animationController.forward();
                            });
                          },
                          onEditingComplete: () {
                            setState(() {
                              _isCvvFocused = false;
                              _animationController.reverse();
                            });
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSubmitting ? 'Kaydediliyor...' : 'Kaydet'),
                onPressed: _isSubmitting ? null : _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canlı önizleme',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (_isCvvFocused) {
              setState(() {
                _isCvvFocused = false;
                _animationController.reverse();
              });
            } else {
              setState(() {
                _isCvvFocused = true;
                _animationController.forward();
              });
            }
          },
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value * 3.14159265359;
              final frontVisible = _animation.value <= 0.5;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _cardColor,
                        Color.lerp(_cardColor, Colors.black, 0.2)!,
                      ],
                    ),
                  ),
                  child: frontVisible
                      ? _buildFrontCard()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(3.14159265359),
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
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.credit_card_outlined,
                  size: 32,
                  color: _textColor,
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
                        color: _textColor,
                        fontSize: 12,
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
                        fontSize: 16,
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
                      color: _textColor,
                      fontSize: 12,
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
                      fontSize: 16,
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
                    _cvvController.text.isEmpty ? '***' : _cvvController.text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTap,
    VoidCallback? onEditingComplete,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _updateCardColor() {
    final cardType = _getCardType(_numberController.text);
    switch (cardType) {
      case CardType.visa:
        _cardColor = const Color(0xFF172571);
        _textColor = Colors.white;
        break;
      case CardType.mastercard:
        _cardColor = const Color(0xFF444444);
        _textColor = Colors.white;
        break;
      case CardType.amex:
        _cardColor = const Color(0xFF0F6EB3);
        _textColor = Colors.white;
        break;
      case CardType.discover:
        _cardColor = const Color(0xFFEE6000);
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
            int.tryParse(cardNumber.substring(0, 4))! >= 2221 &&
            int.tryParse(cardNumber.substring(0, 4))! <= 2720)) {
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
            int.tryParse(cardNumber.substring(0, 6))! >= 622126 &&
            int.tryParse(cardNumber.substring(0, 6))! <= 622925)) {
      return CardType.discover;
    } else if (cardNumber.length >= 13 && cardNumber.length <= 19) {
      return CardType.other;
    }

    return CardType.invalid;
  }

  Widget _getCardTypeLogo() {
    final cardType = _getCardType(_numberController.text);
    switch (cardType) {
      case CardType.visa:
        return const Text(
          'VISA',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      case CardType.mastercard:
        return const Text(
          'MasterCard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      case CardType.amex:
        return const Text(
          'AMEX',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      case CardType.discover:
        return const Text(
          'DISCOVER',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      default:
        return const Text(
          'CARD',
          style: TextStyle(
            fontSize: 22,
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
        return 'BANKA';
      case CardType.mastercard:
        return 'BANKA';
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

  void _onPreviewChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
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
        cardHolderName: _holderController.text.trim(),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kartı sil'),
          content: const Text(
            'Bu kart kaydını silmek istediğinize emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
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
