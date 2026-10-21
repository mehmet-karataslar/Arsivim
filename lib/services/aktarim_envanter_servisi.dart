import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/kimlik_normalizasyonu.dart';
import 'guvenli_aktarim_servisi.dart';

/// Discovery only: stored hashes are hints, never verified transfer receipts.
/// Send selected local IDs through the existing protocol-3 transfer engine.
class AktarimEnvanterServisi {
  static const inventoryVersion = 1;
  static const maxPageSize = 200;
  static const maxPageBytes = 220 * 1024;
  final GuvenliAktarimServisi engine;

  AktarimEnvanterServisi(this.engine);

  /// Keyset cursor is the *source-local* document ID, not a universal ID.
  /// Only active documents are advertised. A null next means end of inventory.
  /// Responses stay strictly below 220 KiB of UTF-8 JSON; an oversized single
  /// entry throws ENVANTER_BOYUT instead of being omitted from discovery.
  /// No files are opened or hashed and no business rows/sync flags are changed.
  /// The engine may persist missing universal IDs, exactly as for a transfer.
  ///
  /// Pages are live discovery, not a multi-page database snapshot. If a row is
  /// edited/deactivated during enumeration, retry discovery; always rebuild the
  /// engine packet before sending. Invalid rows fail the page, never disappear
  /// silently from an inventory used to decide what is new.
  Future<Map<String, dynamic>> page({int? afterId, int limit = 200}) async {
    if (limit < 1 || limit > maxPageSize) {
      throw RangeError.range(limit, 1, maxPageSize, 'limit');
    }
    if (afterId != null && afterId < 0) {
      throw RangeError.value(afterId, 'afterId', 'Must be nonnegative');
    }
    await engine.hazirla();
    final rows = await engine.db.query(
      'belgeler',
      columns: ['id'],
      where: 'aktif = 1 AND id > ?',
      whereArgs: [afterId ?? 0],
      orderBy: 'id ASC',
      limit: limit + 1,
    );
    final items = <Map<String, dynamic>>[];
    var itemBytes = 0;
    Map<String, dynamic> envelope(
      List<Map<String, dynamic>> entries,
      int? next,
    ) => {
      'success': true,
      'inventoryVersion': inventoryVersion,
      'protocolVersion': GuvenliAktarimServisi.surum,
      'items': entries,
      'next': next,
    };
    for (final row in rows.take(limit)) {
      final id = row['id'] as int;
      // Canonical IDs (including archive-owner IDs) belong to the engine.
      final packet = await engine.paketOlustur(id);
      final item = await engine.db.transaction((tx) async {
        final canonicalId = packet['evrensel_belge_id'] as String;
        final aliases = await _aliases(
          tx,
          'belge',
          canonicalId,
          expectedLocalId: id,
        );
        final links = <String, List<Map<String, dynamic>>>{};
        final metadata =
            Map<String, dynamic>.from(packet['belge'] as Map)
              ..remove('dosya_hash')
              ..remove('guncelleme_tarihi')
              ..remove('son_erisim_tarihi');
        for (final kind in ['kisi', 'kategori']) {
          final extra = packet['baglantilar'] as Map?;
          final refs = <Map>[
            if (packet[kind] != null) packet[kind] as Map,
            ...((extra?[kind] as List?) ?? const []).cast<Map>(),
          ];
          links[kind] = [];
          for (final ref in refs) {
            final business = _referenceMetadata(kind, ref);
            links[kind]!.add({
              'ids': await _aliases(tx, kind, ref['evrensel_id'] as String),
              'signature': _hash(business),
            });
          }
          // Primary link is significant. Additional links are an unordered
          // multiset; retaining duplicates avoids collapsing distinct people.
          final signatures = links[kind]!.map((r) => r['signature']).toList();
          metadata[kind] = {
            'primary': signatures.firstOrNull,
            'additional': signatures.skip(1).toList()..sort(),
          };
        }
        final contentHash = packet['belge']['dosya_hash'] as String;
        final metadataHash = _hash(metadata);
        return <String, dynamic>{
          'inventoryVersion': inventoryVersion,
          'id': id,
          'canonicalId': canonicalId,
          'ids': aliases,
          'contentHash': contentHash,
          'metadataHash': metadataHash,
          'signature': _hash([inventoryVersion, contentHash, metadataHash]),
          'size': packet['belge']['dosya_boyutu'],
          'title': packet['belge']['baslik'],
          'fileName': packet['belge']['orijinal_dosya_adi'],
          'links': links,
        };
      });
      final encodedSize = utf8.encode(jsonEncode(item)).length;
      final next = rows.length > items.length + 1 ? id : null;
      final totalSize =
          utf8.encode(jsonEncode(envelope([], next))).length +
          itemBytes +
          encodedSize +
          items.length;
      if (totalSize >= maxPageBytes) {
        if (items.isEmpty) {
          throw AktarimHatasi(
            'ENVANTER_BOYUT',
            'Document $id inventory exceeds the 220 KiB response budget.',
          );
        }
        break;
      }
      items.add(item);
      itemBytes += encodedSize;
    }
    return envelope(
      items,
      rows.length > items.length ? items.last['id'] as int : null,
    );
  }

  static Map<String, dynamic> _referenceMetadata(String kind, Map ref) {
    if (kind == 'kisi') {
      return {
        'ad': KimlikNormalizasyonu.metin(ref['ad'] as String),
        'soyad': KimlikNormalizasyonu.metin(ref['soyad'] as String),
        'kullanici_adi': KimlikNormalizasyonu.kullanici(ref['kullanici_adi']),
      };
    }
    // Categories are matched exactly by the verified engine, unlike people.
    return {
      for (final key in ['kategori_adi', 'renk_kodu', 'simge_kodu', 'aciklama'])
        key: ref[key],
    };
  }

  static Future<List<String>> _aliases(
    DatabaseExecutor tx,
    String kind,
    String canonicalId, {
    int? expectedLocalId,
  }) async {
    final mappings = await tx.query(
      'aktarim_kimlikleri',
      columns: ['yerel_id'],
      where: 'tur = ? AND evrensel_id = ?',
      whereArgs: [kind, canonicalId],
    );
    int? localId = mappings.firstOrNull?['yerel_id'] as int?;
    if (kind == 'kisi') {
      final tables = await tx.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'arsiv_hesabi'",
      );
      if (tables.isNotEmpty) {
        final owner = await tx.query(
          'arsiv_hesabi',
          columns: ['yerel_kisi_id'],
          where: 'yonetici_id = ?',
          whereArgs: [canonicalId],
        );
        if (owner.isNotEmpty) {
          final ownerId = owner.single['yerel_kisi_id'] as int;
          if (localId != null && localId != ownerId) {
            throw AktarimHatasi('ENVANTER_KIMLIK', 'Owner alias is ambiguous.');
          }
          localId = ownerId;
        }
      }
    }
    if (localId == null) {
      throw AktarimHatasi('ENVANTER_KIMLIK', 'Universal identity disappeared.');
    }
    if (expectedLocalId != null && expectedLocalId != localId) {
      throw AktarimHatasi('ENVANTER_KIMLIK', 'Document identity changed.');
    }
    final rows = await tx.query(
      'aktarim_kimlikleri',
      columns: ['evrensel_id'],
      where: 'tur = ? AND yerel_id = ?',
      whereArgs: [kind, localId],
    );
    return {
        canonicalId,
        ...rows.map((row) => row['evrensel_id'] as String),
      }.toList()
      ..sort();
  }

  /// Compare COMPLETE inventories from one peer connection, never an individual
  /// page or a union of several peers. Numeric IDs are scoped to their source.
  /// Identical retry pages are deduplicated; inconsistent retries fail closed.
  /// Set either completeness flag false while fetching: absence cannot yet be
  /// interpreted as new. No identity mappings or business rows are merged here.
  ///
  /// Only localNewIds / remoteNewIds are eligible for automatic direction
  /// selection. conflicts contains {localIds, remoteIds, reason}; byLocalId has
  /// string local-ID keys and {status: new|same|conflict, remoteIds, reason}
  /// values. same is the document count, not the number of matching aliases.
  /// "same" is metadata equality, NOT proof of intact on-disk bytes or an ACK.
  static Map<String, dynamic> compare(
    Iterable<Map<String, dynamic>> localItems,
    Iterable<Map<String, dynamic>> remoteItems, {
    bool localComplete = true,
    bool remoteComplete = true,
  }) {
    if (!localComplete || !remoteComplete) {
      throw StateError('Complete both peer inventories before comparing.');
    }
    final local = _index(localItems);
    final remote = _index(remoteItems);
    final localNew = <int>[];
    final remoteNew = <int>[];
    final sameLocal = <int>[];
    final sameRemote = <int>[];
    final conflicts = <Map<String, dynamic>>[];
    final byLocalId = <String, Map<String, dynamic>>{};
    final visitedLocal = <int>{};
    final visitedRemote = <int>{};

    // Connected components catch alias bridges and duplicate content on BOTH
    // sides. A matching hash must never override a divergent known identity.
    for (final seed in local.items.keys) {
      if (visitedLocal.contains(seed)) continue;
      final left = <int>{};
      final right = <int>{};
      final queue = <(bool, int)>[(true, seed)];
      final expandedKeys = <String>{};
      for (var i = 0; i < queue.length; i++) {
        final (isLocal, id) = queue[i];
        final set = isLocal ? left : right;
        if (!set.add(id)) continue;
        final entry = (isLocal ? local : remote).items[id]!;
        for (final key in _keys(entry)) {
          if (!expandedKeys.add(key)) continue;
          queue.addAll(
            (local.keys[key] ?? const <int>[]).map((id) => (true, id)),
          );
          queue.addAll(
            (remote.keys[key] ?? const <int>[]).map((id) => (false, id)),
          );
        }
      }
      visitedLocal.addAll(left);
      visitedRemote.addAll(right);
      final leftIds = left.toList()..sort();
      final rightIds = right.toList()..sort();
      String? reason;
      String status;
      if (left.length > 1 || right.length > 1) {
        status = 'conflict';
        reason = 'ambiguous_identity';
      } else if (right.isEmpty) {
        status = 'new';
        localNew.add(left.single);
      } else {
        final a = local.items[left.single]!;
        final b = remote.items[right.single]!;
        final sharedId = (a['ids'] as List).any(
          (id) => (b['ids'] as List).contains(id),
        );
        if (!sharedId) {
          status = 'conflict';
          reason = 'same_content_distinct_ids';
        } else if (a['contentHash'] != b['contentHash']) {
          status = 'conflict';
          reason = 'content_changed';
        } else if (a['signature'] != b['signature']) {
          status = 'conflict';
          reason = 'metadata_changed';
        } else if (!_sameLinks(a['links'] as Map, b['links'] as Map)) {
          status = 'conflict';
          reason = 'link_identity_unconfirmed';
        } else {
          status = 'same';
          sameLocal.add(left.single);
          sameRemote.add(right.single);
        }
      }
      if (status == 'conflict') {
        conflicts.add({
          'localIds': leftIds,
          'remoteIds': rightIds,
          'reason': reason,
        });
      }
      for (final id in left) {
        byLocalId['$id'] = {
          'status': status,
          'remoteIds': rightIds,
          'reason': reason,
        };
      }
    }
    // Remote-only duplicates are also unsafe automatic-send candidates.
    final remaining =
        remote.items.values
            .where((r) => !visitedRemote.contains(r['id']))
            .toList();
    if (remaining.isNotEmpty) {
      final reverse = compare(remaining, const <Map<String, dynamic>>[]);
      remoteNew.addAll((reverse['localNewIds'] as List).cast<int>());
      for (final conflict in reverse['conflicts'] as List) {
        conflicts.add({
          'localIds': <int>[],
          'remoteIds': conflict['localIds'],
          'reason': conflict['reason'],
        });
      }
    }
    return {
      'localNewIds': localNew..sort(),
      'remoteNewIds': remoteNew..sort(),
      'conflicts': conflicts,
      'same': sameLocal.length,
      'sameLocalIds': sameLocal..sort(),
      'sameRemoteIds': sameRemote..sort(),
      'byLocalId': byLocalId,
    };
  }

  static bool _sameLinks(Map a, Map b) {
    for (final kind in ['kisi', 'kategori']) {
      final left = (a[kind] as List).cast<Map>();
      final right = (b[kind] as List).cast<Map>();
      if (left.length != right.length) return false;
      bool matches(Map x, Map y) =>
          x['signature'] == y['signature'] &&
          (x['ids'] as List).any((id) => (y['ids'] as List).contains(id));
      // Ambiguous links are not resolved by display name or list order.
      final used = <int>{};
      for (var index = 0; index < left.length; index++) {
        final candidates = <int>[
          for (var i = 0; i < right.length; i++)
            if (matches(left[index], right[i])) i,
        ];
        if (candidates.length != 1 ||
            (index == 0 && candidates.single != 0) ||
            !used.add(candidates.single)) {
          return false;
        }
      }
    }
    return true;
  }

  static ({Map<int, Map<String, dynamic>> items, Map<String, List<int>> keys})
  _index(Iterable<Map<String, dynamic>> input) {
    final items = <int, Map<String, dynamic>>{};
    final keys = <String, List<int>>{};
    for (final item in input) {
      _validate(item);
      final id = item['id'] as int;
      if (items.containsKey(id)) {
        if (_json(items[id]) != _json(item)) {
          throw const FormatException(
            'Inventory changed during pagination; restart discovery.',
          );
        }
        continue;
      }
      items[id] = item;
      for (final key in _keys(item)) {
        (keys[key] ??= []).add(id);
      }
    }
    return (items: items, keys: keys);
  }

  static Iterable<String> _keys(Map item) sync* {
    for (final id in item['ids'] as List) {
      yield 'id:$id';
    }
    yield 'hash:${item['contentHash']}';
  }

  static void _validate(Map item) {
    bool idsValid(Object? value) =>
        value is List &&
        value.isNotEmpty &&
        value.every(
          (id) =>
              id is String &&
              id.trim().isNotEmpty &&
              id.length <= 160 &&
              !id.contains('\x00'),
        ) &&
        value.toSet().length == value.length;
    bool hashValid(Object? value) =>
        value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
    if (item['inventoryVersion'] != inventoryVersion ||
        item['id'] is! int ||
        (item['id'] as int) <= 0 ||
        !idsValid(item['ids']) ||
        !(item['ids'] as List).contains(item['canonicalId']) ||
        !hashValid(item['contentHash']) ||
        !hashValid(item['metadataHash']) ||
        item['signature'] !=
            _hash([
              inventoryVersion,
              item['contentHash'],
              item['metadataHash'],
            ]) ||
        item['size'] is! int ||
        (item['size'] as int) < 0 ||
        (item['size'] as int) > GuvenliAktarimServisi.azamiDosya ||
        item['links'] is! Map) {
      throw const FormatException('Invalid inventory entry.');
    }
    final links = item['links'] as Map;
    if (links.length != 2) throw const FormatException('Invalid link kinds.');
    for (final kind in ['kisi', 'kategori']) {
      final refs = links[kind];
      if (refs is! List ||
          refs.length > 101 ||
          refs.any(
            (ref) =>
                ref is! Map ||
                !idsValid(ref['ids']) ||
                !hashValid(ref['signature']),
          )) {
        throw const FormatException('Invalid inventory links.');
      }
    }
  }

  static String _hash(Object? value) =>
      sha256.convert(utf8.encode(_json(value))).toString();

  static String _json(Object? value) {
    Object? canonical(Object? v) {
      if (v is Map) {
        final keys = v.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: canonical(v[key])};
      }
      if (v is List) return v.map(canonical).toList();
      return v;
    }

    return jsonEncode(canonical(value));
  }
}
