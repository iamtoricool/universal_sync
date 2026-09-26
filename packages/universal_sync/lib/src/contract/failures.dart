import 'delivery.dart';

/// Stable classification codes persisted with dead letters.
enum SyncFailureCode {
  auth,
  forbidden,
  rateLimited,
  transient,
  revisionConflict,
  permanent,
  unknown,
}

/// A typed transport failure. Adapters must map backend errors to one of these
/// variants; the engine never inspects error strings.
sealed class SyncFailure implements Exception {
  const SyncFailure(
    this.message, {
    this.retryAfter,
    this.certainty = DeliveryCertainty.maybeApplied,
  });

  final String message;
  final Duration? retryAfter;
  final DeliveryCertainty certainty;

  SyncFailureCode get code;

  bool get retryable;

  Map<String, Object?> toJson() => {
    'code': code.name,
    'message': message,
    if (retryAfter != null) 'retryAfterMs': retryAfter!.inMilliseconds,
    'certainty': certainty.name,
  };

  /// Forward-compatible reconstruction used for persisted dead letters.
  static SyncFailure fromJson(Map<String, Object?> json) {
    final code = json['code'] as String?;
    final message = json['message'] as String? ?? 'unknown failure';
    final retryAfterMs = json['retryAfterMs'] as int?;
    final certainty = json['certainty'] == DeliveryCertainty.notSent.name
        ? DeliveryCertainty.notSent
        : DeliveryCertainty.maybeApplied;
    final retryAfter = retryAfterMs == null ? null : Duration(milliseconds: retryAfterMs);

    return switch (code) {
      'auth' => AuthFailure(message),
      'forbidden' => ForbiddenFailure(message),
      'rateLimited' => RateLimited(message, retryAfter: retryAfter),
      'transient' => TransientFailure(message, certainty: certainty),
      'revisionConflict' => RevisionConflict(
        message,
        serverRow: (json['serverRow'] as Map?)?.cast<String, Object?>(),
      ),
      'permanent' => PermanentFailure(message),
      _ => UnknownFailure(message, certainty: certainty),
    };
  }

  @override
  String toString() => 'SyncFailure(${code.name}): $message';
}

/// Authentication is missing or expired. Stops the drain; the app must re-auth.
final class AuthFailure extends SyncFailure {
  const AuthFailure(super.message) : super(certainty: DeliveryCertainty.notSent);

  @override
  SyncFailureCode get code => SyncFailureCode.auth;

  @override
  bool get retryable => false;
}

/// The backend rejected this change by policy (RLS, ownership, forbidden).
final class ForbiddenFailure extends SyncFailure {
  const ForbiddenFailure(super.message) : super(certainty: DeliveryCertainty.notSent);

  @override
  SyncFailureCode get code => SyncFailureCode.forbidden;

  @override
  bool get retryable => false;
}

/// The backend rate limited the batch. Honour [retryAfter].
final class RateLimited extends SyncFailure {
  const RateLimited(
    super.message, {
    super.retryAfter,
    super.certainty = DeliveryCertainty.notSent,
  });

  @override
  SyncFailureCode get code => SyncFailureCode.rateLimited;

  @override
  bool get retryable => true;
}

/// Transport-level failure (offline, timeout, 5xx).
final class TransientFailure extends SyncFailure {
  const TransientFailure(
    super.message, {
    super.certainty = DeliveryCertainty.maybeApplied,
  });

  @override
  SyncFailureCode get code => SyncFailureCode.transient;

  @override
  bool get retryable => true;
}

/// The server holds a conflicting revision. [serverRow] is authoritative.
final class RevisionConflict extends SyncFailure {
  const RevisionConflict(super.message, {this.serverRow}) : super(certainty: DeliveryCertainty.notSent);

  final Map<String, Object?>? serverRow;

  @override
  SyncFailureCode get code => SyncFailureCode.revisionConflict;

  @override
  bool get retryable => true;

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    if (serverRow != null) 'serverRow': serverRow,
  };
}

/// Permanent validation failure. The change is parked, never silently dropped.
final class PermanentFailure extends SyncFailure {
  const PermanentFailure(super.message) : super(certainty: DeliveryCertainty.notSent);

  @override
  SyncFailureCode get code => SyncFailureCode.permanent;

  @override
  bool get retryable => false;
}

/// Unknown failure from a newer adapter version. Treated as permanent.
final class UnknownFailure extends SyncFailure {
  const UnknownFailure(
    super.message, {
    super.certainty = DeliveryCertainty.maybeApplied,
  });

  @override
  SyncFailureCode get code => SyncFailureCode.unknown;

  @override
  bool get retryable => false;
}

/// Thrown locally when a payload exceeds [SyncOptions.maxPayloadBytes].
class PayloadTooLargeException implements Exception {
  const PayloadTooLargeException({required this.bytes, required this.limit});

  final int bytes;
  final int limit;

  @override
  String toString() => 'PayloadTooLargeException: payload is $bytes bytes, limit is $limit.';
}

/// Thrown when a synced row carries an owner different from the session user.
class OwnershipViolation implements Exception {
  const OwnershipViolation({required this.table, required this.owner});

  final String table;
  final Object? owner;

  @override
  String toString() =>
      'OwnershipViolation: $table row owned by $owner does not match the '
      'authenticated session user.';
}
