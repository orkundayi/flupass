import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_providers.dart';
import '../../providers/credential_providers.dart';
import '../../services/security_overlay_service.dart';
import '../../services/security_service.dart';
import '../../widgets/themed_app_icon.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isPinBusy = false;
  bool _isBiometricBusy = false;
  bool _isExportBusy = false;
  bool _isImportBusy = false;
  bool _isAutofillSettingsBusy = false;

  // Güvenlik bölümüne scroll için
  final _scrollController = ScrollController();
  final _securitySectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSecuritySection() {
    final context = _securitySectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // iOS için parola ayarlarını doğrudan açan method channel
  static const _autofillChannel = MethodChannel('com.flutech.flupass/autofill');

  Future<void> _openPasswordSettings() async {
    setState(() => _isAutofillSettingsBusy = true);

    try {
      final platform = Theme.of(context).platform;
      final isIOS = platform == TargetPlatform.iOS;

      if (isIOS) {
        // iOS'ta doğrudan parola ayarlarını aç
        await _autofillChannel.invokeMethod('openPasswordSettings');
      } else {
        // Android'de openAutofillSettings kullan
        await _openAutofillSettings();
      }
    } on PlatformException catch (e) {
      // Method channel yoksa fallback olarak normal ayarları aç
      debugPrint('Password settings error: ${e.message}');
      await _openAutofillSettings();
    } finally {
      if (mounted) {
        setState(() => _isAutofillSettingsBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final securityState = ref.watch(securityControllerProvider);
    final securityController = ref.read(securityControllerProvider.notifier);

    final isDarkMode = themeMode.isDarkMode(context);
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

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
                color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Ayarlar'),
          ],
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Security Status Card
                _SecurityStatusCard(
                  state: securityState,
                  onSetupTap: () {
                    _scrollToSecuritySection();
                  },
                  onLockTap: () {
                    if (securityState.isSecurityEnabled) {
                      securityController.lockApp();
                      SecurityOverlayManager().showSecurityOverlay(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Önce PIN veya biyometrik doğrulamayı etkinleştirin.',
                          ),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 28),

                // Autofill Section - En önemli bölüm
                _SectionHeader(
                  title: 'Otomatik Doldurma',
                  icon: Icons.auto_awesome,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: 12),
                _AutofillSetupCard(
                  isIOS: isIOS,
                  isBusy: _isAutofillSettingsBusy,
                  onOpenSettings: _openPasswordSettings,
                  onShowGuide: _showBrowserGuide,
                ),

                const SizedBox(height: 28),

                // Security Section
                _SectionHeader(
                  key: _securitySectionKey,
                  title: 'Güvenlik',
                  icon: Icons.shield_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _SecurityOptionsCard(
                  securityState: securityState,
                  isPinBusy: _isPinBusy,
                  isBiometricBusy: _isBiometricBusy,
                  onPinToggle: (value) =>
                      _handlePinToggle(securityController, value),
                  onBiometricToggle: (value) =>
                      _handleBiometricToggle(securityController, value),
                  onLockNow: securityState.isSecurityEnabled
                      ? () {
                          securityController.lockApp();
                          SecurityOverlayManager().showSecurityOverlay(context);
                        }
                      : null,
                  onOpenBiometricSettings: _openAppSettings,
                ),

                const SizedBox(height: 28),

                // Appearance Section
                _SectionHeader(
                  title: 'Görünüm',
                  icon: Icons.palette_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                _AppearanceCard(
                  isDarkMode: isDarkMode,
                  onThemeChanged: (value) {
                    themeController.setTheme(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Data Management Section
                _SectionHeader(
                  title: 'Veri Yönetimi',
                  icon: Icons.folder_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                _DataManagementCard(
                  isExportBusy: _isExportBusy,
                  isImportBusy: _isImportBusy,
                  onExport: _exportCredentials,
                  onImport: _importCredentials,
                ),

                const SizedBox(height: 28),

                // About Section
                _SectionHeader(
                  title: 'Hakkında',
                  icon: Icons.info_outline,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                _AboutCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAutofillSettings() async {
    if (!mounted) {
      return;
    }

    setState(() => _isAutofillSettingsBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;
    try {
      final service = ref.read(autofillSyncServiceProvider);
      final opened = await service.openAutofillSettings();
      if (!mounted) {
        return;
      }
      if (!opened) {
        final fallbackMessage = isAndroid
            ? 'Cihaz ayarları açılamadı. Lütfen Ayarlar > Sistem > Diller ve giriş > Otomatik doldurma hizmeti yolunu izleyin.'
            : 'Cihaz ayarları açılamadı. Lütfen Ayarlar > Parolalar > Parola Seçenekleri yolundan FluPass uzantısını etkinleştirin.';
        messenger.showSnackBar(SnackBar(content: Text(fallbackMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _isAutofillSettingsBusy = false);
      }
    }
  }

  Future<void> _showBrowserGuide() async {
    if (!mounted) {
      return;
    }

    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;
    final isIOS = platform == TargetPlatform.iOS;

    final sheetTitle = isAndroid
        ? 'Tarayıcı ayar ipuçları'
        : isIOS
        ? 'Safari ve uygulama ipuçları'
        : 'Kullanım ipuçları';

    final introText = isAndroid
        ? 'Tarayıcılar kendi otomatik doldurma servislerini kullanabilir. FluPass önerilerini görmek için aşağıdaki adımları takip edin.'
        : isIOS
        ? 'iOS, üçüncü parti kasaları sistem otomatik doldurma paneli üzerinden gösterir. FluPass kayıtlarını hızla kullanmak için bu rehberi izleyin.'
        : 'FluPass kayıtlarını kullanırken aşağıdaki genel ipuçlarını izleyebilirsiniz.';

    final stepsSections = <Widget>[];
    if (isAndroid) {
      stepsSections.addAll(const [
        _BrowserSteps(
          icon: Icons.language_outlined,
          title: 'Android sistem ayarları',
          steps: [
            'Ayarlar > Sistem > Diller ve giriş > Otomatik doldurma hizmeti menüsünü açın.',
            'FluPass\'ı varsayılan hizmet olarak seçin.',
            'Ayarı yaptıktan sonra forma dönüp alanı tekrar odaklayın.',
          ],
        ),
        SizedBox(height: 20),
        _BrowserSteps(
          icon: Icons.public,
          title: 'Google Chrome',
          steps: [
            'Chrome\'da sağ üstteki ⋮ menüsüne ve ardından Ayarlar\'a dokunun.',
            'Parolalar / Otomatik doldurma bölümüne gidin.',
            'Google\'ın yerleşik yöneticisini kapatın ya da FluPass önerilerine öncelik verin.',
          ],
        ),
        SizedBox(height: 20),
        _BrowserSteps(
          icon: Icons.travel_explore,
          title: 'Diğer tarayıcılar',
          steps: [
            'Tarayıcınızın Ayarlar > Gizlilik veya Parolalar bölümündeki yönetici ayarlarını inceleyin.',
            'Varsa yerleşik parola yöneticisini veya hesap senkronizasyonunu kapatın.',
            'Bazı tarayıcılar dış servisleri desteklemez; böyle bir durumda form alanını odaklayıp Android otomatik doldurma panelindeki FluPass seçeneğini kullanın veya verileri FluPass uygulamasından kopyalayın.',
          ],
        ),
      ]);
    } else if (isIOS) {
      stepsSections.addAll(const [
        _BrowserSteps(
          icon: Icons.settings,
          title: 'iOS ayarları',
          steps: [
            'Ayarlar > Parolalar > Parola Seçenekleri yolunu izleyip "Parolaları Otomatik Doldur" seçeneğini açın.',
            'Aynı ekranda "Doldurmaya İzin Ver" listesinden FluPass uzantısını etkinleştirin.',
            'Uzantı görünmüyorsa FluPass uygulamasını açıp Ayarlar bölümünde otomatik doldurma eşitlemesini tetikleyin.',
          ],
        ),
        SizedBox(height: 20),
        _BrowserSteps(
          icon: Icons.ios_share,
          title: 'Safari ve uygulamalar',
          steps: [
            'Parola alanına dokunduktan sonra klavyedeki Parolalar düğmesine basın ve FluPass\'ı seçin.',
            'Listeden doğru kaydı seçtiğinizde kullanıcı adı ve parola otomatik olarak doldurulur.',
            'Öneri görünmüyorsa sayfayı yenileyip alanı yeniden odaklayın ya da FluPass uygulamasından kaydı açarak tekrar eşitleyin.',
          ],
        ),
      ]);
    } else {
      stepsSections.addAll(const [
        _BrowserSteps(
          icon: Icons.tips_and_updates_outlined,
          title: 'Genel ipuçları',
          steps: [
            'FluPass uygulamasından kayıtları kopyalayıp hedef uygulamaya yapıştırın.',
            'Varsa platformunuzun otomatik doldurma ayarlarında FluPass benzeri üçüncü parti hizmetleri etkinleştirin.',
          ],
        ),
      ]);
    }

    final bool showAndroidNote = isAndroid;
    final bool showIosNote = isIOS;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final bottomPadding = MediaQuery.of(sheetContext).viewPadding.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: bottomPadding > 0 ? bottomPadding + 24 : 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    sheetTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(introText, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ...stepsSections,
                  if (showAndroidNote) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Not: Bazı cihazlarda FluPass\'ı seçtikten sonra tarayıcıyı yeniden başlatmanız gerekebilir.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ] else if (showIosNote) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Not: FluPass uzantısı listede görünmezse Ayarlar > FluPass ekranından uygulamaya otomatik doldurma erişimi verdiğinizi kontrol edin.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Kapat'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePinToggle(
    SecurityController controller,
    bool enable,
  ) async {
    setState(() => _isPinBusy = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      if (enable) {
        final pin = await _showPinSetupDialog(context);
        if (pin == null || !mounted) {
          return;
        }
        final success = await controller.setPin(pin);
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'PIN koruması etkinleştirildi.'
                  : 'PIN oluşturulurken bir hata oluştu.',
            ),
          ),
        );
      } else {
        final pin = await _showPinVerificationDialog(context);
        if (pin == null || !mounted) {
          return;
        }
        final success = await controller.authenticateAndRemovePin(pin);
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'PIN koruması devre dışı bırakıldı.'
                  : 'PIN doğrulanamadı. İşlem iptal edildi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPinBusy = false);
      }
    }
  }

  Future<void> _handleBiometricToggle(
    SecurityController controller,
    bool enable,
  ) async {
    setState(() => _isBiometricBusy = true);
    try {
      final messenger = ScaffoldMessenger.of(context);

      if (enable) {
        final result = await controller.setupBiometricAuth();
        if (!mounted) return;

        switch (result) {
          case BiometricSetupResult.success:
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Biyometrik kimlik doğrulama etkinleştirildi.'),
              ),
            );
            break;
          case BiometricSetupResult.notSupported:
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Cihazınız biyometrik kimlik doğrulamayı desteklemiyor.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            break;
          case BiometricSetupResult.notEnrolled:
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Önce cihazınıza parmak izi veya Face ID ekleyin.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            break;
          case BiometricSetupResult.permissionDenied:
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Biyometrik erişim sağlanamadı. Ayarlardan izinleri kontrol edin.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            break;
          case BiometricSetupResult.lockedOut:
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Çok fazla başarısız deneme. Lütfen bir süre bekleyin.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            break;
          case BiometricSetupResult.cancelled:
            // Kullanıcı iptal etti, sessizce geç
            break;
          case BiometricSetupResult.failed:
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Biyometrik kimlik doğrulama kurulamadı.'),
              ),
            );
            break;
        }
      } else {
        final success = await controller.authenticateAndRemoveBiometricAuth();
        if (!mounted) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Biyometrik kimlik doğrulama devre dışı bırakıldı.'
                  : 'Biyometrik kimlik doğrulama kapatılamadı.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBiometricBusy = false);
      }
    }
  }

  Future<void> _openAppSettings() async {
    final platform = Theme.of(context).platform;

    try {
      if (platform == TargetPlatform.iOS) {
        // iOS: Uygulama ayarlarını aç
        const iosChannel = MethodChannel('com.flutech.flupass/settings');
        final opened = await iosChannel.invokeMethod<bool>('openAppSettings');
        if (opened != true && mounted) {
          // Fallback: Genel ayarları aç
          await _autofillChannel.invokeMethod('openPasswordSettings');
        }
      } else {
        // Android: Uygulama ayarlarını aç
        const androidChannel = MethodChannel('com.flutech.flupass/settings');
        await androidChannel.invokeMethod('openAppSettings');
      }
    } on PlatformException catch (e) {
      debugPrint('Could not open app settings: ${e.message}');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final settingsPath = platform == TargetPlatform.iOS
            ? 'Ayarlar > FluPass'
            : 'Ayarlar > Uygulamalar > FluPass > İzinler';
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lütfen $settingsPath yolunu izleyin.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportCredentials(BuildContext launcherContext) async {
    setState(() => _isExportBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final authorized = await _authorizeSensitiveAction();
      if (!authorized) {
        return;
      }

      final service = ref.read(credentialTransferServiceProvider);
      final file = await service.createExportFile();
      if (!mounted) {
        return;
      }
      if (file == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Dışa aktarılacak kayıt bulunamadı.')),
        );
        return;
      }
      if (!launcherContext.mounted) return;
      final shareOrigin = _resolveShareOrigin(launcherContext);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'FluPass şifre yedeği',
        sharePositionOrigin: shareOrigin,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Şifreler CSV olarak paylaşıldı.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Dışa aktarma başarısız: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportBusy = false);
      }
    }
  }

  Future<bool> _authorizeSensitiveAction() async {
    final securityState = ref.read(securityControllerProvider);
    final securityController = ref.read(securityControllerProvider.notifier);

    if (!securityState.isPinEnabled && !securityState.isBiometricEnabled) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final messenger = ScaffoldMessenger.of(context);
    final hasBiometric = securityState.isBiometricEnabled;
    final hasPin = securityState.isPinEnabled;

    AuthMethod? selectedMethod;

    if (hasBiometric && hasPin) {
      selectedMethod = await _showAuthMethodDialog();
      if (!mounted) {
        return false;
      }
      if (selectedMethod == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Doğrulama iptal edildi.')),
        );
        return false;
      }
    } else if (hasBiometric) {
      selectedMethod = AuthMethod.biometric;
    } else if (hasPin) {
      selectedMethod = AuthMethod.pin;
    }

    if (selectedMethod == AuthMethod.biometric) {
      final biometricSuccess = await securityController
          .authenticateWithBiometrics(inlineAuth: true);
      if (!biometricSuccess) {
        if (!mounted) {
          return false;
        }
        messenger.showSnackBar(
          const SnackBar(content: Text('Biyometrik doğrulama tamamlanamadı.')),
        );
      }
      return biometricSuccess;
    }

    if (selectedMethod == AuthMethod.pin) {
      final pin = await _showPinVerificationDialog(context);
      if (!mounted) {
        return false;
      }

      if (pin == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Doğrulama iptal edildi.')),
        );
        return false;
      }

      final verified = await securityController.verifyPin(pin);
      if (!mounted) {
        return false;
      }

      if (!verified) {
        messenger.showSnackBar(
          const SnackBar(content: Text('PIN doğrulanamadı.')),
        );
      }

      return verified;
    }

    return false;
  }

  Rect _resolveShareOrigin(BuildContext launcherContext) {
    final renderBox = launcherContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      return offset & renderBox.size;
    }

    final overlay = Overlay.of(launcherContext, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox != null && overlayBox.hasSize) {
      final offset = overlayBox.localToGlobal(Offset.zero);
      return offset & overlayBox.size;
    }

    final size = MediaQuery.of(launcherContext).size;
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  Future<AuthMethod?> _showAuthMethodDialog() {
    return showDialog<AuthMethod>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Doğrulama yöntemi seçin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Biyometrik doğrulama'),
                onTap: () {
                  Navigator.of(dialogContext).pop(AuthMethod.biometric);
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('PIN kodu'),
                onTap: () {
                  Navigator.of(dialogContext).pop(AuthMethod.pin);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCredentials(BuildContext _) async {
    setState(() => _isImportBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(credentialTransferServiceProvider);
      final result = await service.importFromFilePicker();
      if (!mounted) {
        return;
      }
      if (result == null) {
        return;
      }
      if (result.hasError) {
        messenger.showSnackBar(
          SnackBar(content: Text('İçe aktarma başarısız: ${result.error}')),
        );
        return;
      }
      if (!result.hasChanges) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('İçe aktarılacak uygun kayıt bulunamadı.'),
          ),
        );
        return;
      }

      await ref.read(credentialListProvider.notifier).refresh();

      final skippedText = result.skipped > 0
          ? ' (${result.skipped} kayıt atlandı)'
          : '';
      messenger.showSnackBar(
        SnackBar(
          content: Text('${result.inserted} kayıt içe aktarıldı$skippedText.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('İçe aktarma sırasında hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportBusy = false);
      }
    }
  }

  Future<String?> _showPinSetupDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        final pinController = TextEditingController();
        final confirmController = TextEditingController();
        bool obscure = true;

        String? validatePin(String? value) {
          final pin = value?.trim() ?? '';
          if (pin.isEmpty) {
            return 'PIN kodu zorunludur.';
          }
          if (pin.length < 4 || pin.length > 6) {
            return 'PIN 4-6 haneli olmalıdır.';
          }
          if (int.tryParse(pin) == null) {
            return 'Sadece rakam kullanın.';
          }
          return null;
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('PIN oluştur'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      obscureText: obscure,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'PIN kodu',
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() => obscure = !obscure);
                          },
                        ),
                      ),
                      validator: validatePin,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      keyboardType: TextInputType.number,
                      obscureText: obscure,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'PIN tekrar',
                        counterText: '',
                      ),
                      validator: (value) {
                        final result = validatePin(value);
                        if (result != null) {
                          return result;
                        }
                        if (value!.trim() != pinController.text.trim()) {
                          return 'PIN kodları eşleşmiyor.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(
                        dialogContext,
                      ).pop(pinController.text.trim());
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showPinVerificationDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        final pinController = TextEditingController();
        bool obscure = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('PIN doğrulama'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscure,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'PIN kodunuz',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setDialogState(() => obscure = !obscure);
                      },
                    ),
                  ),
                  validator: (value) {
                    final pin = value?.trim() ?? '';
                    if (pin.isEmpty) {
                      return 'PIN kodu zorunludur.';
                    }
                    if (pin.length < 4 || pin.length > 6) {
                      return 'PIN 4-6 haneli olmalıdır.';
                    }
                    if (int.tryParse(pin) == null) {
                      return 'Sadece rakam kullanın.';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(
                        dialogContext,
                      ).pop(pinController.text.trim());
                    }
                  },
                  child: const Text('Onayla'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ===== Security Status Card =====

class _SecurityStatusCard extends StatelessWidget {
  const _SecurityStatusCard({
    required this.state,
    required this.onSetupTap,
    required this.onLockTap,
  });

  final SecurityState state;
  final VoidCallback onSetupTap;
  final VoidCallback onLockTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSecure = state.isBiometricEnabled || state.isPinEnabled;

    final statusText = state.isBiometricEnabled
        ? 'Face ID / Touch ID aktif'
        : state.isPinEnabled
        ? 'PIN koruması aktif'
        : 'Koruma aktif değil';

    final icon = state.isBiometricEnabled
        ? Icons.face
        : state.isPinEnabled
        ? Icons.pin_outlined
        : Icons.shield_outlined;

    // Güvenlik durumuna göre renkler
    final Color primaryColor;
    final Color bgColor;
    final Color borderColor;
    final Color iconBgColor;

    if (isSecure) {
      // Güvenlik aktif - yeşil tonları
      primaryColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E);
      bgColor = isDark ? const Color(0xFF1A2E1A) : const Color(0xFFECFDF5);
      borderColor = isDark ? const Color(0xFF2D5A2D) : const Color(0xFFBBF7D0);
      iconBgColor = primaryColor;
    } else {
      // Güvenlik aktif değil - turuncu/amber tonları (dikkat çekici ama agresif değil)
      primaryColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
      bgColor = isDark ? const Color(0xFF2D2A1A) : const Color(0xFFFFFBEB);
      borderColor = isDark ? const Color(0xFF5C4A1A) : const Color(0xFFFDE68A);
      iconBgColor = primaryColor;
    }

    return GestureDetector(
      onTap: isSecure ? null : onSetupTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  // İkon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconBgColor,
                          iconBgColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: iconBgColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Güvenlik Durumu',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isSecure
                    ? 'Verileriniz güvende! Şifreleriniz koruma altında.'
                    : 'Şifrelerinizi korumak için PIN veya biyometrik doğrulama ayarlayın.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white70
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              if (isSecure) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onLockTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text(
                      'Şimdi Kilitle',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSetupTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.security_rounded),
                    label: const Text(
                      'Güvenliği Etkinleştir',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Autofill Setup Card =====

class _AutofillSetupCard extends StatelessWidget {
  const _AutofillSetupCard({
    required this.isIOS,
    required this.isBusy,
    required this.onOpenSettings,
    required this.onShowGuide,
  });

  final bool isIOS;
  final bool isBusy;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowGuide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.tertiary.withValues(alpha: 0.15),
            theme.colorScheme.tertiary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.password_rounded,
                    color: theme.colorScheme.tertiary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Otomatik Doldurma',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIOS
                            ? 'FluPass\'ı iOS parola servisi olarak seçin'
                            : 'FluPass\'ı varsayılan autofill olarak ayarlayın',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Steps
            _StepItem(
              number: '1',
              text: isIOS
                  ? 'Ayarlar > Parolalar > Parola Seçenekleri'
                  : 'Ayarlar > Sistem > Otomatik doldurma',
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
            _StepItem(
              number: '2',
              text: isIOS
                  ? '"Parolaları Otomatik Doldur" seçeneğini açın'
                  : 'FluPass\'ı varsayılan olarak seçin',
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
            _StepItem(
              number: '3',
              text: isIOS
                  ? '"Doldurmaya İzin Ver" listesinde FluPass\'ı işaretleyin'
                  : 'Tarayıcınızda giriş yaparken FluPass önerilerini kullanın',
              color: theme.colorScheme.tertiary,
            ),

            const SizedBox(height: 20),

            // Main Button - Opens Password Settings directly
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onOpenSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiary,
                  foregroundColor: theme.colorScheme.onTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: isBusy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onTertiary,
                        ),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                label: Text(
                  isIOS ? 'Parola Ayarlarını Aç' : 'Autofill Ayarlarını Aç',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Secondary Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShowGuide,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.tertiary,
                  side: BorderSide(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
                  ),
                ),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('Detaylı Rehber'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.number,
    required this.text,
    required this.color,
  });

  final String number;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}

// ===== Security Options Card =====

class _SecurityOptionsCard extends StatelessWidget {
  const _SecurityOptionsCard({
    required this.securityState,
    required this.isPinBusy,
    required this.isBiometricBusy,
    required this.onPinToggle,
    required this.onBiometricToggle,
    required this.onLockNow,
    this.onOpenBiometricSettings,
  });

  final SecurityState securityState;
  final bool isPinBusy;
  final bool isBiometricBusy;
  final ValueChanged<bool> onPinToggle;
  final ValueChanged<bool> onBiometricToggle;
  final VoidCallback? onLockNow;
  final VoidCallback? onOpenBiometricSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // PIN Toggle
          _OptionTile(
            icon: Icons.pin_outlined,
            title: 'PIN Koruması',
            subtitle: 'Uygulama açılışında PIN iste',
            trailing: isPinBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: securityState.isPinEnabled,
                    onChanged: onPinToggle,
                  ),
            showDivider: true,
          ),

          // Biometric Toggle
          _OptionTile(
            icon: Icons.fingerprint,
            title: 'Biyometrik Doğrulama',
            subtitle: 'Face ID veya Touch ID ile kilit aç',
            trailing: isBiometricBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: securityState.isBiometricEnabled,
                    onChanged: onBiometricToggle,
                  ),
            showDivider: false,
          ),

          // Biyometrik ayarları yardım butonu
          if (onOpenBiometricSettings != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InkWell(
                onTap: onOpenBiometricSettings,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Biyometrik çalışmıyor mu? İzinleri kontrol edin.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== Appearance Card =====

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _OptionTile(
        icon: isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        title: 'Karanlık Tema',
        subtitle: isDarkMode ? 'Aktif' : 'Kapalı',
        trailing: Switch(value: isDarkMode, onChanged: onThemeChanged),
        showDivider: false,
      ),
    );
  }
}

// ===== Data Management Card =====

class _DataManagementCard extends StatelessWidget {
  const _DataManagementCard({
    required this.isExportBusy,
    required this.isImportBusy,
    required this.onExport,
    required this.onImport,
  });

  final bool isExportBusy;
  final bool isImportBusy;
  final Future<void> Function(BuildContext) onExport;
  final Future<void> Function(BuildContext) onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Export
            _DataActionTile(
              icon: Icons.upload_rounded,
              title: 'Dışa Aktar',
              subtitle: 'Şifreleri CSV olarak kaydet',
              buttonLabel: 'Dışa Aktar',
              isBusy: isExportBusy,
              color: theme.colorScheme.primary,
              onTap: () => onExport(context),
            ),

            const SizedBox(height: 16),
            Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),

            // Import
            _DataActionTile(
              icon: Icons.download_rounded,
              title: 'İçe Aktar',
              subtitle: 'CSV dosyasından şifre ekle',
              buttonLabel: 'İçe Aktar',
              isBusy: isImportBusy,
              color: theme.colorScheme.secondary,
              onTap: () => onImport(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataActionTile extends StatelessWidget {
  const _DataActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isBusy,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isBusy;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.tonal(
          onPressed: isBusy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
          ),
          child: isBusy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(buttonLabel),
        ),
      ],
    );
  }
}

// ===== Option Tile =====

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.showDivider,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 62,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

// ===== About Card =====

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  Future<void> _openBuyMeACoffee() async {
    final uri = Uri.parse('https://buymeacoffee.com/orkundayi');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // App Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: const ThemedAppIconMedium(showGlow: true),
            ),

            const SizedBox(height: 16),

            Text(
              'FluPass',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sürüm 1.1.6',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Şifre ve kart bilgilerinizi güvenle saklayan, tamamen yerel çalışan modern bir parola yöneticisi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            // Buy Me a Coffee Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFDD00).withValues(alpha: 0.15),
                    const Color(0xFFFF813F).withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFDD00).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: const Color(0xFFFF6B6B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uygulamayı beğendiniz mi?',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'FluPass tamamen ücretsiz ve reklamsız. Geliştirmeye destek olmak isterseniz bana bir kahve ısmarlayabilirsiniz!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openBuyMeACoffee,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFDD00), Color(0xFFFF813F)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFFDD00,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('☕', style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                'Bana Kahve Ismarla',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              '© ${DateTime.now().year} FluPass',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Browser Guide Components =====

class _BrowserSteps extends StatelessWidget {
  const _BrowserSteps({
    required this.icon,
    required this.title,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...steps.map((step) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 4),
                Icon(Icons.circle, size: 6, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(child: Text(step, style: theme.textTheme.bodySmall)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
