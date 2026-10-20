import 'media.dart';

/// 收藏 / 历史用的剧集摘要。
class LibraryEntry {
  const LibraryEntry({
    required this.seriesId,
    required this.sourceId,
    required this.sourceKey,
    required this.title,
    required this.updatedAt,
    this.cover,
    this.year,
    this.positionMs,
    this.durationMs,
    this.episodeTitle,
  });

  final String seriesId;
  final String sourceId;
  final String sourceKey;
  final String title;
  final DateTime updatedAt;
  final String? cover;
  final int? year;
  final int? positionMs;
  final int? durationMs;
  final String? episodeTitle;

  double get progressRatio {
    if (positionMs == null || durationMs == null || durationMs == 0) return 0;
    return (positionMs! / durationMs!).clamp(0.0, 1.0);
  }

  bool get finished =>
      durationMs != null && durationMs! > 0 && progressRatio > 0.92;
}

/// 收藏记录。
class FavoriteEntry {
  const FavoriteEntry({
    required this.seriesId,
    required this.title,
    required this.addedAt,
    this.cover,
    this.year,
  });

  final String seriesId;
  final String title;
  final DateTime addedAt;
  final String? cover;
  final int? year;
}

/// 详情页展示用的聚合信息。
class SeriesBundle {
  const SeriesBundle({
    required this.detail,
    required this.sourceName,
    this.mergedFrom = const <String>[],
  });

  final SeriesDetail detail;
  final String sourceName;

  /// 同一剧在其它源上的 id 列表。
  final List<String> mergedFrom;
}

/// 一条完整的播放进度。
class ProgressRecord {
  const ProgressRecord({
    required this.seriesId,
    required this.episodeId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String seriesId;
  final String episodeId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get ratio {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}