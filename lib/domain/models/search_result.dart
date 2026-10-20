import 'media.dart';

/// 跨源聚合后的搜索结果。
class AggregatedResult {
  AggregatedResult({
    required this.title,
    required this.hits,
    this.cover,
    this.year,
  });

  final String title;
  final List<SearchHit> hits;
  final String? cover;
  final int? year;

  String? get remark {
    for (final h in hits) {
      if (h.remark != null && h.remark!.isNotEmpty) return h.remark;
    }
    return null;
  }

  SearchHit get primary => hits.first;
}

/// 单源搜索状态。
class SourceSearchState {
  const SourceSearchState({
    required this.sourceId,
    required this.sourceName,
    this.count = 0,
    this.durationMs = 0,
    this.error,
    this.done = false,
  });

  final String sourceId;
  final String sourceName;
  final int count;
  final int durationMs;
  final String? error;
  final bool done;
}