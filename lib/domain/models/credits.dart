/// TMDB 演职员数据。
///
/// 只保留展示需要的字段，缓存时整体序列化，避免回源。
library;

class CastMember {
  const CastMember({
    required this.name,
    this.character,
    this.profilePath,
    this.order = 0,
  });

  final String name;
  final String? character;
  final String? profilePath;
  final int order;

  String? profileUrl({String size = 'w185'}) {
    final String? path = profilePath;
    if (path == null || path.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (character != null && character!.isNotEmpty) 'character': character,
        if (profilePath != null && profilePath!.isNotEmpty) 'profile_path': profilePath,
        'order': order,
      };

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
        name: json['name'] as String? ?? '',
        character: json['character'] as String?,
        profilePath: json['profile_path'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

class CrewMember {
  const CrewMember({required this.name, required this.job});

  final String name;
  final String job;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name, 'job': job};

  factory CrewMember.fromJson(Map<String, dynamic> json) => CrewMember(
        name: json['name'] as String? ?? '',
        job: json['job'] as String? ?? '',
      );
}

/// 一部剧的演职员。
class SeriesCredits {
  const SeriesCredits({
    required this.tmdbId,
    required this.cast,
    required this.crew,
    required this.fetchedAt,
  });

  /// 未匹配到时为 null（负缓存）。
  final int? tmdbId;
  final List<CastMember> cast;
  final List<CrewMember> crew;
  final DateTime fetchedAt;

  bool get matched => tmdbId != null;
  bool get isEmpty => cast.isEmpty && crew.isEmpty;

  List<CrewMember> get directors =>
      crew.where((CrewMember c) => c.job == 'Director').toList();

  List<CrewMember> get writers => crew
      .where((CrewMember c) =>
          c.job == 'Writer' || c.job == 'Screenplay' || c.job == 'Teleplay')
      .toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tmdbId': tmdbId,
        'cast': cast.map((CastMember e) => e.toJson()).toList(),
        'crew': crew.map((CrewMember e) => e.toJson()).toList(),
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
      };

  factory SeriesCredits.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(Object? raw) {
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>
              e.map((dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v)))
          .toList();
    }

    return SeriesCredits(
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      cast: list(json['cast']).map(CastMember.fromJson).toList(),
      crew: list(json['crew']).map(CrewMember.fromJson).toList(),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['fetchedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  static final SeriesCredits empty = SeriesCredits(
    tmdbId: null,
    cast: const <CastMember>[],
    crew: const <CrewMember>[],
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
