/// How confident a transport is that a failed request was applied remotely.
enum DeliveryCertainty {
  /// The request provably never reached the server (offline, DNS failure,
  /// connection refused, rate limited before processing). A change in this
  /// state stays coalescible.
  notSent,

  /// The request may have reached the server (timeout, reset after write, 5xx).
  /// Such changes are immutable and are replayed as-is.
  maybeApplied,
}
