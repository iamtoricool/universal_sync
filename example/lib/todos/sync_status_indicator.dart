import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_sync/universal_sync.dart';
import 'providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(syncStateProvider);
    final totalPendingAsync = ref.watch(totalPendingCountProvider);
    final pending = totalPendingAsync.valueOrNull ?? 0;

    final syncState = stateAsync.valueOrNull;

    return switch (syncState) {
      SyncIdle() => _idleBanner(context, syncState, pending),
      SyncInProgress() => _progressBanner(context, syncState),
      SyncError() => _errorBanner(context, ref, syncState, pending),
      null => const SizedBox(),
    };
  }

  Widget _idleBanner(BuildContext context, SyncIdle state, int pending) {
    final color = pending > 0 ? Colors.orange : Colors.green;
    final text = pending > 0
        ? '$pending pending'
        : _timeAgo(state.lastSyncedAt);
    return _banner(context, color, text);
  }

  Widget _progressBanner(BuildContext context, SyncInProgress state) {
    final phase = state.phase == SyncPhase.pushing ? 'Pushing' : 'Pulling';
    return _banner(
      context,
      Colors.blue,
      '$phase... ${state.processed}/${state.total}',
      leading: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
    );
  }

  Widget _errorBanner(
    BuildContext context,
    WidgetRef ref,
    SyncError state,
    int pending,
  ) {
    final msg = state.error.toString();
    final truncated = msg.length > 40 ? '${msg.substring(0, 40)}...' : msg;
    final text = pending > 0
        ? 'Sync failed: $truncated ($pending pending)'
        : 'Sync failed: $truncated';
    return _banner(
      context,
      Colors.red,
      text,
      trailing: TextButton(
        onPressed: () {
          final engine = ref.read(syncEngineProvider).valueOrNull;
          engine?.sync();
        },
        child: const Text(
          'Retry',
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
    );
  }

  Widget _banner(
    BuildContext context,
    Color color,
    String text, {
    Widget? leading,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
          ?trailing,
        ],
      ),
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Not synced yet';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Synced ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    return 'Synced ${diff.inHours}h ago';
  }
}
