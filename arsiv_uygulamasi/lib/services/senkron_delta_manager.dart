import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_delta.dart';
import '../models/senkron_metadata.dart';
import '../services/veritabani_servisi.dart';

/// Delta sync yönetimi için kullanılan servis
class SenkronDeltaManager {
  static final SenkronDeltaManager _instance = SenkronDeltaManager._internal();
  static SenkronDeltaManager get instance => _instance;
  SenkronDeltaManager._internal();

  // Callback fonksiyonları
  Function(String message)? onLogMessage;
  Function(SenkronDelta delta)? onDeltaGenerated;
  Function(int count)? onChangesDetected;

  /// Son senkronizasyondan beri değişen belgeleri tespit et
  Future<List<SenkronDelta>> generateLocalDeltas(DateTime? lastSyncTime) async {
    try {
      _log('🔄 Local delta üretimi başlatılıyor...');

      final deltas = <SenkronDelta>[];
      final veriTabani = VeriTabaniServisi();

      // Tüm belgeleri al
      final belgeler = await veriTabani.belgeleriGetir();

      // Son senkronizasyon zamanı yoksa tüm belgeler yeni kabul edilir
      final syncTime = lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0);

      _log('📅 Son senkronizasyon: ${syncTime.toIso8601String()}');

      int yeniBelgeSayisi = 0;
      int guncellenmisBelgeSayisi = 0;

      for (final belge in belgeler) {
        SenkronDeltaType deltaType;

        if (belge.olusturmaTarihi.isAfter(syncTime)) {
          // Yeni belge
          deltaType = SenkronDeltaType.create;
          yeniBelgeSayisi++;
        } else if (belge.guncellemeTarihi.isAfter(syncTime)) {
          // Güncellenen belge
          deltaType = SenkronDeltaType.update;
          guncellenmisBelgeSayisi++;
        } else {
          // Değişmemiş belge - delta'ya dahil etme
          continue;
        }

        // Delta oluştur
        final delta = SenkronDelta(
          id: _generateDeltaId(),
          documentId: belge.id?.toString() ?? '',
          documentHash: belge.dosyaHash ?? '',
          deltaType: deltaType,
          timestamp: DateTime.now(),
          metadata: _createMetadataFromBelge(belge),
          size: belge.dosyaBoyutu,
          priority: _calculatePriority(deltaType, belge),
        );

        deltas.add(delta);
        onDeltaGenerated?.call(delta);
      }

      // Silinmiş belgeleri kontrol et (şu an için basit implementation)
      // TODO: Soft delete tracking sistemi ekle

      _log('✅ Local delta üretimi tamamlandı');
      _log('   • Yeni belgeler: $yeniBelgeSayisi');
      _log('   • Güncellenen belgeler: $guncellenmisBelgeSayisi');
      _log('   • Toplam delta: ${deltas.length}');

      onChangesDetected?.call(deltas.length);

      return deltas;
    } catch (e) {
      _log('❌ Local delta üretimi hatası: $e');
      rethrow;
    }
  }

  /// Uzak cihazdan gelen delta'ları işle
  Future<List<SenkronDelta>> processRemoteDeltas(
    List<Map<String, dynamic>> remoteDeltaData,
  ) async {
    try {
      _log('📥 Remote delta işleme başlatılıyor...');

      final deltas = <SenkronDelta>[];

      for (final deltaData in remoteDeltaData) {
        try {
          final delta = SenkronDelta.fromJson(deltaData);
          deltas.add(delta);

          _log(
            '📦 Remote delta işlendi: ${delta.documentId} (${delta.deltaType.name})',
          );
        } catch (e) {
          _log('⚠️ Remote delta parse hatası: $e');
          continue;
        }
      }

      // Delta'ları timestamp'e göre sırala
      deltas.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _log('✅ Remote delta işleme tamamlandı: ${deltas.length} delta');

      return deltas;
    } catch (e) {
      _log('❌ Remote delta işleme hatası: $e');
      rethrow;
    }
  }

  /// Delta'ları karşılaştır ve konfliktleri tespit et
  Future<DeltaComparisonResult> compareDeltas(
    List<SenkronDelta> localDeltas,
    List<SenkronDelta> remoteDeltas,
  ) async {
    try {
      _log('🔍 Delta karşılaştırma başlatılıyor...');

      final result = DeltaComparisonResult(
        localOnly: [],
        remoteOnly: [],
        conflicts: [],
        identical: [],
      );

      // Local delta'ları indexle
      final localIndex = <String, SenkronDelta>{};
      for (final delta in localDeltas) {
        localIndex[delta.documentId] = delta;
      }

      // Remote delta'ları indexle
      final remoteIndex = <String, SenkronDelta>{};
      for (final delta in remoteDeltas) {
        remoteIndex[delta.documentId] = delta;
      }

      // Tüm benzersiz belge ID'lerini al
      final allDocIds = <String>{};
      allDocIds.addAll(localIndex.keys);
      allDocIds.addAll(remoteIndex.keys);

      for (final docId in allDocIds) {
        final localDelta = localIndex[docId];
        final remoteDelta = remoteIndex[docId];

        if (localDelta != null && remoteDelta != null) {
          // Her iki tarafta da var - karşılaştır
          if (localDelta.documentHash == remoteDelta.documentHash) {
            result.identical.add(localDelta);
          } else {
            // Conflict - timestamp kontrol et
            final timeDiff =
                localDelta.timestamp
                    .difference(remoteDelta.timestamp)
                    .inMinutes
                    .abs();

            if (timeDiff < 5) {
              // Simultaneous conflict
              result.conflicts.add(
                DeltaConflict(
                  localDelta: localDelta,
                  remoteDelta: remoteDelta,
                  conflictType: DeltaConflictType.simultaneousEdit,
                  severity: DeltaConflictSeverity.high,
                ),
              );
            } else {
              // Timestamp-based resolution
              result.conflicts.add(
                DeltaConflict(
                  localDelta: localDelta,
                  remoteDelta: remoteDelta,
                  conflictType: DeltaConflictType.timestampDifference,
                  severity: DeltaConflictSeverity.medium,
                ),
              );
            }
          }
        } else if (localDelta != null) {
          // Sadece local'de var
          result.localOnly.add(localDelta);
        } else if (remoteDelta != null) {
          // Sadece remote'da var
          result.remoteOnly.add(remoteDelta);
        }
      }

      _log('✅ Delta karşılaştırma tamamlandı');
      _log('   • Local only: ${result.localOnly.length}');
      _log('   • Remote only: ${result.remoteOnly.length}');
      _log('   • Conflicts: ${result.conflicts.length}');
      _log('   • Identical: ${result.identical.length}');

      return result;
    } catch (e) {
      _log('❌ Delta karşılaştırma hatası: $e');
      rethrow;
    }
  }

  /// Delta'ları boyutuna göre optimize et
  List<SenkronDelta> optimizeDeltas(List<SenkronDelta> deltas) {
    try {
      _log('⚡ Delta optimizasyonu başlatılıyor...');

      // Boyuta göre sırala (küçükten büyüğe)
      deltas.sort((a, b) => a.size.compareTo(b.size));

      // Prioritye göre yeniden sırala
      final prioritized = <SenkronDelta>[];
      final lowPriority = <SenkronDelta>[];

      for (final delta in deltas) {
        if (delta.priority >= 7) {
          prioritized.add(delta);
        } else {
          lowPriority.add(delta);
        }
      }

      // Yüksek prioriteyi başa al
      final optimized = [...prioritized, ...lowPriority];

      _log('✅ Delta optimizasyonu tamamlandı');
      _log('   • Yüksek priorite: ${prioritized.length}');
      _log('   • Düşük priorite: ${lowPriority.length}');

      return optimized;
    } catch (e) {
      _log('❌ Delta optimizasyonu hatası: $e');
      return deltas;
    }
  }

  /// Belge'den metadata oluştur
  SenkronMetadata _createMetadataFromBelge(BelgeModeli belge) {
    return SenkronMetadata(
      documentId: belge.id?.toString() ?? '',
      documentHash: belge.dosyaHash,
      lastSyncTime: DateTime.now(),
      lastModifiedTime: belge.guncellemeTarihi,
      properties: {
        'dosyaAdi': belge.dosyaAdi,
        'dosyaBoyutu': belge.dosyaBoyutu,
        'dosyaTipi': belge.dosyaTipi,
        'kategoriId': belge.kategoriId,
        'kisiId': belge.kisiId,
        'baslik': belge.baslik,
        'aciklama': belge.aciklama,
        'etiketler': belge.etiketler,
      },
    );
  }

  /// Delta ID üret
  String _generateDeltaId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString();
    return sha256.convert(utf8.encode(random)).toString().substring(0, 16);
  }

  /// Priority hesapla
  int _calculatePriority(SenkronDeltaType deltaType, BelgeModeli belge) {
    int priority = 5; // Varsayılan

    // Delta türüne göre
    switch (deltaType) {
      case SenkronDeltaType.create:
        priority += 2;
        break;
      case SenkronDeltaType.update:
        priority += 1;
        break;
      case SenkronDeltaType.delete:
        priority += 3;
        break;
    }

    // Dosya boyutuna göre (küçük dosyalar öncelikli)
    if (belge.dosyaBoyutu < 1024 * 1024) {
      // 1MB altı
      priority += 1;
    }

    // Metadata doluluğuna göre
    if (belge.baslik != null && belge.baslik!.isNotEmpty) priority += 1;
    if (belge.aciklama != null && belge.aciklama!.isNotEmpty) priority += 1;
    if (belge.etiketler != null && belge.etiketler!.isNotEmpty) priority += 1;

    return priority.clamp(1, 10);
  }

  /// Log mesajı
  void _log(String message) {
    print(message);
    onLogMessage?.call(message);
  }
}

/// Delta karşılaştırma sonucu
class DeltaComparisonResult {
  final List<SenkronDelta> localOnly;
  final List<SenkronDelta> remoteOnly;
  final List<DeltaConflict> conflicts;
  final List<SenkronDelta> identical;

  DeltaComparisonResult({
    required this.localOnly,
    required this.remoteOnly,
    required this.conflicts,
    required this.identical,
  });

  int get totalChanges =>
      localOnly.length + remoteOnly.length + conflicts.length;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasChanges => totalChanges > 0;
}

/// Delta conflict
class DeltaConflict {
  final SenkronDelta localDelta;
  final SenkronDelta remoteDelta;
  final DeltaConflictType conflictType;
  final DeltaConflictSeverity severity;

  DeltaConflict({
    required this.localDelta,
    required this.remoteDelta,
    required this.conflictType,
    required this.severity,
  });
}

/// Delta conflict türleri
enum DeltaConflictType { simultaneousEdit, timestampDifference, hashMismatch }

/// Delta conflict şiddeti
enum DeltaConflictSeverity { low, medium, high }
