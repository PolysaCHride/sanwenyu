import 'dart:async';

import 'package:collection/collection.dart';

import '../core/logger.dart';
import '../core/utils/text_utils.dart';
import '../domain/models/media.dart';
import '../domain/models/search_result.dart';
import '../domain/source/source_adapter.dart';

/// 多源并发搜索与结果聚合。
class SearchService {
  const SearchService({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  Future<SearchResponse> searchAll(
    String keyword,
    List<SourceAdapter> adapters, {
    void Function(SourceSearchState state)? onSourceDone,
  }) async {
    if (adapters.isEmpty) {
      return const SearchResponse(
        results: <AggregatedResult>[],
        states: <SourceSearchState>[],
      );
    }

    final collected = <String, List<SearchHit>>{};
    final states = <SourceSearchState>[];

    Future<void> run(SourceAdapter adapter) async {
      final sw = Stopwatch()..start();
      try {
        final hits = await adapter.search(keyword).timeout(timeout);
        sw.stop();
        collected[adapter.id] = hits;
        final state = SourceSearchState(
          sourceId: adapter.id,
          sourceName: adapter.name,
          count: hits.length,
          durationMs: sw.elapsedMilliseconds,
          done: true,
        );
        states.add(state);
        onSourceDone?.call(state);
      } on Object catch (e) {
        sw.stop();
        appLogger.w('搜索失败 ${adapter.name}: $e');
        collected[adapter.id] = const <SearchHit>[];
        final state = SourceSearchState(
          sourceId: adapter.id,
          sourceName: adapter.name,
          durationMs: sw.elapsedMilliseconds,
          error: e.toString(),
          done: true,
        );
        states.add(state);
        onSourceDone?.call(state);
      }
    }

    await Future.wait(adapters.map(run));

    final all = <SearchHit>[
      for (final adapter in adapters) ...(collected[adapter.id] ?? const <SearchHit>[]),
    ];

    return SearchResponse(results: aggregate(all), states: states);
  }

  /// 把同一部剧在不同源的结果合并。
  static List<AggregatedResult> aggregate(List<SearchHit> hits) {
    final groups = <List<SearchHit>>[];
    for (final hit in hits) {
      List<SearchHit>? target;
      for (final g in groups) {
        if (isSameSeries(g.first.title, hit.title,
            yearA: g.first.year, yearB: hit.year)) {
          target = g;
          break;
        }
      }
      if (target == null) {
        groups.add(<SearchHit>[hit]);
      } else {
        target.add(hit);
      }
    }

    final results = groups.map((List<SearchHit> g) {
      g.sort((SearchHit a, SearchHit b) => a.title.length.compareTo(b.title.length));
      final first = g.first;
      final withCover = g.firstWhereOrNull(
        (SearchHit h) => h.cover != null && h.cover!.isNotEmpty,
      );
      final year = first.year ?? g.firstWhereOrNull((SearchHit h) => h.year != null)?.year;
      return AggregatedResult(
        title: cleanTitle(first.title),
        hits: g,
        cover: withCover?.cover,
        year: year,
      );
    }).toList();

    results.sort((AggregatedResult a, AggregatedResult b) {
      final bySources = b.hits.length.compareTo(a.hits.length);
      if (bySources != 0) return bySources;
      return a.title.compareTo(b.title);
    });
    return results;
  }
}

/// 搜索响应。
class SearchResponse {
  const SearchResponse({required this.results, required this.states});

  final List<AggregatedResult> results;
  final List<SourceSearchState> states;
}