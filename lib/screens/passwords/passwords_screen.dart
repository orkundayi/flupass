import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/credential.dart';
import '../../providers/credential_providers.dart';
import 'password_form_screen.dart';

class PasswordsScreen extends ConsumerStatefulWidget {
  const PasswordsScreen({super.key});

  @override
  ConsumerState<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends ConsumerState<PasswordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showFavoritesOnly = false;
  String? _selectedTag;
  Set<String> _allTags = {};
  Timer? _debounce;

  // Cache için
  List<Credential>? _cachedItems;
  List<Credential>? _cachedFiltered;
  String? _cachedFilterKey;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(credentialListProvider.notifier).refresh();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credentialsAsync = ref.watch(credentialListProvider);

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
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.lock_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Şifrelerim'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showFavoritesOnly ? 'Tümünü göster' : 'Favoriler',
            icon: Icon(
              _showFavoritesOnly
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: _showFavoritesOnly
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
            },
          ),
        ],
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
                    hintText: 'Şifrelerde ara...',
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),

                  const SizedBox(height: 20),

                  // Content
                  credentialsAsync.when(
                    data: (items) {
                      // Tüm etiketleri topla
                      _allTags = items.expand((item) => item.tags).toSet();

                      // Seçili etiket artık mevcut değilse temizle
                      if (_selectedTag != null &&
                          !_allTags.contains(_selectedTag)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _selectedTag = null;
                            });
                          }
                        });
                      }

                      final filtered = _filterCredentials(items);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Row
                          _StatsRow(
                            total: items.length,
                            favorites: items.where((c) => c.isFavorite).length,
                            filtered: filtered.length,
                            isFiltered:
                                _query.isNotEmpty ||
                                _showFavoritesOnly ||
                                _selectedTag != null,
                          ),

                          const SizedBox(height: 20),

                          // Tag Filter
                          if (_allTags.isNotEmpty) ...[
                            _ModernTagFilter(
                              tags: _allTags.toList()..sort(),
                              selectedTag: _selectedTag,
                              onTagSelected: (tag) {
                                setState(() {
                                  _selectedTag = tag == _selectedTag
                                      ? null
                                      : tag;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                          ],

                          // List or Empty State
                          if (filtered.isEmpty)
                            _ModernEmptyState(
                              icon: Icons.lock_open_rounded,
                              title: 'Kayıt bulunamadı',
                              description:
                                  _query.isNotEmpty ||
                                      _showFavoritesOnly ||
                                      _selectedTag != null
                                  ? 'Filtreleri temizlemeyi deneyin'
                                  : 'İlk şifrenizi ekleyin',
                              actionLabel:
                                  _query.isEmpty &&
                                      !_showFavoritesOnly &&
                                      _selectedTag == null
                                  ? 'Şifre Ekle'
                                  : null,
                              onAction:
                                  _query.isEmpty &&
                                      !_showFavoritesOnly &&
                                      _selectedTag == null
                                  ? () => _openForm(context)
                                  : null,
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final credential = filtered[index];
                                return _ModernCredentialTile(
                                  credential: credential,
                                  onEdit: () => _openForm(
                                    context,
                                    credential: credential,
                                  ),
                                  onDelete: () =>
                                      _confirmDelete(context, credential),
                                  onToggleFavorite: (value) => ref
                                      .read(credentialListProvider.notifier)
                                      .toggleFavorite(credential.id!, value),
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
        label: const Text('Yeni Şifre'),
      ),
    );
  }

  List<Credential> _filterCredentials(List<Credential> items) {
    final listChanged = _cachedItems != items;
    final filterKey =
        '$_query|$_showFavoritesOnly|$_selectedTag|${items.length}';

    if (!listChanged &&
        _cachedFilterKey == filterKey &&
        _cachedFiltered != null) {
      return _cachedFiltered!;
    }

    final filtered = items.where((item) {
      if (_showFavoritesOnly && !item.isFavorite) return false;
      if (_selectedTag != null && !item.tags.contains(_selectedTag)) {
        return false;
      }
      if (_query.isEmpty) return true;

      final queryLower = _query.toLowerCase();
      return item.title.toLowerCase().contains(queryLower) ||
          item.username.toLowerCase().contains(queryLower) ||
          (item.website?.toLowerCase().contains(queryLower) ?? false) ||
          (item.notes?.toLowerCase().contains(queryLower) ?? false);
    }).toList();

    _cachedItems = items;
    _cachedFilterKey = filterKey;
    _cachedFiltered = filtered;

    return filtered;
  }

  Future<void> _openForm(BuildContext context, {Credential? credential}) async {
    final result = await Navigator.of(context).push<PasswordFormResult>(
      MaterialPageRoute(
        builder: (_) => PasswordFormScreen(initialCredential: credential),
      ),
    );

    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case PasswordFormStatus.created:
        messenger.showSnackBar(
          const SnackBar(content: Text('Yeni şifre kaydedildi.')),
        );
        break;
      case PasswordFormStatus.updated:
        messenger.showSnackBar(
          const SnackBar(content: Text('Şifre bilgileri güncellendi.')),
        );
        break;
      case PasswordFormStatus.deleted:
        messenger.showSnackBar(
          const SnackBar(content: Text('Şifre kaydı silindi.')),
        );
        break;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Credential credential,
  ) async {
    if (credential.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Şifreyi sil'),
          content: Text(
            '"${credential.title}" kaydını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final deleted = await ref
        .read(credentialListProvider.notifier)
        .deleteCredential(credential.id!);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Şifre kaydı silindi.'
              : 'Şifre silinirken bir sorun oluştu.',
        ),
      ),
    );
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
    required this.favorites,
    required this.filtered,
    required this.isFiltered,
  });

  final int total;
  final int favorites;
  final int filtered;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.lock_rounded,
            value: total.toString(),
            label: 'Toplam Şifre',
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            value: favorites.toString(),
            label: 'Favori',
            color: theme.colorScheme.tertiary,
            backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.1),
          ),
        ),
        if (isFiltered) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.filter_list_rounded,
              value: filtered.toString(),
              label: 'Sonuç',
              color: theme.colorScheme.secondary,
              backgroundColor: theme.colorScheme.secondary.withValues(
                alpha: 0.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ===== Modern Tag Filter =====

class _ModernTagFilter extends StatelessWidget {
  const _ModernTagFilter({
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
  });

  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Etiketler',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = tag == selectedTag;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTagSelected(tag),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ===== Modern Credential Tile =====

class _ModernCredentialTile extends StatefulWidget {
  const _ModernCredentialTile({
    required this.credential,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final Credential credential;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final ValueChanged<bool> onToggleFavorite;

  @override
  State<_ModernCredentialTile> createState() => _ModernCredentialTileState();
}

class _ModernCredentialTileState extends State<_ModernCredentialTile> {
  bool _isExpanded = false;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credential = widget.credential;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(20),
                bottom: Radius.circular(_isExpanded ? 0 : 20),
              ),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  credential.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (credential.isFavorite)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: theme.colorScheme.tertiary,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            credential.username.isEmpty
                                ? 'Kullanıcı adı yok'
                                : credential.username,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Expand Arrow
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded Content
          if (_isExpanded)
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Website
                    if (credential.website != null &&
                        credential.website!.isNotEmpty)
                      _InfoField(
                        icon: Icons.language_rounded,
                        label: 'Website',
                        value: credential.website!,
                        onCopy: () => _copyToClipboard(
                          credential.website!,
                          'Website kopyalandı',
                        ),
                      ),

                    // Username
                    _InfoField(
                      icon: Icons.person_outline_rounded,
                      label: 'Kullanıcı adı',
                      value: credential.username.isEmpty
                          ? '—'
                          : credential.username,
                      onCopy: credential.username.isNotEmpty
                          ? () => _copyToClipboard(
                              credential.username,
                              'Kullanıcı adı kopyalandı',
                            )
                          : null,
                    ),

                    // Password
                    _InfoField(
                      icon: Icons.key_rounded,
                      label: 'Şifre',
                      value: _showPassword ? credential.password : '••••••••',
                      isObfuscated: !_showPassword,
                      onCopy: () => _copyToClipboard(
                        credential.password,
                        'Şifre kopyalandı',
                      ),
                      onToggleVisibility: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),

                    // Notes
                    if (credential.notes != null &&
                        credential.notes!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.note_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Notlar',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              credential.notes!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    // Tags
                    if (credential.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: credential.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: widget.onEdit,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Düzenle'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.outlined(
                          tooltip: credential.isFavorite
                              ? 'Favorilerden çıkar'
                              : 'Favorilere ekle',
                          icon: Icon(
                            credential.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: credential.isFavorite
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () =>
                              widget.onToggleFavorite(!credential.isFavorite),
                        ),
                        IconButton.outlined(
                          tooltip: 'Sil',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}

// ===== Info Field =====

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.icon,
    required this.label,
    required this.value,
    this.isObfuscated = false,
    this.onCopy,
    this.onToggleVisibility,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isObfuscated;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    letterSpacing: isObfuscated ? 2 : null,
                    fontWeight: isObfuscated ? FontWeight.w600 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onToggleVisibility != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isObfuscated
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onToggleVisibility,
            ),
          if (onCopy != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.copy_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onCopy,
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
    final primaryColor = theme.colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(alpha: 0.08),
              primaryColor.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating decorative elements
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background floating icons
                  Positioned(
                    left: 20,
                    top: 0,
                    child: _FloatingIcon(
                      icon: Icons.key_rounded,
                      color: primaryColor.withValues(alpha: 0.2),
                      size: 24,
                    ),
                  ),
                  Positioned(
                    right: 30,
                    top: 10,
                    child: _FloatingIcon(
                      icon: Icons.shield_rounded,
                      color: primaryColor.withValues(alpha: 0.15),
                      size: 20,
                    ),
                  ),
                  Positioned(
                    left: 40,
                    bottom: 5,
                    child: _FloatingIcon(
                      icon: Icons.vpn_key_rounded,
                      color: primaryColor.withValues(alpha: 0.12),
                      size: 18,
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 0,
                    child: _FloatingIcon(
                      icon: Icons.security_rounded,
                      color: primaryColor.withValues(alpha: 0.18),
                      size: 22,
                    ),
                  ),
                  // Main icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 40, color: primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
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

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
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
              color: theme.colorScheme.primary,
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
