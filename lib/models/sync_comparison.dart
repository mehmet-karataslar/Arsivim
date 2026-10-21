class SyncComparison {
  const SyncComparison({
    required this.sendIds,
    required this.receiveIds,
    required this.same,
    this.conflicts = const [],
    this.issues = const [],
  });
  final List<int> sendIds, receiveIds;
  final int same;
  final List<String> conflicts, issues;
}

enum SyncDirection { send, receive }

class SyncDirectionChoice {
  const SyncDirectionChoice(this.direction, this.comparison);
  final SyncDirection direction;
  final SyncComparison comparison;
}
