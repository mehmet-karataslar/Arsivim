class ScanPage {
  const ScanPage(this.path, {this.quarterTurns = 0, this.isCompressed = false});
  final String path;
  final int quarterTurns;
  // Persist this with the draft to avoid repeated lossy JPEG encoding on edits.
  final bool isCompressed;
  ScanPage rotated() => ScanPage(
    path,
    quarterTurns: (quarterTurns + 1) % 4,
    isCompressed: isCompressed,
  );
  Map<String, dynamic> toJson() => {
    'path': path,
    'turns': quarterTurns,
    'compressed': isCompressed,
  };
  factory ScanPage.fromJson(Map<String, dynamic> value) => ScanPage(
    value['path'] as String,
    quarterTurns: (value['turns'] as int? ?? 0) % 4,
    isCompressed: value['compressed'] == true,
  );
}
