import '../../core/utils/text_utils.dart';

/// TMDB 搜索到的一部剧。
class TmdbTitleMatch {
  const TmdbTitleMatch({
    required this.id,
    required this.name,
    required this.originalName,
    required this.originCountry,
    required this.originalLanguage,
    this.year,
    this.posterPath,
    this.overview,
  });

  final int id;
  final String name;
  final String originalName;
  final int? year;
  final List<String> originCountry;
  final String originalLanguage;
  final String? posterPath;
  final String? overview;

  bool get isKorean =>
      originCountry.contains('KR') || originalLanguage.toLowerCase() == 'ko';

  factory TmdbTitleMatch.fromJson(Map<String, dynamic> json) {
    final String date = (json['first_air_date'] ?? '').toString();
    final int? year = date.length >= 4
        ? int.tryParse(date.substring(0, 4))
        : null;
    final List<String> countries = <String>[];
    final Object? rawCountries = json['origin_country'];
    if (rawCountries is List) {
      for (final Object? item in rawCountries) {
        if (item is String && item.isNotEmpty) countries.add(item);
      }
    }
    return TmdbTitleMatch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      originalName: (json['original_name'] ?? '').toString(),
      year: year,
      originCountry: countries,
      originalLanguage: (json['original_language'] ?? '').toString(),
      posterPath: _nonEmpty(json['poster_path']?.toString()),
      overview: _nonEmpty(json['overview']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'original_name': originalName,
    'first_air_date': year == null ? '' : '$year-01-01',
    'origin_country': originCountry,
    'original_language': originalLanguage,
    'poster_path': posterPath,
    'overview': overview,
  };

  static String? _nonEmpty(String? value) {
    final String s = (value ?? '').trim();
    return s.isEmpty ? null : s;
  }
}

/// 给 TMDB 候选打分；标题对不上返回 0。
int tmdbTitleScore(TmdbTitleMatch match, Set<String> queries, int? year) {
  final Set<String> names = <String>{
    match.name,
    match.originalName,
    normalizeTitle(match.name),
    normalizeTitle(match.originalName),
  }..removeWhere((String n) => n.trim().isEmpty);

  int best = 0;
  for (final String query in queries) {
    final String q = normalizeTitle(query);
    if (q.isEmpty) continue;
    for (final String name in names) {
      final String n = normalizeTitle(name);
      if (n.isEmpty) continue;
      if (n == q) {
        if (best < 100) best = 100;
      } else if (n.contains(q) || q.contains(n)) {
        if (best < 60) best = 60;
      }
    }
  }
  if (best == 0) return 0;

  if (year != null && match.year != null) {
    final int diff = (match.year! - year).abs();
    if (diff == 0) {
      best += 20;
    } else if (diff == 1) {
      best += 10;
    } else if (diff > 2) {
      best -= 20;
    }
  }
  if (match.isKorean) best += 30;
  return best;
}
