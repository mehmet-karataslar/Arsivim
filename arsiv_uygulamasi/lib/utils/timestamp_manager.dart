import 'dart:io';
import 'dart:convert';
import 'dart:async';

/// SADELEŞTİRİLMİŞ Zaman damgası yönetimi utilities
/// Sadece temel timestamp işlemleri
class TimestampManager {
  static final TimestampManager _instance = TimestampManager._internal();
  static TimestampManager get instance => _instance;
  TimestampManager._internal();

  /// Mevcut zaman damgasını al
  DateTime getCurrentTimestamp() {
    return DateTime.now();
  }

  /// ISO 8601 formatında zaman damgası
  String getCurrentTimestampIso() {
    return DateTime.now().toIso8601String();
  }

  /// UTC zaman damgası
  DateTime getCurrentTimestampUtc() {
    return DateTime.now().toUtc();
  }

  /// Zaman damgalarını karşılaştır
  int compareTimestamps(DateTime timestamp1, DateTime timestamp2) {
    return timestamp1.compareTo(timestamp2);
  }

  /// Zaman damgası farkını hesapla
  Duration getTimestampDifference(DateTime timestamp1, DateTime timestamp2) {
    return timestamp1.difference(timestamp2);
  }

  /// Zaman damgasını formatlı string'e çevir
  String formatTimestamp(DateTime timestamp) {
    return timestamp.toIso8601String().substring(0, 19).replaceAll('T', ' ');
  }

  /// String'den zaman damgasını parse et
  DateTime parseTimestamp(String timestampString) {
    try {
      return DateTime.parse(timestampString);
    } catch (e) {
      throw FormatException('Geçersiz zaman damgası formatı: $timestampString');
    }
  }

  /// İki zaman damgasının aynı olup olmadığını kontrol et
  bool areTimestampsEqual(
    DateTime timestamp1,
    DateTime timestamp2, {
    Duration? tolerance,
  }) {
    if (tolerance == null) {
      return timestamp1.isAtSameMomentAs(timestamp2);
    }

    final difference = timestamp1.difference(timestamp2).abs();
    return difference <= tolerance;
  }

  /// Relative timestamp oluştur (X dakika önce gibi)
  String formatRelativeTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks hafta önce';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yıl önce';
    }
  }

  /// Human readable timestamp
  String formatHumanReadableTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Timestamp validation
  bool isValidTimestamp(DateTime timestamp) {
    // Reasonable date range check (1970 - 2100)
    final minDate = DateTime(1970);
    final maxDate = DateTime(2100);

    return timestamp.isAfter(minDate) && timestamp.isBefore(maxDate);
  }

  /// Backup timestamp oluştur
  String createBackupTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
