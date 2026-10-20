import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../core/network/http_client.dart';
import '../../core/storage/database.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/models/media.dart';
import 'tmdb_client.dart';
import 'tmdb_settings.dart';
import 'tmdb_title_match.dart';

/// 一条搜索结果 + TMDB 匹配结果。
class ClassifiedHit {
  const ClassifiedHit({required this.hit, this.match});

  final SearchHit hit;
  final TmdbTitleMatch? match;

  bool get known => match != null;
  bool get isKorean => match?.isKorean ?? false;
}

/// 用 TMDB 判断剧名是否属于韩剧，并缓存正/负结果。
class TmdbClassifier {
  TmdbClassifier(this._db, this._http);

  final AppDatabase _db;
  final HttpClient _http;

  static const Duration ttl = Duration(days: 30);
  static const Duration failureCooldown = Duration(minutes: 10);

  DateTime? _failureAt;

  Future<List<ClassifiedHit>> classify(
    List<SearchHit> hits, {
    int concurrency = 4,
  }) async {
    if (hits.isEmpty) return const <ClassifiedHit>[];
    final List<TmdbTitleMatch?> matches = List<TmdbTitleMatch?>.filled(
      hits.length,
      null,
    );

    final TmdbSettings settings = await TmdbSettings.load();
    if (!settings.enabled) {
      return <ClassifiedHit>[
        for (final SearchHit hit in hits) ClassifiedHit(hit: hit),
      ];
    }

    final TmdbClient client = TmdbClient(
      apiKey: settings.effectiveApiKey,
      language: settings.language,
      http: _http,
    );

    // 同名剧只查一次；一个搜索结果可能对应多个 index。
    final Map<String, List<int>> groups = <String, List<int>>{};
    for (var i = 0; i < hits.length; i++) {
      final String key = _key(hits[i]);
      groups.putIfAbsent(key, () => <int>[]).add(i);
    }
    final List<String> keys = groups.keys.toList();
    final int workerCount = concurrency < 1
        ? 1
        : (concurrency > keys.length ? keys.length : concurrency);

    Future<void> worker() async {
      while (keys.isNotEmpty) {
        final String key = keys.removeLast();
        final List<int> indexes = groups[key]!;
        final SearchHit sample = hits[indexes.first];

        final _CacheEntry? cached = _lookup(key);
        if (cached != null) {
          for (final int i in indexes) {
            matches[i] = cached.match;
          }
          continue;
        }

        final DateTime? failedAt = _failureAt;
        if (failedAt != null &&
            DateTime.now().difference(failedAt) < failureCooldown) {
          continue;
        }

        try {
          final TmdbTitleMatch? match = await client.matchTitle(
            title: sample.title,
            year: sample.year,
          );
          _save(key, match);
          for (final int i in indexes) {
            matches[i] = match;
          }
        } on TmdbException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 429) {
            _failureAt = DateTime.now();
          }
          // 单条失败保持 unknown，不影响其他条目。
        } on Object {
          // 网络错误同样保持 unknown。
        }
      }
    }

    await Future.wait(<Future<void>>[
      for (var i = 0; i < workerCount; i++) worker(),
    ]);

    return <ClassifiedHit>[
      for (var i = 0; i < hits.length; i++)
        ClassifiedHit(hit: hits[i], match: matches[i]),
    ];
  }

  String _key(SearchHit hit) {
    final String title = normalizeTitle(hit.title);
    final String fallback = hit.title.trim().toLowerCase();
    return '${title.isEmpty ? fallback : title}|${hit.year ?? ''}';
  }

  _CacheEntry? _lookup(String key) {
    final ResultSet rows = _db.db.select(
      'SELECT * FROM tmdb_titles WHERE cache_key = ? LIMIT 1',
      <Object?>[key],
    );
    if (rows.isEmpty) return null;
    final Row row = rows.first;
    final int checkedAt = row['checked_at'] as int;
    final DateTime stamp = DateTime.fromMillisecondsSinceEpoch(checkedAt);
    if (DateTime.now().difference(stamp) > ttl) return null;
    return _CacheEntry(_fromRow(row));
  }

  TmdbTitleMatch? _fromRow(Row row) {
    final Object? id = row['tmdb_id'];
    if (id is! int || id <= 0) return null;
    final String countriesRaw = (row['origin_country'] as String?) ?? '[]';
    final List<String> countries = <String>[];
    try {
      final Object? decoded = jsonDecode(countriesRaw);
      if (decoded is List) {
        for (final Object? item in decoded) {
          if (item is String) countries.add(item);
        }
      }
    } on Object {
      // 缓存损坏时当作没有国家信息。
    }
    return TmdbTitleMatch(
      id: id,
      name: (row['name'] as String?) ?? '',
      originalName: (row['original_name'] as String?) ?? '',
      year: row['year'] as int?,
      originCountry: countries,
      originalLanguage: (row['original_language'] as String?) ?? '',
      posterPath: row['poster_path'] as String?,
      overview: row['overview'] as String?,
    );
  }

  void _save(String key, TmdbTitleMatch? match) {
    _db.db.execute(
      'INSERT OR REPLACE INTO tmdb_titles('
      'cache_key, is_korean, tmdb_id, name, original_name, year, '
      'origin_country, original_language, poster_path, overview, checked_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        key,
        match?.isKorean == true ? 1 : 0,
        match?.id,
        match?.name,
        match?.originalName,
        match?.year,
        jsonEncode(match?.originCountry ?? const <String>[]),
        match?.originalLanguage,
        match?.posterPath,
        match?.overview,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }
}

class _CacheEntry {
  const _CacheEntry(this.match);

  final TmdbTitleMatch? match;
}
