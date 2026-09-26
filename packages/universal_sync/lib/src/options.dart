import 'dart:math' as math;

import 'conflict.dart';
import 'contract/session.dart';

/// Backoff policy for retryable failures.
sealed class Backoff {
  const Backoff();

  Duration delayFor(int failures);
}

/// Exponential backoff with optional jitter, capped at [max].
final class ExponentialBackoff extends Backoff {
  const ExponentialBackoff({
    this.initial = const Duration(seconds: 1),
    this.factor = 2,
    this.max = const Duration(minutes: 5),
    this.jitter = 0.2,
  });

  final Duration initial;
  final double factor;
  final Duration max;

  /// Fractional jitter in `[0, 1)`. Set to 0 for deterministic tests.
  final double jitter;

  @override
  Duration delayFor(int failures) {
    final exponent = failures < 0 ? 0 : failures;
    final base = initial.inMilliseconds * math.pow(factor, exponent);
    final capped = math.min(base.round(), max.inMilliseconds);
    if (jitter <= 0) return Duration(milliseconds: capped);
    final spread = (capped * jitter).round();
    final offset = spread == 0 ? 0 : math.Random().nextInt(spread * 2 + 1) - spread;
    return Duration(milliseconds: math.max(0, capped + offset));
  }
}

/// Constant delay between retries.
final class FixedBackoff extends Backoff {
  const FixedBackoff(this.delay);

  final Duration delay;

  @override
  Duration delayFor(int failures) => delay;
}

/// Retry immediately on the next drain.
final class NoBackoff extends Backoff {
  const NoBackoff();

  @override
  Duration delayFor(int failures) => Duration.zero;
}

/// Engine configuration. Every option is read; no dead knobs.
final class SyncOptions {
  const SyncOptions({
    this.pushBatchSize = 50,
    this.pullPageSize = 500,
    this.maxPayloadBytes = 1024 * 1024,
    this.maxBatchBytes = 4 * 1024 * 1024,
    this.backoff = const ExponentialBackoff(),
    this.maxAttempts = 3,
    this.maxDrainIterations = 1000,
    this.drainTimeBudget = const Duration(seconds: 30),
    this.lease = const Duration(minutes: 2),
    this.tombstoneRetention = const Duration(days: 30),
    this.maxOutboxBytes = 32 * 1024 * 1024,
    this.autoDrain = false,
    this.autoDrainDebounce = const Duration(milliseconds: 500),
    this.pushConcurrency = 1,
    this.pullConcurrency = 1,
    this.skipUnchangedPulls = true,
    this.conflictPolicy = const NewestWins(),
    this.purgeOnUserChange = true,
    this.stampUpdatedAt = true,
    this.cancelUnsyncedCreateThenDelete = false,
    this.promoteDependentUpdates = true,
    this.emitPayloads = false,
    this.validateSchema = true,
    this.clock = const SystemClock(),
    this.instanceId,
  });

  final int pushBatchSize;
  final int pullPageSize;
  final int maxPayloadBytes;
  final int maxBatchBytes;
  final Backoff backoff;

  /// Budget for non-transient failures before a change is parked.
  final int maxAttempts;

  final int maxDrainIterations;
  final Duration drainTimeBudget;
  final Duration lease;
  final Duration tombstoneRetention;
  final int maxOutboxBytes;
  final bool autoDrain;
  final Duration autoDrainDebounce;

  /// Reserved for adapters that can push entities concurrently.
  final int pushConcurrency;

  /// Reserved for adapters that can pull entities concurrently.
  final int pullConcurrency;

  final bool skipUnchangedPulls;
  final ConflictPolicy conflictPolicy;
  final bool purgeOnUserChange;
  final bool stampUpdatedAt;
  final bool cancelUnsyncedCreateThenDelete;
  final bool promoteDependentUpdates;
  final bool emitPayloads;
  final bool validateSchema;
  final SyncClock clock;

  /// Overrides the generated identity of this DB instance (tests).
  final String? instanceId;
}
