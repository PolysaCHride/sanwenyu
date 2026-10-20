import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../core/network/http_client.dart';
import '../../core/storage/database.dart';
import '../../domain/models/credits.dart';
import 'tmdb_client.dart';
import 'tmdb_settings.dart';

/// 演职员缓存。
///
/// 命中缓存 30 天内不再请求 TMDB；匹配失败也缓存（负缓存），
/// 否则每次打开详情页都会打一次搜索接口。
class CreditsRepository {
  CreditsRepository(this._db, this._http);

  final AppDatabase _db;
  final HttpClient _http;

  static const Duration ttl = Duration(days: 30);

  /// Key 失效/超额后冷却一段时间，避免每打开一次详情就打一次 TMDB。
  static const Duration failureCooldown = Duration(minutes: 10);

  DateTime? _failureAt;

  SeriesCredits? cached(String seriesId, {DateTime? now}) {
    final ResultSet rows = _db.db.select(
      'SELECT payload, fetched_at FROM credits WHERE series_id = ? LIMIT 1',
      <Object?>[seriesId],
    );
    if (rows.isEmpty) return null;
    final Row row = rows.first;
    final int fetchedAt = row['fetched_at'] as int;
    final DateTime stamp = DateTime.fromMillisecondsSinceEpoch(fetchedAt);
    final Duration age = (now ?? DateTime.now()).difference(stamp);
    if (age > ttl) return null;
    try {
      final Object? payload = jsonDecode(row['payload'] as String);
      if (payload is! Map<String, dynamic>) return null;
      return SeriesCredits.fromJson(payload);
    } on Object {
      return null;
    }
  }

  void save(String seriesId, SeriesCredits credits) {
    _db.db.execute(
      'INSERT OR REPLACE INTO credits(series_id, tmdb_id, payload, fetched_at) '
      'VALUES (?, ?, ?, ?)',
      <Object?>[
        seriesId,
        credits.tmdbId,
        jsonEncode(credits.toJson()),
        credits.fetchedAt.millisecondsSinceEpoch,
      ],
    );
  }

  Future<SeriesCredits?> forSeries({
    required String seriesId,
    required String title,
    int? year,
    required TmdbSettings settings,
    bool force = false,
  }) async {
    if (!force) {
      final SeriesCredits? hit = cached(seriesId);
      if (hit != null) return hit.isEmpty ? null : hit;
      final DateTime? failedAt = _failureAt;
      if (failedAt != null && DateTime.now().difference(failedAt) < failureCooldown) {
        return null;
      }
    }
    if (!settings.enabled) return null;

    try {
      final SeriesCredits credits = await TmdbClient(
        apiKey: settings.apiKey,
        language: settings.language,
        http: _http,
      ).creditsFor(title: title, year: year);

      save(seriesId, credits);
      return credits.isEmpty ? null : credits;
    } on TmdbException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 429) {
        _failureAt = DateTime.now();
      }
      rethrow;
    }
  }
}
