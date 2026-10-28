import 'package:universal_sync/universal_sync.dart';

/// Minimal adapter skeleton. Real adapters live in their own packages
/// (for example `universal_sync_supabase`) and map their backend errors to the
/// sealed [SyncFailure] hierarchy.
void main() {
  final transport = _DemoTransport();
  print('UniversalSync contract demo: ${transport.capabilities.cursors}');
}

final class _DemoTransport extends SyncTransport {
  @override
  SyncTransportCapabilities get capabilities => const SyncTransportCapabilities();

  @override
  Future<PushOutcome> push(PushBatch batch) async {
    // Send `batch.changes` to your backend and return one ack per change.
    return PushOutcome([
      for (final change in batch.changes) ChangeAck.applied(change.sequence),
    ]);
  }

  @override
  Future<PullPage> pull(PullPageRequest request) async {
    // Return full rows after `request.cursor`, plus deleted key lists.
    return const PullPage.empty();
  }
}
