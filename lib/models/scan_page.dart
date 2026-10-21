class ScanPage {
  const ScanPage(this.path, {this.quarterTurns = 0});
  final String path;
  final int quarterTurns;
  ScanPage rotated() => ScanPage(path, quarterTurns: (quarterTurns + 1) % 4);
  Map<String, dynamic> toJson() => {'path': path, 'turns': quarterTurns};
  factory ScanPage.fromJson(Map<String, dynamic> value) => ScanPage(
    value['path'] as String,
    quarterTurns: (value['turns'] as int? ?? 0) % 4,
  );
}
