import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tmdb_provider.dart';
import '../../../data/services/sync_engine.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Cloud Sync Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: settings.syncStatus == SyncStatus.synced
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: settings.syncStatus == SyncStatus.synced
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : AppColors.primaryAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        settings.syncStatus == SyncStatus.synced
                            ? Icons.cloud_done_rounded
                            : (settings.syncStatus == SyncStatus.syncing
                                ? Icons.cloud_sync_rounded
                                : Icons.cloud_outlined),
                        color: settings.syncStatus == SyncStatus.synced
                            ? const Color(0xFF10B981)
                            : AppColors.primaryAmber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supabase Bulut Eşitleme',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            settings.syncStatus == SyncStatus.synced
                                ? 'Verileriniz bulut ile güncel ve yedekli.'
                                : (settings.syncStatus == SyncStatus.syncing
                                    ? 'Buluta eşitleniyor...'
                                    : 'Çevrimdışı / Yerel SQLite modunda.'),
                            style: TextStyle(
                              fontSize: 12,
                              color: settings.syncStatus == SyncStatus.synced
                                  ? const Color(0xFF10B981)
                                  : AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cihaz Bulut Kimliği:',
                            style: TextStyle(fontSize: 11, color: AppColors.textLow),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            settings.deviceCloudId.isNotEmpty
                                ? '${settings.deviceCloudId.substring(0, 8)}...${settings.deviceCloudId.substring(settings.deviceCloudId.length - 6)}'
                                : 'Anonim Cihaz',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textHigh),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(settingsProvider.notifier).triggerSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bulut senkronizasyonu tamamlandı! ☁️')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryAmber,
                        side: const BorderSide(color: AppColors.primaryAmber),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Şimdi Eşitle', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Hybrid Architecture Info Badges
          Text(
            'Altyapı & Entegrasyonlar',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textHigh),
          ),
          const SizedBox(height: 10),

          // Groq Llama 3.3 Pool Badge
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Groq Llama 3.3 AI Havuzu (Sunucu Tarafı)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'API anahtarı girmenize gerek yoktur. Otomatik anahtar rotasyonu ve sıfır-gecikmeli yerel şablon birleştirici devrededir.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // TMDB Built-in Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.movie_filter_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TMDB Film Kataloğu (Limitsiz & Entegre)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '800.000+ film afişi, 2-3 cümlelik Türkçe özetler ve anlık arama motoru doğrudan dahili çalışır.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Application Preferences
          Text(
            'Uygulama Tercihleri',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textHigh),
          ),
          const SizedBox(height: 10),

          Material(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.primaryAmber,
                    ),
                    title: Text(
                      settings.isDarkMode ? 'Karanlık Tema' : 'Aydınlık Tema',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textHigh),
                    ),
                    subtitle: Text(
                      settings.isDarkMode
                          ? 'OLED ve düşük ışık uyumlu sinematik koyu arayüz'
                          : 'Ferah ve yüksek kontrastlı modern aydınlık arayüz',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                    value: settings.isDarkMode,
                    activeThumbColor: AppColors.primaryAmber,
                    onChanged: (_) => ref.read(settingsProvider.notifier).toggleTheme(),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  ListTile(
                    leading: Icon(Icons.copy_rounded, color: AppColors.textMedium, size: 20),
                    title: Text('Cihaz Bulut ID\'sini Kopyala', style: TextStyle(fontSize: 14, color: AppColors.textHigh)),
                    subtitle: Text('Farklı cihazda geçmişinizi eşitlemek için kullanabilirsiniz', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: settings.deviceCloudId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bulut Kimliği panoya kopyalandı! 📋')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 4. Data Management & Reset
          Text(
            'Veri Yönetimi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textHigh),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textHigh,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Örnek Veri Yükle', style: TextStyle(fontSize: 13)),
                  onPressed: () async {
                    await ref.read(settingsProvider.notifier).seedDemoData();
                    ref.read(libraryProvider.notifier).loadLibrary();
                    ref.read(tmdbProvider.notifier).fetchTrending();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Örnek film verileri yüklendi! 🎬')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRose,
                    side: const BorderSide(color: AppColors.accentRose),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Verileri Sıfırla', style: TextStyle(fontSize: 13)),
                  onPressed: () => _confirmReset(context, ref),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Footer
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

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Tüm Veriler Sıfırlansın mı?'),
        content: Text(
          'Kütüphanenizdeki tüm izlenen filmler, puanlamalar ve sohbet geçmişi yerel cihazınızdan tamamen silinecektir.',
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
              await ref.read(settingsProvider.notifier).resetAllData();
              ref.read(libraryProvider.notifier).loadLibrary();
              ref.read(chatProvider.notifier).clearHistory();
              ref.read(tmdbProvider.notifier).fetchTrending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm veriler başarıyla sıfırlandı.')),
                );
              }
            },
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
  }
}
