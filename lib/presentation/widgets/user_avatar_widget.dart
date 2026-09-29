import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_web_helper.dart';
import '../providers/settings_provider.dart';

class CinematicAvatarPreset {
  final String id;
  final String title;
  final String emoji;
  final List<Color> gradient;

  const CinematicAvatarPreset({
    required this.id,
    required this.title,
    required this.emoji,
    required this.gradient,
  });
}

class UserAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final bool showCameraBadge;
  final VoidCallback? onTap;
  final List<Color>? defaultGradient;

  const UserAvatarWidget({
    super.key,
    this.avatarUrl,
    this.size = 56.0,
    this.showCameraBadge = false,
    this.onTap,
    this.defaultGradient,
  });

  static const List<CinematicAvatarPreset> presets = [
    CinematicAvatarPreset(
      id: 'avatar:popcorn',
      title: 'Mısır Kovası',
      emoji: '🍿',
      gradient: [Color(0xFFFF9900), Color(0xFFFF5E3A)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:clapper',
      title: 'Klaket',
      emoji: '🎬',
      gradient: [Color(0xFF374151), Color(0xFF111827)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:camera',
      title: 'Sinema Kamerası',
      emoji: '🎥',
      gradient: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:masks',
      title: 'Tiyatro Maskesi',
      emoji: '🎭',
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:oscar',
      title: 'Oscar Heykeli',
      emoji: '🏆',
      gradient: [Color(0xFFFACC15), Color(0xFFEAB308)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:star',
      title: 'Altın Yıldız',
      emoji: '🌟',
      gradient: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:robot',
      title: 'CineAI Robot',
      emoji: '🤖',
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    CinematicAvatarPreset(
      id: 'avatar:lion',
      title: 'Sinema Aslanı',
      emoji: '🦁',
      gradient: [Color(0xFFF43F5E), Color(0xFFBE123C)],
    ),
  ];

  static Future<void> showAvatarSelectionSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1.5),
                  left: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                  right: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textLow.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primaryBlue, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Profil Fotoğrafı Seç',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Upload from device
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.file_upload_rounded, size: 18),
                      label: const Text(
                        '📁 Cihazdan / Galeriden Fotoğraf Yükle',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        final base64Image = await PlatformWebHelper.pickImageAsBase64();
                        if (base64Image != null) {
                          await ref.read(settingsProvider.notifier).updateAvatar(base64Image);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profil fotoğrafınız güncellendi! 📸')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'Hazır Sinematik Avatarlar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 12),

                  // 8 Cinematic Presets Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: presets.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 85,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (ctx, index) {
                      final preset = presets[index];
                      return InkWell(
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await ref.read(settingsProvider.notifier).updateAvatar(preset.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${preset.title} avatarı seçildi! ${preset.emoji}')),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: preset.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  preset.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              preset.title,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Varsayılan Avatara Sıfırla', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await ref.read(settingsProvider.notifier).updateAvatar(null);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Varsayılan avatar uygulandı.')),
                          );
                        }
                      },
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

  static Future<void> showEditUserNameDialog(BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName == 'Sinefil' ? '' : currentName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: AppColors.primaryAmber, size: 22),
            const SizedBox(width: 10),
            Text(
              'Kullanıcı Adını Değiştir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CineAI profilinizde ve kütüphane önerilerinizde görünecek adı belirleyin:',
              style: TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Örn: Ahmet Yılmaz',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryAmber, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryAmber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(settingsProvider.notifier).updateUserName(newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kullanıcı adı güncellendi: $newName ✨')),
                  );
                }
              }
            },
            child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarContent = _buildAvatarContent();

    Widget coreAvatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );

    if (showCameraBadge || onTap != null) {
      coreAvatar = Stack(
        clipBehavior: Clip.none,
        children: [
          coreAvatar,
          if (showCameraBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: EdgeInsets.all(size * 0.08),
                decoration: BoxDecoration(
                  color: AppColors.primaryAmber,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: size * 0.28,
                ),
              ),
            ),
        ],
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: coreAvatar,
        ),
      );
    }

    return coreAvatar;
  }

  Widget _buildAvatarContent() {
    final avatar = avatarUrl?.trim();

    // 1. Preset cinematic avatar
    if (avatar != null && avatar.startsWith('avatar:')) {
      final preset = presets.firstWhere(
        (p) => p.id == avatar,
        orElse: () => presets.first,
      );
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: preset.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            preset.emoji,
            style: TextStyle(fontSize: size * 0.52),
          ),
        ),
      );
    }

    // 2. Base64 data URL
    if (avatar != null && avatar.startsWith('data:image')) {
      try {
        final commaIndex = avatar.indexOf(',');
        final base64String = commaIndex != -1 ? avatar.substring(commaIndex + 1) : avatar;
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }

    // 3. Network URL (e.g. Google profile picture)
    if (avatar != null && (avatar.startsWith('http://') || avatar.startsWith('https://'))) {
      return Image.network(
        avatar,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.surfaceElevated,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    // 4. Fallback default
    return _buildFallback();
  }

  Widget _buildFallback() {
    final colors = defaultGradient ?? const [Color(0xFF10B981), Color(0xFF059669)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}
