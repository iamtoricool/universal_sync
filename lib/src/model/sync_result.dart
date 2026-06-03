class SyncResult {
  final int pushed;
  final int pulled;
  final int failed;
  final int conflicted;
  final Duration duration;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.conflicted = 0,
    this.duration = Duration.zero,
  });

  bool get hasErrors => failed > 0;
  bool get hasConflicts => conflicted > 0;
  bool get isClean => !hasErrors && !hasConflicts;
}
