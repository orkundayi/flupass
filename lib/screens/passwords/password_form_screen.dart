import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/credential.dart';
import '../../providers/credential_providers.dart';

class PasswordFormScreen extends ConsumerStatefulWidget {
  const PasswordFormScreen({super.key, this.initialCredential});

  final Credential? initialCredential;

  @override
  ConsumerState<PasswordFormScreen> createState() => _PasswordFormScreenState();
}

class _PasswordFormScreenState extends ConsumerState<PasswordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _websiteController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagController;

  // Focus nodes for better keyboard navigation
  final _titleFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _websiteFocus = FocusNode();
  final _notesFocus = FocusNode();

  bool _isFavorite = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  final List<String> _tags = <String>[];

  bool get _isEditing => widget.initialCredential != null;

  // Form değişiklik kontrolü için
  bool get _hasChanges {
    final credential = widget.initialCredential;
    if (credential == null) {
      // Yeni kayıt - herhangi bir alan dolduysa değişiklik var
      return _titleController.text.isNotEmpty ||
          _usernameController.text.isNotEmpty ||
          _passwordController.text.isNotEmpty ||
          _websiteController.text.isNotEmpty ||
          _notesController.text.isNotEmpty ||
          _tags.isNotEmpty ||
          _isFavorite;
    }
    // Düzenleme - orijinalle karşılaştır
    return _titleController.text.trim() != credential.title ||
        _usernameController.text.trim() != credential.username ||
        _passwordController.text != credential.password ||
        _websiteController.text.trim() != (credential.website ?? '') ||
        _notesController.text.trim() != (credential.notes ?? '') ||
        !_listEquals(_tags, credential.tags) ||
        _isFavorite != credential.isFavorite;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final credential = widget.initialCredential;
    _titleController = TextEditingController(text: credential?.title ?? '');
    _usernameController = TextEditingController(
      text: credential?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: credential?.password ?? '',
    );
    _websiteController = TextEditingController(text: credential?.website ?? '');
    _notesController = TextEditingController(text: credential?.notes ?? '');
    _tagController = TextEditingController();

    if (credential != null) {
      _tags.addAll(credential.tags);
      _isFavorite = credential.isFavorite;
    }

    // Listen for changes to trigger rebuild for _hasChanges
    _titleController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _websiteController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    // Trigger rebuild to update _hasChanges
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _usernameController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _websiteController.removeListener(_onFieldChanged);
    _notesController.removeListener(_onFieldChanged);

    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    _tagController.dispose();

    _titleFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _websiteFocus.dispose();
    _notesFocus.dispose();
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
          title: Text(_isEditing ? 'Şifreyi düzenle' : 'Yeni şifre'),
          centerTitle: true,
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Kaydı sil',
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
                  // Website Section - Öne çıkarıldı
                  _WebsiteSection(
                    controller: _websiteController,
                    focusNode: _websiteFocus,
                    onNext: () => _titleFocus.requestFocus(),
                  ),

                  const SizedBox(height: 24),

                  // Credentials Section
                  _buildSectionHeader(
                    icon: Icons.key_rounded,
                    title: 'Giriş Bilgileri',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),

                  _buildInputCard(
                    children: [
                      _buildInputField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        label: 'Başlık',
                        hint: 'Örn. GitHub, Netflix, Gmail',
                        icon: Icons.bookmark_outline,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _usernameFocus.requestFocus(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Başlık zorunludur';
                          }
                          return null;
                        },
                      ),
                      const _InputDivider(),
                      _buildInputField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        label: 'Kullanıcı adı veya e-posta',
                        hint: 'ornek@email.com',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Kullanıcı adı zorunludur';
                          }
                          return null;
                        },
                      ),
                      const _InputDivider(),
                      _buildPasswordField(),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Additional Info Section
                  _buildSectionHeader(
                    icon: Icons.info_outline,
                    title: 'Ek Bilgiler',
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),

                  _buildInputCard(
                    children: [
                      _buildInputField(
                        controller: _notesController,
                        focusNode: _notesFocus,
                        label: 'Notlar',
                        hint: 'Güvenlik soruları, ek bilgiler...',
                        icon: Icons.note_outlined,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tags
                  _TagSection(
                    controller: _tagController,
                    tags: _tags,
                    onTagAdded: _addTag,
                    onTagRemoved: _removeTag,
                  ),

                  const SizedBox(height: 16),

                  // Favorite Toggle
                  _buildFavoriteToggle(),

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
    List<String>? autofillHints,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      maxLines: maxLines,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(icon, size: 22),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorStyle: const TextStyle(height: 0.8),
      ),
    );
  }

  Widget _buildPasswordField() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _notesFocus.requestFocus(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Parola zorunludur';
            }
            if (value.length < 4) {
              return 'En az 4 karakter olmalı';
            }
            return null;
          },
          style: theme.textTheme.bodyLarge?.copyWith(
            letterSpacing: _obscurePassword ? 2 : 0,
          ),
          decoration: InputDecoration(
            labelText: 'Parola',
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline, size: 22),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  tooltip: _obscurePassword ? 'Göster' : 'Gizle',
                ),
                IconButton(
                  icon: const Icon(Icons.casino_outlined, size: 22),
                  onPressed: _generatePassword,
                  tooltip: 'Parola üret',
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            errorStyle: const TextStyle(height: 0.8),
          ),
        ),
        // Password strength indicator
        if (_passwordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PasswordStrengthIndicator(
              password: _passwordController.text,
            ),
          ),
      ],
    );
  }

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    final password = List.generate(
      16,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    _passwordController.text = password;
    setState(() => _obscurePassword = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Güçlü parola üretildi ✓'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFavoriteToggle() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFavorite
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _isFavorite = !_isFavorite),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isFavorite
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _isFavorite
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Favorilere ekle',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hızlı erişim için listenin başında göster',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isFavorite,
                  onChanged: (value) => setState(() => _isFavorite = value),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  _isEditing ? 'Değişiklikleri kaydet' : 'Şifreyi kaydet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(credentialListProvider.notifier);

    try {
      final now = DateTime.now();
      Credential credential;
      if (_isEditing) {
        final existing = widget.initialCredential!;
        credential = existing.copyWith(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          website: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          tags: List<String>.from(_tags),
          isFavorite: _isFavorite,
        );
        final success = await notifier.updateCredential(credential);
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kayıt güncellenemedi.')),
            );
          }
          return;
        }
      } else {
        credential = Credential(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          website: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          tags: List<String>.from(_tags),
          isFavorite: _isFavorite,
          createdAt: now,
          updatedAt: now,
        );
        final saved = await notifier.addCredential(credential);
        if (saved == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Kayıt eklenemedi.')));
          }
          return;
        }
        credential = saved;
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        PasswordFormResult(
          status: _isEditing
              ? PasswordFormStatus.updated
              : PasswordFormStatus.created,
          credential: credential,
        ),
      );
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
          title: const Text('Kaydı sil'),
          content: const Text(
            'Bu şifreyi kalıcı olarak silmek istediğinize emin misiniz?',
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
    final notifier = ref.read(credentialListProvider.notifier);

    try {
      final id = widget.initialCredential!.id;
      if (id == null) {
        return;
      }
      final deleted = await notifier.deleteCredential(id);
      if (deleted) {
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).pop(const PasswordFormResult(status: PasswordFormStatus.deleted));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kayıt silinemedi.')));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty) {
      return;
    }
    if (_tags.contains(tag)) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
    });
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }
}

// ===== Custom Widgets =====

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

class _WebsiteSection extends StatelessWidget {
  const _WebsiteSection({
    required this.controller,
    required this.focusNode,
    required this.onNext,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Web Sitesi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Autofill için önemli',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.url],
                onFieldSubmitted: (_) => onNext(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'örn: github.com, netflix.com',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Text(
                      'https://',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Doğru web sitesi adresi, şifrenin otomatik doldurulmasını sağlar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.controller,
    required this.tags,
    required this.onTagAdded,
    required this.onTagRemoved,
  });

  final TextEditingController controller;
  final List<String> tags;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.label_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Etiketler',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'İsteğe bağlı',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Etiket ekle...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: onTagAdded,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-Z0-9ğüşöçıİĞÜŞÖÇ\s-]"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onTagAdded(controller.text),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onTagRemoved(tag),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: theme.colorScheme.onSecondaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = _calculateStrength(password);
    final color = _getStrengthColor(context, strength);
    final label = _getStrengthLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _calculateStrength(String password) {
    if (password.isEmpty) return 0;

    double strength = 0;

    // Length score
    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.15;
    if (password.length >= 16) strength += 0.15;

    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.15;

    return strength.clamp(0.0, 1.0);
  }

  Color _getStrengthColor(BuildContext context, double strength) {
    final theme = Theme.of(context);
    if (strength < 0.3) return theme.colorScheme.error;
    if (strength < 0.5) return theme.colorScheme.error.withValues(alpha: 0.7);
    if (strength < 0.7) return theme.colorScheme.tertiary;
    if (strength < 0.9) return theme.colorScheme.primary.withValues(alpha: 0.8);
    return theme.colorScheme.primary;
  }

  String _getStrengthLabel(double strength) {
    if (strength < 0.3) return 'Çok zayıf';
    if (strength < 0.5) return 'Zayıf';
    if (strength < 0.7) return 'Orta';
    if (strength < 0.9) return 'Güçlü';
    return 'Çok güçlü';
  }
}

class PasswordFormResult {
  const PasswordFormResult({required this.status, this.credential});

  final PasswordFormStatus status;
  final Credential? credential;
}

enum PasswordFormStatus { created, updated, deleted }
