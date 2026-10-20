import 'dart:convert';

import '../../domain/models/sync.dart';

/// 合并结果。
class SyncMergeResult {
  const SyncMergeResult({
    required this.document,
    required this.localChanged,
    required this.remoteChanged,
  });

  final SyncDocument document;

  /// 合并结果与本机不同，需要写回本地库。
  final bool localChanged;

  /// 合并结果与云端不同，需要上传。
  final bool remoteChanged;
}

/// LWW 合并。
///
/// 纯函数，不碰数据库、不碰网络，方便把「删除会不会复活」这类问题钉死在测试里。
class SyncMerger {
  const SyncMerger._();

  /// 墓碑保留期：过期墓碑直接丢弃，避免文档无限膨胀。
  static const Duration tombstoneRetention = Duration(days: 90);

  static SyncMergeResult merge({
    required SyncDocument local,
    SyncDocument? remote,
    required SyncConflictPolicy policy,
    int? now,
  }) {
    final int timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    final SyncDocument remoteDoc = remote ?? SyncDocument.empty(local.deviceId);

    final List<SyncFavorite> favorites = _merge<SyncFavorite>(
      local: local.favorites,
      remote: remoteDoc.favorites,
      id: (SyncFavorite e) => e.seriesId,
      version: (SyncFavorite e) => e.version,
      deleted: (SyncFavorite e) => e.isDeleted,
      policy: policy,
      now: timestamp,
    );
    final List<SyncProgress> progress = _merge<SyncProgress>(
      local: local.progress,
      remote: remoteDoc.progress,
      id: (SyncProgress e) => e.seriesId,
      version: (SyncProgress e) => e.version,
      deleted: (SyncProgress e) => e.isDeleted,
      policy: policy,
      now: timestamp,
    );
    final List<SyncSource> sources = _merge<SyncSource>(
      local: local.sources,
      remote: remoteDoc.sources,
      id: (SyncSource e) => e.id,
      version: (SyncSource e) => e.version,
      deleted: (SyncSource e) => e.isDeleted,
      policy: policy,
      now: timestamp,
    );
    final List<SyncSeries> series = _merge<SyncSeries>(
      local: local.series,
      remote: remoteDoc.series,
      id: (SyncSeries e) => e.id,
      version: (SyncSeries e) => e.updatedAt,
      deleted: (SyncSeries e) => false,
      policy: policy,
      now: timestamp,
    );

    final SyncDocument merged = SyncDocument(
      deviceId: local.deviceId,
      updatedAt: timestamp,
      favorites: favorites,
      progress: progress,
      sources: sources,
      series: series,
    );

    return SyncMergeResult(
      document: merged,
      localChanged: _fingerprint(local) != _fingerprint(merged),
      remoteChanged: _fingerprint(remoteDoc) != _fingerprint(merged),
    );
  }

  static List<T> _merge<T>({
    required List<T> local,
    required List<T> remote,
    required String Function(T) id,
    required int Function(T) version,
    required bool Function(T) deleted,
    required SyncConflictPolicy policy,
    required int now,
  }) {
    final Map<String, T> localMap = <String, T>{
      for (final T item in local) id(item): item,
    };
    final Map<String, T> remoteMap = <String, T>{
      for (final T item in remote) id(item): item,
    };
    final Set<String> keys = <String>{...localMap.keys, ...remoteMap.keys};
    final List<T> result = <T>[];

    for (final String key in keys) {
      final T? a = localMap[key];
      final T? b = remoteMap[key];
      final T? winner = _pick(a, b, policy, version, deleted);
      if (winner == null) continue;
      // 过期墓碑不再传播。
      if (deleted(winner)) {
        final int tombstoneAge = now - version(winner);
        if (tombstoneAge > tombstoneRetention.inMilliseconds) continue;
      }
      result.add(winner);
    }

    result.sort((T a, T b) => id(a).compareTo(id(b)));
    return result;
  }

  static T? _pick<T>(
    T? local,
    T? remote,
    SyncConflictPolicy policy,
    int Function(T) version,
    bool Function(T) deleted,
  ) {
    if (local == null) return remote;
    if (remote == null) return local;
    switch (policy) {
      case SyncConflictPolicy.local:
        return local;
      case SyncConflictPolicy.remote:
        return remote;
      case SyncConflictPolicy.newest:
        final int a = version(local);
        final int b = version(remote);
        if (a == b) {
          // 时间相同：删除优先，保证删除不会因为「同一毫秒」而丢失。
          if (deleted(local) != deleted(remote)) {
            return deleted(local) ? local : remote;
          }
          return local;
        }
        return a > b ? local : remote;
    }
  }

  /// 只比较内容，忽略文档级的 deviceId/updatedAt。
  static String _fingerprint(SyncDocument doc) {
    List<Map<String, dynamic>> sorted<T>(
      List<T> items,
      String Function(T) id,
      Map<String, dynamic> Function(T) toJson,
    ) {
      final List<T> copy = List<T>.of(items)
        ..sort((T a, T b) => id(a).compareTo(id(b)));
      return copy.map(toJson).toList();
    }

    return jsonEncode(<String, Object?>{
      'favorites': sorted<SyncFavorite>(doc.favorites, (SyncFavorite e) => e.seriesId, (SyncFavorite e) => e.toJson()),
      'progress': sorted<SyncProgress>(doc.progress, (SyncProgress e) => e.seriesId, (SyncProgress e) => e.toJson()),
      'sources': sorted<SyncSource>(doc.sources, (SyncSource e) => e.id, (SyncSource e) => e.toJson()),
      'series': sorted<SyncSeries>(doc.series, (SyncSeries e) => e.id, (SyncSeries e) => e.toJson()),
    });
  }
}
