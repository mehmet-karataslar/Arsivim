class SenkronCihazi {
  final String id;
  final String ad;
  final String ip;
  final String mac;
  final String platform;
  final DateTime sonGorulen;
  final bool aktif;
  final int belgeSayisi;
  final int toplamBoyut;

  SenkronCihazi({
    required this.id,
    required this.ad,
    required this.ip,
    required this.mac,
    required this.platform,
    required this.sonGorulen,
    required this.aktif,
    required this.belgeSayisi,
    required this.toplamBoyut,
  });

  factory SenkronCihazi.fromJson(Map<String, dynamic> json) {
    return SenkronCihazi(
      id: json['id'] ?? '',
      ad: json['ad'] ?? '',
      ip: json['ip'] ?? '',
      mac: json['mac'] ?? '',
      platform: json['platform'] ?? '',
      sonGorulen: DateTime.parse(
        json['sonGorulen'] ?? DateTime.now().toIso8601String(),
      ),
      aktif: json['aktif'] ?? false,
      belgeSayisi: json['belgeSayisi'] ?? 0,
      toplamBoyut: json['toplamBoyut'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ad': ad,
      'ip': ip,
      'mac': mac,
      'platform': platform,
      'sonGorulen': sonGorulen.toIso8601String(),
      'aktif': aktif,
      'belgeSayisi': belgeSayisi,
      'toplamBoyut': toplamBoyut,
    };
  }

  SenkronCihazi copyWith({
    String? id,
    String? ad,
    String? ip,
    String? mac,
    String? platform,
    DateTime? sonGorulen,
    bool? aktif,
    int? belgeSayisi,
    int? toplamBoyut,
  }) {
    return SenkronCihazi(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      platform: platform ?? this.platform,
      sonGorulen: sonGorulen ?? this.sonGorulen,
      aktif: aktif ?? this.aktif,
      belgeSayisi: belgeSayisi ?? this.belgeSayisi,
      toplamBoyut: toplamBoyut ?? this.toplamBoyut,
    );
  }

  @override
  String toString() {
    return 'SenkronCihazi(id: $id, ad: $ad, ip: $ip, platform: $platform, aktif: $aktif)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SenkronCihazi &&
        other.id == id &&
        other.ad == ad &&
        other.ip == ip;
  }

  @override
  int get hashCode {
    return id.hashCode ^ ad.hashCode ^ ip.hashCode;
  }
}
