import 'package:intl/intl.dart';

class DateFormatter {
  /// Returns a friendly formatted string such as "15 Ekim 2024" or "Oct 15, 2024"
  static String formatFriendly(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Bilinmiyor';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (_) {
      return isoString;
    }
  }

  /// Returns a short relative date like "3 gün önce", "2 ay önce"
  static String formatRelative(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays >= 365) {
        final years = (difference.inDays / 365).floor();
        return '$years yıl önce';
      } else if (difference.inDays >= 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ay önce';
      } else if (difference.inDays >= 7) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks hafta önce';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} gün önce';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat önce';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} dakika önce';
      } else {
        return 'Az önce';
      }
    } catch (_) {
      return '';
    }
  }

  /// Formats release year from "2024-05-12" to "2024"
  static String formatYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.length < 4) return '';
    return releaseDate.substring(0, 4);
  }
}
