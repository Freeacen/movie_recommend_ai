import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/platform_web_helper.dart';
import '../../providers/chat_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tmdb_provider.dart';
import '../../../data/services/sync_engine.dart';
import '../../widgets/user_avatar_widget.dart';
import '../../widgets/google_sign_in_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).checkAndProcessOAuthCallback().then((didLogin) {
        if (didLogin && mounted) {
          ref.read(libraryProvider.notifier).loadLibrary();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google hesabınız bağlandı ve profiliniz eşitlendi! 🎉')),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _processAccountConnect(
    String identifier, {
    String? username,
    String? password,
  }) async {
    setState(() => _isLoading = true);
    try {
      final check = await ref.read(settingsProvider.notifier).loginWithEmail(
        identifier,
        username: username,
        password: password,
      );
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (check.hasConflict) {
        _showConflictDialog(check);
      } else {
        ref.read(libraryProvider.notifier).loadLibrary();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesap bağlandı ve senkronizasyon tamamlandı! 🎉')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Giriş hatası: $e')),
        );
      }
    }
  }

  Future<void> _showConflictDialog(AccountCheckResult check) async {
    final choice = await showDialog<ConflictResolutionChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: AppColors.primaryBlue, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Çakışma Tespit Edildi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu e-posta adresinde bulutta kayıtlı ${check.cloudMovieCount} adet film geçmişi bulundu. '
              'Mevcut cihazınızda ise ${check.localMovieCount} film yer alıyor. Nasıl devam etmek istersiniz?',
              style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Option 1: Merge
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.merge,
              icon: Icons.merge_type_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Akıllı Birleştir (Önerilen)',
              subtitle: 'Hiçbir veri silinmez. İki liste birleştirilir, çakışan filmlerde bu cihazdaki puanlar geçerli kalır.',
            ),
            const SizedBox(height: 10),

            // Option 2: Local wins
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.deviceWins,
              icon: Icons.phone_android_rounded,
              iconColor: AppColors.primaryBlue,
              title: 'Bu Cihazdakileri Geçerli Kıl',
              subtitle: 'Buluttaki eski geçmiş silinir ve bu cihazdaki liste buluta yüklenir.',
            ),
            const SizedBox(height: 10),

            // Option 3: Cloud wins
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.cloudWins,
              icon: Icons.cloud_download_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'Buluttakileri Geçerli Kıl',
              subtitle: 'Bu cihazdaki liste silinir ve buluttaki geçmiş cihaza geri yüklenir.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    // Step 2: Show Confirmation Warning Dialog
    final confirmed = await _showConfirmationDialog(choice);
    if (!mounted) return;

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(settingsProvider.notifier).resolveConflict(
          choice: choice,
          cloudUserId: check.cloudUserId,
          email: check.email,
        );
        setState(() => _isLoading = false);

        if (!mounted) return;
        ref.read(libraryProvider.notifier).loadLibrary();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eşitleme başarıyla tamamlandı! 🎉')),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Senkronizasyon hatası: $e')),
          );
        }
      }
    } else {
      // User tapped "İptal", return back to options dialog
      _showConflictDialog(check);
    }
  }

  Widget _buildConflictOption({
    required BuildContext ctx,
    required ConflictResolutionChoice choice,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(ctx, choice),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMedium, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(ConflictResolutionChoice choice) {
    String title;
    String message;
    Color buttonColor;

    switch (choice) {
      case ConflictResolutionChoice.merge:
        title = 'Akıllı Birleştirme Onayı';
        message = 'Cihazınızdaki ve buluttaki filmler birleştirilecek. Hiçbir film silinmeyecek; çakışan filmlerde bu cihazdaki puan ve izleme tarihleri geçerli kalacak.';
        buttonColor = const Color(0xFF10B981);
        break;
      case ConflictResolutionChoice.deviceWins:
        title = '⚠️ DİKKAT: Bulut Verileri Silinecek';
        message = 'Bulutta önceden kayıtlı olan tüm film geçmişi kalıcı olarak SİLİNECEK ve yalnızca bu cihazdaki filmler buluta aktarılacak.';
        buttonColor = AppColors.accentRose;
        break;
      case ConflictResolutionChoice.cloudWins:
        title = '⚠️ DİKKAT: Cihaz Verileri Silinecek';
        message = 'Bu cihazdaki yerel izleme listeniz tamamen SİLİNECEK ve buluttaki geçmişiniz cihaza geri yüklenecektir.';
        buttonColor = AppColors.accentRose;
        break;
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
        content: Text(
          '$message\n\nBu işlemi onaylıyor musunuz?',
          style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal (Seçeneklere Dön)', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tamam, Onayla'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        children: [
          // 0. User Account / Profile Card (Apple ID Banner Style)
          _buildAccountCard(settings, isDark),

          // 1. Görünüm (Appearance)
          _buildSectionHeader('Görünüm'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              _buildSwitchRow(
                icon: settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: const Color(0xFF5856D6), // Apple Indigo
                title: settings.isDarkMode ? 'Karanlık Tema' : 'Aydınlık Tema',
                subtitle: settings.isDarkMode
                    ? 'OLED ve düşük ışık uyumlu sinematik koyu arayüz'
                    : 'Ferah ve yüksek kontrastlı modern aydınlık arayüz',
                value: settings.isDarkMode,
                onChanged: (_) => ref.read(settingsProvider.notifier).toggleTheme(),
              ),
              _buildRowDivider(isDark),
              _buildSwitchRow(
                icon: Icons.animation_rounded,
                iconColor: settings.isAnimationsEnabled
                    ? const Color(0xFF007AFF) // Apple System Blue
                    : const Color(0xFF8E8E93), // iOS System Gray
                title: 'Arayüz Animasyonları',
                subtitle: settings.isAnimationsEnabled
                    ? 'Sayfa geçişleri, menü süzülmeleri ve akıcı hareketler aktif.'
                    : 'Animasyonlar kapalı (Hareketi Azalt). Sayfalar ve sekmeler anında değişir.',
                value: settings.isAnimationsEnabled,
                onChanged: (_) => ref.read(settingsProvider.notifier).toggleAnimations(),
              ),
            ],
          ),

          // 2. Bulut & Senkronizasyon (Cloud & Sync)
          _buildSectionHeader('Bulut & Senkronizasyon'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              // Cloud status row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildIconBadge(
                      icon: settings.syncStatus == SyncStatus.synced
                          ? Icons.cloud_done_rounded
                          : (settings.syncStatus == SyncStatus.syncing
                              ? Icons.cloud_sync_rounded
                              : (settings.syncStatus == SyncStatus.error
                                  ? Icons.cloud_off_rounded
                                  : Icons.cloud_outlined)),
                      backgroundColor: settings.syncStatus == SyncStatus.synced
                          ? const Color(0xFF34C759) // iOS System Green
                          : (settings.syncStatus == SyncStatus.error
                              ? const Color(0xFFFF3B30)
                              : AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulut Eşitleme',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHigh,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            settings.syncStatus == SyncStatus.synced
                                ? 'Verileriniz bulut ile güncel ve yedekli.'
                                : (settings.syncStatus == SyncStatus.syncing
                                    ? 'Buluta eşitleniyor...'
                                    : (settings.syncStatus == SyncStatus.error
                                        ? 'Eşitleme sırasında hata oluştu.'
                                        : 'Çevrimdışı / Yerel SQLite modunda.')),
                            style: TextStyle(
                              fontSize: 12,
                              color: settings.syncStatus == SyncStatus.synced
                                  ? const Color(0xFF34C759)
                                  : (settings.syncStatus == SyncStatus.error
                                      ? const Color(0xFFFF3B30)
                                      : AppColors.textMedium),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Şimdi Eşitle',
                      icon: settings.syncStatus == SyncStatus.syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                            )
                          : const Icon(Icons.sync_rounded, color: AppColors.primaryBlue, size: 22),
                      onPressed: settings.syncStatus == SyncStatus.syncing
                          ? null
                          : () async {
                              await ref.read(settingsProvider.notifier).triggerSync(isManual: true);
                              if (context.mounted) {
                                ref.read(libraryProvider.notifier).loadLibrary();
                                final currentStatus = ref.read(settingsProvider).syncStatus;
                                if (currentStatus == SyncStatus.synced) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bulut senkronizasyonu tamamlandı! ☁️'),
                                      backgroundColor: Color(0xFF34C759),
                                    ),
                                  );
                                } else if (currentStatus == SyncStatus.offline) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Buluta ulaşılamadı, çevrimdışı moddasınız.'),
                                      backgroundColor: Colors.amber,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bulut eşitleme sırasında bir hata oluştu.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
              _buildRowDivider(isDark),

              // Auto-sync switch row
              _buildSwitchRow(
                icon: Icons.sync_rounded,
                iconColor: settings.isAutoSyncEnabled
                    ? const Color(0xFF34C759)
                    : const Color(0xFF8E8E93),
                title: 'Otomatik Bulut Yedekleme',
                subtitle: settings.isAutoSyncEnabled
                    ? 'Kütüphane değişiklikleri arka planda otomatik eşitlenir.'
                    : 'Otomatik yedekleme kapalı. Değişiklikler yerel tutulur.',
                value: settings.isAutoSyncEnabled,
                onChanged: (_) => ref.read(settingsProvider.notifier).toggleAutoSync(),
              ),
              _buildRowDivider(isDark),

              // Device cloud ID row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildIconBadge(
                      icon: Icons.fingerprint_rounded,
                      backgroundColor: const Color(0xFF5856D6), // Apple Purple/Indigo
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cihaz Bulut Kimliği',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHigh,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            settings.deviceCloudId.isNotEmpty
                                ? '${settings.deviceCloudId.substring(0, 8)}...${settings.deviceCloudId.substring(settings.deviceCloudId.length - 6)}'
                                : 'Anonim Cihaz',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      label: const Text('Kopyala', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: settings.deviceCloudId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cihaz kimliğiniz kopyalandı! 📋 Başka cihazda "Kimlik Gir" diyerek kütüphanenizi anında yükleyebilirsiniz.',
                            ),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5856D6),
                        side: BorderSide(color: const Color(0xFF5856D6).withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 13),
                      label: const Text('Kimlik Gir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      onPressed: () => _handleCloudIdImportDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Veri ve Depolama (Data & Storage)
          _buildSectionHeader('Veri ve Depolama'),
          _buildGroupContainer(
            isDark: isDark,
            children: [
              // Sohbet Geçmişi Temizleme
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildIconBadge(
                      icon: Icons.chat_bubble_outline_rounded,
                      backgroundColor: const Color(0xFFFF9500), // Apple Orange
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sohbet Geçmişi',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHigh,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kütüphanenizi koruyarak yalnızca sohbet ekranını sıfırlar.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF9500),
                        side: BorderSide(color: const Color(0xFFFF9500).withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _confirmClearChat(context),
                      child: const Text('Temizle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              _buildRowDivider(isDark),

              // Veri Aktarımı ve Yedekleme
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildIconBadge(
                          icon: Icons.import_export_rounded,
                          backgroundColor: const Color(0xFF007AFF), // Apple Royal Blue
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Veri Aktarımı ve Yedekleme',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHigh,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kütüphanenizi dosya veya bulut kimliğiyle taşıyın.',
                                style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textHigh,
                              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cloud_download_rounded, size: 15),
                            label: const Text('Buluttan İndir', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            onPressed: () => _handleRestoreFromActiveCloudDialog(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textHigh,
                              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.file_download_outlined, size: 15),
                            label: const Text('Yedek Al', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            onPressed: () => _handleExportJsonDialog(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textHigh,
                              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.file_upload_outlined, size: 15),
                            label: const Text('Yedek Yükle', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            onPressed: () => _handleImportJsonDialog(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildRowDivider(isDark),

              // Tüm Verileri Sıfırla (Danger Zone)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildIconBadge(
                      icon: Icons.delete_forever_rounded,
                      backgroundColor: const Color(0xFFFF3B30), // Apple System Red
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tüm Verileri Sıfırla',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF3B30),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cihazdaki ve buluttaki tüm verileri kalıcı siler.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _confirmReset(context),
                      child: const Text('Sıfırla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 4. Footer
          Center(
            child: Column(
              children: [
                Text(
                  'CineAI • Sürüm 2.0 (Hibrit Mimari)',
                  style: TextStyle(fontSize: 12, color: AppColors.textLow, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supabase Edge Functions + Groq Llama 3.3 + Offline-First SQLite',
                  style: TextStyle(fontSize: 11, color: AppColors.textLow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Apple Inset Grouped UI Helpers ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 22),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textLow,
        ),
      ),
    );
  }

  Widget _buildGroupContainer({
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildRowDivider(bool isDark) {
    return Divider(
      height: 0.75,
      thickness: 0.75,
      indent: 58,
      endIndent: 0,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color backgroundColor,
    double size = 32,
    double iconSize = 18,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.5),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _buildIconBadge(icon: icon, backgroundColor: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.primaryBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(SettingsState settings, bool isDark) {
    if (settings.isLoggedIn) {
      final emailSub = settings.userEmail != null &&
              settings.userEmail!.isNotEmpty &&
              settings.userEmail != settings.effectiveDisplayName
          ? settings.userEmail!
          : 'Kütüphaneniz bu hesapla bulutta eşitleniyor';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.045) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25),
            width: 0.75,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            UserAvatarWidget(
              avatarUrl: settings.avatarUrl,
              size: 54,
              showCameraBadge: true,
              onTap: () => _showAvatarSelectionDialog(context),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          settings.effectiveDisplayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHigh,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _showEditUserNameDialog(context, settings.effectiveDisplayName),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.edit_rounded, size: 15, color: AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Bağlı',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    emailSub,
                    style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Çıkış Yap',
              icon: const Icon(Icons.logout_rounded, color: AppColors.accentRose, size: 21),
              onPressed: () => _confirmLogout(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.045) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarWidget(
                avatarUrl: settings.avatarUrl,
                size: 54,
                showCameraBadge: true,
                onTap: () => _showAvatarSelectionDialog(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            settings.effectiveDisplayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHigh,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showEditUserNameDialog(context, settings.effectiveDisplayName),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.edit_rounded, size: 15, color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Misafir Profil • Fotoğrafa dokunarak değiştirin',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subtle Apple Callout Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.22 : 0.15),
                width: 0.75,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 17),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Kütüphaneniz şu an bu cihaza geçici kimlikle yedekleniyor. Farklı cihazlarda senkronize etmek için hesabınızı bağlayabilir veya bulut kimliğinizi kopyalayabilirsiniz.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMedium,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Apple Style Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Giriş Yap', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  onPressed: _isLoading ? null : () => _showLoginDialog(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.4), width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Kayıt Ol', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  onPressed: _isLoading ? null : () => _showRegisterDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleOAuth() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(settingsProvider.notifier).loginWithGooglePopup();
      if (mounted) {
        if (success) {
          ref.read(libraryProvider.notifier).loadLibrary();
          ref.read(chatProvider.notifier).clearHistory();
          ref.read(tmdbProvider.notifier).fetchTrending();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google hesabınız başarıyla bağlandı! 🎉')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google ile giriş hatası: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAvatarSelectionDialog(BuildContext context) async {
    await UserAvatarWidget.showAvatarSelectionSheet(context, ref);
  }

  Future<void> _showEditUserNameDialog(BuildContext context, String currentName) async {
    await UserAvatarWidget.showEditUserNameDialog(context, ref, currentName);
  }

  void _showLoginDialog() {
    final identifierController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.border, width: 0.8),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Brand & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.movie_filter_rounded, color: AppColors.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'CineAI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHigh,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textLow, size: 20),
                        tooltip: 'Kapat',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title & Subtitle
                  Text(
                    'Hesabınıza Giriş Yapın',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Film kütüphanenizi ve sinema profilinizi tüm cihazlarınızla eşitleyin.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMedium,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. Primary Action: Official Google Sign-In Button
                  GoogleSignInButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleGoogleOAuth();
                    },
                  ),
                  const SizedBox(height: 18),

                  // 2. Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya e-posta ile',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textLow),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. Email / Username field
                  TextField(
                    controller: identifierController,
                    style: TextStyle(fontSize: 13.5, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı veya E-posta',
                      hintText: 'ornek@email.com',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Password field
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: TextStyle(fontSize: 13.5, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Full-width Login Action Button
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final id = identifierController.text.trim();
                        final pass = passwordController.text;
                        if (id.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen kullanıcı adı veya e-posta girin.')),
                          );
                          return;
                        }
                        if (pass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen şifrenizi girin.')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        _processAccountConnect(id, password: pass);
                      },
                      child: const Text(
                        'Giriş Yap',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Switch to Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Henüz hesabınız yok mu?',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textMedium),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showRegisterDialog();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Kayıt Olun',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.border, width: 0.8),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Brand & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'CineAI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHigh,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textLow, size: 20),
                        tooltip: 'Kapat',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title & Subtitle
                  Text(
                    'Yeni Hesap Oluştur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kişiselleştirilmiş sinema dünyanızı ve önerilerinizi saklayın.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMedium,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. Primary Action: Official Google Sign-In Button
                  GoogleSignInButton(
                    label: 'Google ile Kayıt Ol',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleGoogleOAuth();
                    },
                  ),
                  const SizedBox(height: 18),

                  // 2. Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya bilgilerinizi girin',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textLow),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Form Fields
                  TextField(
                    controller: usernameController,
                    style: TextStyle(fontSize: 13.5, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      hintText: 'Örn: Sinemasever',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 13.5, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'E-posta Adresi',
                      hintText: 'ornek@email.com',
                      prefixIcon: const Icon(Icons.mail_outline_rounded, size: 19),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: TextStyle(fontSize: 13.5, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscurePassword,
                    style: TextStyle(fontSize: 13.5, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Şifre Tekrar',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Full-width Register Button
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final username = usernameController.text.trim();
                        final email = emailController.text.trim();
                        final pass = passwordController.text;
                        final passConfirm = confirmPasswordController.text;

                        if (username.length < 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kullanıcı adı en az 3 karakter olmalıdır.')),
                          );
                          return;
                        }
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen geçerli bir e-posta adresi girin.')),
                          );
                          return;
                        }
                        if (pass.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Şifre en az 4 karakter olmalıdır.')),
                          );
                          return;
                        }
                        if (pass != passConfirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Şifreler eşleşmiyor, lütfen tekrar deneyin.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        _processAccountConnect(
                          email,
                          username: username,
                          password: pass,
                        );
                      },
                      child: const Text(
                        'Hesabı Oluştur',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Switch to Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Zaten bir hesabınız var mı?',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textMedium),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showLoginDialog();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Giriş Yapın',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Çıkış Yapılsın mı?'),
        content: Text(
          'Hesabınızdan çıkış yaptığınızda yerel verileriniz cihazınızda kalır, ancak yeni değişiklikler bu hesaba eşitlenmez.',
          style: TextStyle(color: AppColors.textMedium, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(settingsProvider.notifier).logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hesaptan çıkış yapıldı.')),
                );
              }
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _confirmClearChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: Color(0xFFFF9500), size: 22),
            const SizedBox(width: 8),
            Text('Sohbet Temizlensin mi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          ],
        ),
        content: Text(
          'Sohbet penceresindeki tüm mesajlar ve öneri kartları temizlenecek ve karşılama ekranına dönülecektir.\n\n'
          'Kütüphanenizdeki kayıtlı filmler, puanlamalarınız ve yapay zekanın arka plan öneri hafızası korunacaktır.\n\n'
          'Onaylıyor musunuz?',
          style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9500),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(chatProvider.notifier).clearChatDisplayOnly();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sohbet ekranı temizlendi! 🧹')),
                );
              }
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  void _showCancelledInfoDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 22),
            const SizedBox(width: 8),
            Text('İşlem İptal Edildi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<ConflictResolutionChoice?> _showFourChoiceConflictDialog({
    required BuildContext context,
    required String title,
    required String description,
    required String targetName,
  }) {
    return showDialog<ConflictResolutionChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Choice 1: Merge
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.merge,
              icon: Icons.merge_type_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Akıllı Birleştir (Önerilen)',
              subtitle: 'Hiçbir film silinmez. İki liste birleştirilir, çakışan filmlerde bu cihazdaki puanlar geçerli kalır.',
            ),
            const SizedBox(height: 10),

            // Choice 2: Device Wins
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.deviceWins,
              icon: Icons.phone_android_rounded,
              iconColor: AppColors.primaryBlue,
              title: 'Bu Cihazdakileri Geçerli Kıl',
              subtitle: 'Bu cihazdaki kayıtlar korunur, $targetName tarafındaki çakışan veriler güncellenir.',
            ),
            const SizedBox(height: 10),

            // Choice 3: Target/Cloud Wins
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.cloudWins,
              icon: Icons.download_rounded,
              iconColor: AppColors.accentRose,
              title: '$targetName Tarafındakileri Geçerli Kıl',
              subtitle: '⚠️ Bu cihazdaki liste silinir ve $targetName içindeki filmler cihaza yüklenir.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Vazgeç (İptal Et)', style: TextStyle(color: AppColors.textMedium)),
          ),
        ],
      ),
    );
  }

  Future<ConflictResolutionChoice?> _showJsonConflictDialog({
    required BuildContext context,
    required String title,
    required String description,
  }) {
    return showDialog<ConflictResolutionChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Choice 1: Merge (Recommended)
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.merge,
              icon: Icons.merge_type_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Akıllı Birleştir (Önerilen)',
              subtitle: 'Mevcut filmleriniz ve puanlarınız korunur, yedek dosyasındaki yeni filmler listenize eklenir.',
            ),
            const SizedBox(height: 10),

            // Choice 2: Overwrite (cloudWins)
            _buildConflictOption(
              ctx: ctx,
              choice: ConflictResolutionChoice.cloudWins,
              icon: Icons.file_download_outlined,
              iconColor: AppColors.accentRose,
              title: 'Dosyadakileri Geçerli Kıl (Üzerine Yaz)',
              subtitle: '⚠️ Bu cihazdaki mevcut filmler silinir, sadece yedek dosyasındaki filmler yüklenir.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Vazgeç (İptal Et)', style: TextStyle(color: AppColors.textMedium)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestoreFromActiveCloudDialog(BuildContext context) async {
    setState(() => _isLoading = true);
    final count = await ref.read(settingsProvider.notifier).checkActiveCloudMovieCount();
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (count == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text('Bulut Yedeği Bulunamadı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
            ],
          ),
          content: Text(
            'Bulut hesabınızda henüz kayıtlı herhangi bir film yedeği bulunmuyor. Üst kısımdaki "Bulut Eşitleme" (🔄) butonunu kullanarak mevcut filmlerinizi buluta yedekleyebilirsiniz.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bulut Yedeğini Geri Yükle',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3B30), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DİKKAT: Bu cihazdaki yerel izleme listeniz tamamen silinecektir.',
                      style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Bu işlem yapıldığında, cihazınızda kayıtlı mevcut filmleriniz silinecek ve yerine yalnızca bulutta kayıtlı $count adet film yüklenecektir.',
              style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'İpucu: Eğer verilerinizi silmeden iki tarafı birleştirmek istiyorsanız, bunun yerine üst kısımdaki "Bulut Eşitleme" (🔄) butonunu kullanabilirsiniz.',
              style: TextStyle(color: AppColors.textLow, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cihazı Sıfırla ve Buluttan Yükle', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) {
        _showCancelledInfoDialog(context, 'Buluttan geri yükleme işlemi iptal edildi. Cihazınızdaki hiçbir veriye dokunulmadı.');
      }
      return;
    }

    setState(() => _isLoading = true);
    await ref.read(settingsProvider.notifier).restoreFromActiveCloud(choice: ConflictResolutionChoice.cloudWins);
    setState(() => _isLoading = false);

    if (mounted) {
      ref.read(libraryProvider.notifier).loadLibrary();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buluttaki filmleriniz başarıyla cihaza geri yüklendi! 🎉'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    }
  }

  Future<void> _handleCloudIdImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final cloudId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.cloud_download_rounded, color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 8),
            Text('Bulut ID ile İçe Aktar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Başka bir cihazdan kopyaladığınız Cihaz Bulut Kimliğini aşağıya yapıştırın:',
              style: TextStyle(color: AppColors.textMedium, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(fontSize: 13, color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Örn: e2b4c10a-85d7-4...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textLow),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Kontrol Et'),
          ),
        ],
      ),
    );

    if (cloudId == null || cloudId.isEmpty) {
      if (mounted) {
        _showCancelledInfoDialog(context, 'Buluttan veri çekme işlemi iptal edildi. Cihazınızdaki hiçbir veriye dokunulmadı.');
      }
      return;
    }

    setState(() => _isLoading = true);
    final count = await ref.read(settingsProvider.notifier).checkTargetCloudId(cloudId);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (count == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Kayıt Bulunamadı'),
          content: Text(
            'Girilen Bulut Kimliğinde ($cloudId) kayıtlı herhangi bir film bulunamadı.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final localMovies = await ref.read(movieRepositoryProvider).getAllMovies();

    // Show 4-choice conflict dialog
    final choice = await _showFourChoiceConflictDialog(
      context: context,
      title: 'Bulut ID Eşitleme Seçenekleri',
      description: 'Girilen Bulut Kimliğinde $count adet film bulundu. Bu cihazınızda ise ${localMovies.length} film yer alıyor. Nasıl devam etmek istersiniz?',
      targetName: 'Hedef Bulut ID',
    );

    if (choice == null) {
      if (mounted) {
        _showCancelledInfoDialog(context, 'Buluttan getirilen veriler kütüphanenize veya cihazınıza uygulanmadı. Mevcut verileriniz aynen korunmaktadır.');
      }
      return;
    }

    // If destructive choice, confirm
    if (choice == ConflictResolutionChoice.deviceWins || choice == ConflictResolutionChoice.cloudWins) {
      final confirmed = await _showConfirmationDialog(choice);
      if (confirmed != true) {
        if (mounted) {
          _showCancelledInfoDialog(context, 'İşlem onaylanmadığı için veriler uygulanmadı. Mevcut verileriniz aynen korunuyor.');
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    await ref.read(settingsProvider.notifier).importFromCloudId(
      targetCloudId: cloudId,
      choice: choice,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      ref.read(libraryProvider.notifier).loadLibrary();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulut ID ile veri eşitlemesi başarıyla tamamlandı! 🎉')),
      );
    }
  }

  Future<void> _handleExportJsonDialog(BuildContext context) async {
    final settings = ref.read(settingsProvider);

    // Check if not fully synced
    if (settings.syncStatus != SyncStatus.synced) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.primaryAmber, size: 24),
              const SizedBox(width: 8),
              Text('Bulut Senkronizasyon Uyarısı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
            ],
          ),
          content: Text(
            '⚠️ Cihazınız şu an bulut ile tam senkronize değil veya bekleyen yerel veriler var.\n\n'
            'İsterseniz önce bulutla eşitleyip yedeği öyle alabilir, ya da doğrudan bu cihazdaki güncel yerel verilerinizin yedeğini alabilirsiniz.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx, true);
                await ref.read(settingsProvider.notifier).triggerSync(isManual: true);
              },
              child: const Text('Önce Eşitle ve Yedekle'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yine de Yerel Yedeği Al'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        if (mounted) {
          _showCancelledInfoDialog(context, 'Yedek alma işlemi iptal edildi.');
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    final jsonStr = await ref.read(settingsProvider.notifier).exportLibraryToJson();
    setState(() => _isLoading = false);

    if (!mounted) return;

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = 'cineai_yedek_$dateStr.json';

    await PlatformWebHelper.downloadFile(jsonStr, fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedek dosyanız başarıyla indirildi: $fileName 💾'),
          backgroundColor: const Color(0xFF34C759),
        ),
      );
    }
  }

  Future<void> _handleImportJsonDialog(BuildContext context) async {
    final jsonText = await PlatformWebHelper.pickTextFile(accept: '.json,application/json');

    if (jsonText == null || jsonText.trim().isEmpty) {
      return;
    }

    // Validate JSON
    int movieCount = 0;
    try {
      final Map<String, dynamic> data = jsonDecode(jsonText);
      final movies = data['movies'] as List<dynamic>? ?? [];
      movieCount = movies.length;
      if (movieCount == 0) {
        throw Exception('Yedek dosyasında geçerli film kaydı bulunamadı.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geçersiz veya bozuk yedek dosyası: $e')),
        );
      }
      return;
    }

    final localMovies = await ref.read(movieRepositoryProvider).getAllMovies();

    // Show conflict dialog for JSON file
    final choice = await _showJsonConflictDialog(
      context: context,
      title: 'Yedek Dosyasını İçe Aktarma',
      description: 'Seçtiğiniz yedek dosyasında $movieCount adet film bulundu. Bu cihazınızda ise ${localMovies.length} film yer alıyor. Nasıl yüklemek istersiniz?',
    );

    if (choice == null) {
      if (mounted) {
        _showCancelledInfoDialog(context, 'Yedek dosyasındaki veriler kütüphanenize veya cihazınıza uygulanmadı. Mevcut verileriniz aynen korunmaktadır.');
      }
      return;
    }

    if (choice == ConflictResolutionChoice.cloudWins) {
      // Destructive: replace local
      final confirmOverwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('⚠️ DİKKAT: Mevcut Filmler Silinecek'),
          content: const Text(
            'Bu cihazdaki mevcut tüm filmler kalıcı olarak SİLİNECEK ve yerini yedek dosyasındaki filmlere bırakacaktır.\n\nOnaylıyor musunuz?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet, Üzerine Yaz'),
            ),
          ],
        ),
      );
      if (confirmOverwrite != true) {
        if (mounted) {
          _showCancelledInfoDialog(context, 'İşlem iptal edildi. Cihazınızdaki veriler aynen korunuyor.');
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    final importedCount = await ref.read(settingsProvider.notifier).importLibraryFromJson(
      jsonStr: jsonText,
      choice: choice,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      ref.read(libraryProvider.notifier).loadLibrary();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importedCount adet film başarıyla kütüphanenize aktarıldı! 🎉')),
      );
    }
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accentRose, size: 24),
            const SizedBox(width: 8),
            Text('⚠️ Tüm Veriler Kalıcı Olarak Silinsin mi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentRose)),
          ],
        ),
        content: Text(
          'DİKKAT: Kütüphanenizdeki tüm izlenen filmler, puanlamalar, özel zevk profiliniz ve sohbet geçmişiniz hem bu cihazdan HEM DE bulut sunucularından kalıcı olarak silinecektir.\n\n'
          'Cihazınız için sıfır bir kimlik oluşturulacaktır. Bu işlem geri alınamaz!\n\n'
          'Onaylıyor musunuz?',
          style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(settingsProvider.notifier).clearAllDataAndCloud();
              ref.read(libraryProvider.notifier).loadLibrary();
              ref.read(chatProvider.notifier).clearHistory();
              ref.read(tmdbProvider.notifier).fetchTrending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm veriler cihazdan ve buluttan kalıcı olarak silindi.')),
                );
              }
            },
            child: const Text('Evet, Tümünü Sil'),
          ),
        ],
      ),
    );
  }
}
