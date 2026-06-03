import '../model/sync_queue_entry.dart';

enum SyncOutcome { accepted, conflicted, rejected }

class SyncEntryResult {
  final String entryId;
  final SyncOutcome outcome;
  final int? serverSequence;
  final Map<String, dynamic>? serverPayload;
  final String? errorMessage;

  const SyncEntryResult._({
    required this.entryId,
    required this.outcome,
    this.serverSequence,
    this.serverPayload,
    this.errorMessage,
  });

  factory SyncEntryResult.accepted({
    required String entryId,
    required int serverSequence,
  }) {
    return SyncEntryResult._(
      entryId: entryId,
      outcome: SyncOutcome.accepted,
      serverSequence: serverSequence,
    );
  }

  factory SyncEntryResult.conflicted({
    required String entryId,
    required Map<String, dynamic> serverPayload,
  }) {
    return SyncEntryResult._(
      entryId: entryId,
      outcome: SyncOutcome.conflicted,
      serverPayload: serverPayload,
    );
  }

  factory SyncEntryResult.rejected({
    required String entryId,
    String errorMessage = '',
  }) {
    return SyncEntryResult._(
      entryId: entryId,
      outcome: SyncOutcome.rejected,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    final msg = errorMessage;
    return {
      'entryId': entryId,
      'outcome': outcome.name,
      if (serverSequence != null) 'serverSequence': serverSequence,
      if (serverPayload != null) 'serverPayload': serverPayload,
      if (msg != null && msg.isNotEmpty) 'errorMessage': msg,
    };
  }

  factory SyncEntryResult.fromJson(Map<String, dynamic> json) {
    final outcome = SyncOutcome.values.firstWhere(
      (e) => e.name == json['outcome'],
      orElse: () => throw ArgumentError('Unknown outcome: ${json['outcome']}'),
    );
    switch (outcome) {
      case SyncOutcome.accepted:
        return SyncEntryResult.accepted(
          entryId: json['entryId'] as String,
          serverSequence: json['serverSequence'] as int,
        );
      case SyncOutcome.conflicted:
        return SyncEntryResult.conflicted(
          entryId: json['entryId'] as String,
          serverPayload: json['serverPayload'] as Map<String, dynamic>,
        );
      case SyncOutcome.rejected:
        return SyncEntryResult.rejected(
          entryId: json['entryId'] as String,
          errorMessage: json['errorMessage'] as String? ?? '',
        );
    }
  }
}

class PushEntry {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final String payload;
  final int localSequence;

  const PushEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.localSequence,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation.name,
    'payload': payload,
    'localSequence': localSequence,
  };
}

class PushRequest {
  final List<PushEntry> entries;
  const PushRequest(this.entries);
  Map<String, dynamic> toJson() => {'entries': entries.map((e) => e.toJson()).toList()};
}

class PushResponse {
  final List<SyncEntryResult> results;
  const PushResponse(this.results);
  factory PushResponse.fromJson(Map<String, dynamic> json) => PushResponse(
    (json['results'] as List).map((e) => SyncEntryResult.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class PullRequest {
  final String entityType;
  final int sinceSequence;
  const PullRequest({required this.entityType, required this.sinceSequence});
  Map<String, dynamic> toJson() => {'entityType': entityType, 'sinceSequence': sinceSequence};
}

class RemoteOperation {
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final int serverSequence;

  const RemoteOperation({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.serverSequence,
  });

  factory RemoteOperation.fromJson(Map<String, dynamic> json) => RemoteOperation(
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    operation: SyncOperation.values.firstWhere((e) => e.name == json['operation']),
    payload: json['payload'] as Map<String, dynamic>,
    serverSequence: json['serverSequence'] as int,
  );
}

class PullResponse {
  final List<RemoteOperation> operations;
  final int latestSequence;
  const PullResponse({required this.operations, required this.latestSequence});
  factory PullResponse.fromJson(Map<String, dynamic> json) => PullResponse(
    operations: (json['operations'] as List).map((e) => RemoteOperation.fromJson(e as Map<String, dynamic>)).toList(),
    latestSequence: json['latestSequence'] as int,
  );
}

abstract class RemoteAdapter {
  Future<PushResponse> push(PushRequest request);
  Future<PullResponse> pull(PullRequest request);
}
