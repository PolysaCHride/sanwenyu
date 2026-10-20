/// 跨设备同步的数据模型。
///
/// 设计要点：
/// - 每条记录带版本时间戳，合并时按时间取新（LWW）；
/// - 删除不直接消失，而是留下带 `deletedAt` 的墓碑，否则会被另一端复活；
/// - 文档整体带 `deviceId` 与 `updatedAt`，便于排查「谁覆盖了谁」。
library;

/// 冲突策略。
enum SyncConflictPolicy {
  /// 逐条按时间取新。
  newest,

  /// 以本机为准（云端只补充本机没有的记录）。
  local,

  /// 以云端为准。
  remote;

  String get storageValue => name;

  static SyncConflictPolicy fromStorage(String? value) {
    return switch (value) {
      'local' => SyncConflictPolicy.local,
      'remote' => SyncConflictPolicy.remote,
      _ => SyncConflictPolicy.newest,
    };
  }
}

class SyncFavorite {
  const SyncFavorite({
    required this.seriesId,
    required this.addedAt,
    this.deletedAt,
  });

  final String seriesId;
  final int addedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;
  int get version => deletedAt ?? addedAt;

  SyncFavorite copyWith({int? addedAt, int? deletedAt, bool clearDeleted = false}) {
    return SyncFavorite(
      seriesId: seriesId,
      addedAt: addedAt ?? this.addedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seriesId': seriesId,
        'addedAt': addedAt,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  factory SyncFavorite.fromJson(Map<String, dynamic> json) => SyncFavorite(
        seriesId: json['seriesId'] as String? ?? '',
        addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
        deletedAt: (json['deletedAt'] as num?)?.toInt(),
      );
}

class SyncProgress {
  const SyncProgress({
    required this.seriesId,
    required this.episodeId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    this.deletedAt,
  });

  final String seriesId;
  final String episodeId;
  final int positionMs;
  final int durationMs;
  final int updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;
  int get version => deletedAt ?? updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seriesId': seriesId,
        'episodeId': episodeId,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  factory SyncProgress.fromJson(Map<String, dynamic> json) => SyncProgress(
        seriesId: json['seriesId'] as String? ?? '',
        episodeId: json['episodeId'] as String? ?? '',
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
        deletedAt: (json['deletedAt'] as num?)?.toInt(),
      );
}

class SyncSource {
  const SyncSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.kind,
    required this.enabled,
    required this.priority,
    required this.updatedAt,
    this.ruleJson,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String kind;
  final String? ruleJson;
  final bool enabled;
  final int priority;
  final int updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;
  int get version => deletedAt ?? updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'kind': kind,
        if (ruleJson != null) 'ruleJson': ruleJson,
        'enabled': enabled,
        'priority': priority,
        'updatedAt': updatedAt,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  factory SyncSource.fromJson(Map<String, dynamic> json) => SyncSource(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        kind: json['kind'] as String? ?? 'rule',
        ruleJson: json['ruleJson'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        priority: (json['priority'] as num?)?.toInt() ?? 100,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
        deletedAt: (json['deletedAt'] as num?)?.toInt(),
      );
}

/// 收藏/进度指向的剧集元数据。
///
/// 没有它，新设备同步过来的收藏只会显示「未知剧集」。
class SyncSeries {
  const SyncSeries({
    required this.id,
    required this.sourceId,
    required this.sourceKey,
    required this.title,
    required this.updatedAt,
    this.cover,
    this.year,
    this.synopsis,
    this.rating,
  });

  final String id;
  final String sourceId;
  final String sourceKey;
  final String title;
  final String? cover;
  final int? year;
  final String? synopsis;
  final double? rating;
  final int updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sourceId': sourceId,
        'sourceKey': sourceKey,
        'title': title,
        if (cover != null) 'cover': cover,
        if (year != null) 'year': year,
        if (synopsis != null) 'synopsis': synopsis,
        if (rating != null) 'rating': rating,
        'updatedAt': updatedAt,
      };

  factory SyncSeries.fromJson(Map<String, dynamic> json) => SyncSeries(
        id: json['id'] as String? ?? '',
        sourceId: json['sourceId'] as String? ?? '',
        sourceKey: json['sourceKey'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        year: (json['year'] as num?)?.toInt(),
        synopsis: json['synopsis'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// 一次同步的完整负载。
class SyncDocument {
  const SyncDocument({
    required this.deviceId,
    required this.updatedAt,
    this.version = 1,
    this.favorites = const <SyncFavorite>[],
    this.progress = const <SyncProgress>[],
    this.sources = const <SyncSource>[],
    this.series = const <SyncSeries>[],
  });

  final int version;
  final String deviceId;
  final int updatedAt;
  final List<SyncFavorite> favorites;
  final List<SyncProgress> progress;
  final List<SyncSource> sources;
  final List<SyncSeries> series;

  factory SyncDocument.empty(String deviceId) =>
      SyncDocument(deviceId: deviceId, updatedAt: 0);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'deviceId': deviceId,
        'updatedAt': updatedAt,
        'favorites': favorites.map((SyncFavorite e) => e.toJson()).toList(),
        'progress': progress.map((SyncProgress e) => e.toJson()).toList(),
        'sources': sources.map((SyncSource e) => e.toJson()).toList(),
        'series': series.map((SyncSeries e) => e.toJson()).toList(),
      };

  factory SyncDocument.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) {
      final Object? raw = json[key];
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>
              e.map((dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v)))
          .toList();
    }

    return SyncDocument(
      version: (json['version'] as num?)?.toInt() ?? 1,
      deviceId: json['deviceId'] as String? ?? '',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      favorites: list('favorites').map(SyncFavorite.fromJson).toList(),
      progress: list('progress').map(SyncProgress.fromJson).toList(),
      sources: list('sources').map(SyncSource.fromJson).toList(),
      series: list('series').map(SyncSeries.fromJson).toList(),
    );
  }

  SyncDocument copyWith({
    String? deviceId,
    int? updatedAt,
    List<SyncFavorite>? favorites,
    List<SyncProgress>? progress,
    List<SyncSource>? sources,
    List<SyncSeries>? series,
  }) {
    return SyncDocument(
      version: version,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      favorites: favorites ?? this.favorites,
      progress: progress ?? this.progress,
      sources: sources ?? this.sources,
      series: series ?? this.series,
    );
  }
}
