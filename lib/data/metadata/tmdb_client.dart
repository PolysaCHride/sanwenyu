import 'package:dio/dio.dart';

import '../../core/network/http_client.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/models/credits.dart';

/// TMDB 调用失败。
class TmdbException implements Exception {
  const TmdbException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// TMDB v3 客户端（用户自备 Key）。
class TmdbClient {
  TmdbClient({
    required this.apiKey,
    required this.language,
    required HttpClient http,
  }) : _http = http;

  static const String _base = 'https://api.themoviedb.org/3';

  final String apiKey;
  final String language;
  final HttpClient _http;

  /// 搜索剧集并取演职员；匹配不到返回 [SeriesCredits.empty]（tmdbId 为 null）。
  Future<SeriesCredits> creditsFor({required String title, int? year}) async {
    final int? id = await _searchSeries(title: title, year: year);
    if (id == null) {
      return SeriesCredits(
        tmdbId: null,
        cast: const <CastMember>[],
        crew: const <CrewMember>[],
        fetchedAt: DateTime.now(),
      );
    }

    final Response<dynamic> resp = await _http.getJson(
      '$_base/tv/$id/credits',
      query: <String, dynamic>{'api_key': apiKey, 'language': language},
    );
    _ensureOk(resp);
    final Map<String, dynamic> body = _asMap(resp.data);

    final List<CastMember> cast = <CastMember>[];
    final Object? rawCast = body['cast'];
    if (rawCast is List) {
      for (final Object? item in rawCast) {
        if (item is! Map) continue;
        final CastMember member = CastMember.fromJson(_stringKeyed(item));
        if (member.name.isEmpty) continue;
        cast.add(member);
      }
    }
    cast.sort((CastMember a, CastMember b) => a.order.compareTo(b.order));

    final List<CrewMember> crew = <CrewMember>[];
    final Object? rawCrew = body['crew'];
    if (rawCrew is List) {
      for (final Object? item in rawCrew) {
        if (item is! Map) continue;
        final CrewMember member = CrewMember.fromJson(_stringKeyed(item));
        if (member.name.isEmpty) continue;
        crew.add(member);
      }
    }

    return SeriesCredits(
      tmdbId: id,
      cast: cast.take(12).toList(),
      crew: crew.take(40).toList(),
      fetchedAt: DateTime.now(),
    );
  }

  Future<int?> _searchSeries({required String title, int? year}) async {
    final List<String> queries = <String>[
      title.trim(),
      cleanTitle(title),
    ].where((String q) => q.isNotEmpty).toSet().toList();

    for (final String query in queries) {
      final Response<dynamic> resp = await _http.getJson(
        '$_base/search/tv',
        query: <String, dynamic>{
          'api_key': apiKey,
          'language': language,
          'query': query,
          'include_adult': 'false',
          if (year != null) 'first_air_date_year': '$year',
        },
      );
      _ensureOk(resp);
      final Map<String, dynamic> body = _asMap(resp.data);
      final Object? results = body['results'];
      if (results is! List) continue;
      for (final Object? item in results) {
        if (item is! Map) continue;
        final int? id = (_stringKeyed(item)['id'] as num?)?.toInt();
        if (id != null) return id;
      }
    }
    return null;
  }

  /// 设置页的连接测试：只验证 Key 是否可用。
  Future<void> testConnection() async {
    final Response<dynamic> resp = await _http.getJson(
      '$_base/configuration',
      query: <String, dynamic>{'api_key': apiKey},
    );
    _ensureOk(resp);
  }

  void _ensureOk(Response<dynamic> resp) {
    final int code = resp.statusCode ?? 0;
    if (code == 401) {
      throw const TmdbException('Invalid API key', statusCode: 401);
    }
    if (code >= 400) {
      throw TmdbException('TMDB request failed', statusCode: code);
    }
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return _stringKeyed(data);
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> map) {
    return map.map((dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value));
  }
}

