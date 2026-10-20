import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_events.dart';
import '../../core/logger.dart';
import '../../core/storage/database.dart';
import '../../domain/models/sync.dart';
import '../repository/library_repository.dart';
import '../repository/source_repository.dart';
import 'sync_merge.dart';
import 'sync_settings.dart';
import 'webdav_client.dart';

/// 同步状态。
enum SyncState { idle, syncing, success, failed, disabled }

class SyncStatus {
  const SyncStatus({
    this.state = SyncState.idle,
    this.message,
    this.at,
  });

  final SyncState state;
  final String? message;
  final DateTime? at;

  bool get busy => state == SyncState.syncing;
}

class SyncOutcome {
  const SyncOutcome({
    required this.ok,
    this.pulled = false,
    this.pushed = false,
    this.message,
  });

  final bool ok;
  final bool pulled;
  final bool pushed;
  final String? message;
}

/// 跨设备同步服务。
///
/// 触发时机：启动后 3 秒、收藏/源变更后 8 秒（防抖）、停止播放后 45 秒、
/// 以及设置页的「立即同步」。播放中的进度不会每 5 秒推一次云端。
class SyncService {
  SyncService({
    required LibraryRepository library,
    required SourceRepository sources,
    required AppDatabase database,
    WebDavClient Function(SyncSettings)? clientFactory,
  })  : _library = library,
        _sources = sources,
        _db = database,
        _clientFactory = clientFactory ?? ((SyncSettings settings) => WebDavClient(settings));

  final LibraryRepository _library;
  final SourceRepository _sources;
  final AppDatabase _db;
  final WebDavClient Function(SyncSettings) _clientFactory;

  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(const SyncStatus());

  Timer? _debounce;
  bool _started = false;
  bool _applying = false;
  bool _running = false;

  String get deviceId {
    final String? existing = _db.meta('deviceId');
    if (existing != null && existing.isNotEmpty) return existing;
    final String created = const Uuid().v4();
    _db.setMeta('deviceId', created);
    return created;
  }

  void start() {
    if (_started) return;
    _started = true;
    AppEvents.favorites.addListener(_onFavoritesChanged);
    AppEvents.sources.addListener(_onSourcesChanged);
    AppEvents.progress.addListener(_onProgressChanged);
    Timer(const Duration(seconds: 3), () => unawaited(syncNow()));
  }

  void dispose() {
    AppEvents.favorites.removeListener(_onFavoritesChanged);
    AppEvents.sources.removeListener(_onSourcesChanged);
    AppEvents.progress.removeListener(_onProgressChanged);
    _debounce?.cancel();
    status.dispose();
  }

  void _onFavoritesChanged() => schedule(const Duration(seconds: 8));
  void _onSourcesChanged() => schedule(const Duration(seconds: 8));
  void _onProgressChanged() => schedule(const Duration(seconds: 45));

  /// 防抖：每次变更都重置计时器，播放结束后才会真正上传。
  void schedule(Duration delay) {
    if (_applying) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
  }

  /// 立即同步。
  ///
  /// [force] 为 true 时忽略「自动同步开关」，用于设置页的手动触发。
  Future<SyncOutcome> syncNow({bool force = false}) async {
    if (_running) return const SyncOutcome(ok: false, message: 'busy');
    final SyncSettings settings = await SyncSettings.load();
    if (!settings.enabled && !force) {
      status.value = const SyncStatus(state: SyncState.disabled);
      return const SyncOutcome(ok: false, message: 'disabled');
    }
    if (!settings.isConfigured) {
      status.value = const SyncStatus(state: SyncState.disabled);
      return const SyncOutcome(ok: false, message: 'not-configured');
    }

    _running = true;
    status.value = SyncStatus(state: SyncState.syncing, at: DateTime.now());
    try {
      final WebDavClient client = _clientFactory(settings);
      final String? raw = await client.read();
      final SyncDocument? remote = _parse(raw);
      final SyncDocument local = _collect(settings);

      final SyncMergeResult merged = SyncMerger.merge(
        local: local,
        remote: remote,
        policy: settings.policy,
      );
      SyncDocument document = merged.document;
      bool localChanged = merged.localChanged;
      bool remoteChanged = merged.remoteChanged;

      if (!settings.syncSources) {
        // 不同步源时，云端源既不写回本地也不上传。
        document = document.copyWith(sources: local.sources);
        localChanged = false;
        remoteChanged = remoteChanged && (remote?.sources.isEmpty ?? true);
      }

      if (localChanged) {
        _applying = true;
        try {
          _library.applyFavorites(document.favorites);
          _library.applyProgress(document.progress);
          _library.applySeries(document.series);
          if (settings.syncSources) _sources.applySources(document.sources);
        } finally {
          _applying = false;
        }
      }

      if (remoteChanged || raw == null) {
        await client.write(
          const JsonEncoder.withIndent('  ').convert(document.toJson()),
        );
      }

      final DateTime now = DateTime.now();
      await SyncSettings.setLastSyncAt(now);
      status.value = SyncStatus(state: SyncState.success, at: now);
      appLogger.i(
        '同步完成：本地${localChanged ? '有' : '无'}变更，云端${remoteChanged ? '已' : '未'}更新',
      );
      return SyncOutcome(
        ok: true,
        pulled: localChanged,
        pushed: remoteChanged || raw == null,
      );
    } on Object catch (e, stack) {
      appLogger.e('同步失败', error: e, stackTrace: stack);
      status.value = SyncStatus(
        state: SyncState.failed,
        message: e.toString(),
        at: DateTime.now(),
      );
      return SyncOutcome(ok: false, message: e.toString());
    } finally {
      _running = false;
    }
  }

  SyncDocument _collect(SyncSettings settings) {
    return SyncDocument(
      deviceId: deviceId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      favorites: _library.exportFavorites(),
      progress: _library.exportProgress(),
      sources: settings.syncSources ? _sources.exportSources() : const <SyncSource>[],
      series: _library.exportSeries(),
    );
  }

  SyncDocument? _parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('remote sync document is malformed');
    }
    return SyncDocument.fromJson(decoded);
  }
}
