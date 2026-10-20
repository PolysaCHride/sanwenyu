/// 字段提取规则。
class FieldRule {
  const FieldRule({this.selector, this.attr = 'text', this.regex, this.group = 1});

  /// CSS 选择器；为空表示在当前节点上取值。
  final String? selector;

  /// text / html / 任意 HTML 属性名。
  final String attr;

  /// 对取到的文本再做一次正则提取。
  final String? regex;
  final int group;

  factory FieldRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FieldRule();
    return FieldRule(
      selector: json['sel'] as String?,
      attr: json['attr'] as String? ?? 'text',
      regex: json['regex'] as String?,
      group: json['group'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (selector != null && selector!.isNotEmpty) 'sel': selector,
        'attr': attr,
        if (regex != null && regex!.isNotEmpty) 'regex': regex,
        if (group != 1) 'group': group,
      };

  FieldRule copyWith({String? selector, String? attr, String? regex, int? group}) {
    return FieldRule(
      selector: selector ?? this.selector,
      attr: attr ?? this.attr,
      regex: regex ?? this.regex,
      group: group ?? this.group,
    );
  }
}

/// 列表项规则（搜索结果 / 选集）。
class ListRule {
  const ListRule({
    required this.list,
    required this.title,
    required this.url,
    this.cover,
    this.remark,
  });

  final String list;
  final FieldRule title;
  final FieldRule url;
  final FieldRule? cover;
  final FieldRule? remark;

  factory ListRule.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> fields =
        (json['fields'] as Map<String, dynamic>?) ?? json;
    FieldRule? opt(String key) {
      final Object? v = json[key] ?? fields[key];
      if (v == null) return null;
      return FieldRule.fromJson(v as Map<String, dynamic>);
    }

    return ListRule(
      list: json['list'] as String? ?? '',
      title: FieldRule.fromJson(fields['title'] as Map<String, dynamic>?),
      url: FieldRule.fromJson(fields['url'] as Map<String, dynamic>?),
      cover: opt('cover'),
      remark: opt('remark'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'list': list,
        'fields': <String, dynamic>{
          'title': title.toJson(),
          'url': url.toJson(),
          if (cover != null) 'cover': cover!.toJson(),
          if (remark != null) 'remark': remark!.toJson(),
        },
      };
}

/// 搜索规则。
class SearchRule {
  const SearchRule({
    required this.url,
    required this.list,
    this.method = 'GET',
    this.body,
  });

  /// 支持 {keyword} 占位符。
  final String url;
  final String method;
  final String? body;
  final ListRule list;

  factory SearchRule.fromJson(Map<String, dynamic> json) {
    return SearchRule(
      url: json['url'] as String? ?? '',
      method: (json['method'] as String? ?? 'GET').toUpperCase(),
      body: json['body'] as String?,
      list: ListRule.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'method': method,
        if (body != null && body!.isNotEmpty) 'body': body,
        ...list.toJson(),
      };

  SearchRule copyWith({String? url, String? method, String? body, ListRule? list}) {
    return SearchRule(
      url: url ?? this.url,
      method: method ?? this.method,
      body: body ?? this.body,
      list: list ?? this.list,
    );
  }
}

/// 详情规则。
class DetailRule {
  const DetailRule({
    required this.title,
    required this.episodes,
    this.cover,
    this.synopsis,
    this.year,
    this.rating,
  });

  final FieldRule title;
  final FieldRule? cover;
  final FieldRule? synopsis;
  final FieldRule? year;
  final FieldRule? rating;
  final ListRule episodes;

  factory DetailRule.fromJson(Map<String, dynamic> json) {
    return DetailRule(
      title: FieldRule.fromJson(json['title'] as Map<String, dynamic>?),
      cover: json['cover'] == null
          ? null
          : FieldRule.fromJson(json['cover'] as Map<String, dynamic>),
      synopsis: json['synopsis'] == null
          ? null
          : FieldRule.fromJson(json['synopsis'] as Map<String, dynamic>),
      year: json['year'] == null
          ? null
          : FieldRule.fromJson(json['year'] as Map<String, dynamic>),
      rating: json['rating'] == null
          ? null
          : FieldRule.fromJson(json['rating'] as Map<String, dynamic>),
      episodes: ListRule.fromJson(
        (json['episodes'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title.toJson(),
        if (cover != null) 'cover': cover!.toJson(),
        if (synopsis != null) 'synopsis': synopsis!.toJson(),
        if (year != null) 'year': year!.toJson(),
        if (rating != null) 'rating': rating!.toJson(),
        'episodes': episodes.toJson(),
      };
}

/// 播放解析规则。
class PlayRule {
  const PlayRule({
    this.mode = 'page',
    this.extract = const <String>[],
    this.headers = const <String, String>{},
    this.referer,
  });

  /// page：请求播放页后正则提取；direct：选集地址本身就是流地址。
  final String mode;
  final List<String> extract;
  final Map<String, String> headers;
  final String? referer;

  factory PlayRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlayRule();
    return PlayRule(
      mode: json['mode'] as String? ?? 'page',
      extract: (json['extract'] as List<dynamic>?)
              ?.map((dynamic e) => e is String ? e : (e as Map<String, dynamic>)['regex'] as String)
              .where((String? e) => e != null)
              .cast<String>()
              .toList() ??
          const <String>[],
      headers: (json['headers'] as Map<String, dynamic>?)
              ?.map((String k, dynamic v) => MapEntry<String, String>(k, v.toString())) ??
          const <String, String>{},
      referer: json['referer'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode,
        if (extract.isNotEmpty) 'extract': extract,
        if (headers.isNotEmpty) 'headers': headers,
        if (referer != null && referer!.isNotEmpty) 'referer': referer,
      };
}

/// 一个站点规则的完整描述。
class SiteRule {
  const SiteRule({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.search,
    required this.detail,
    required this.play,
    this.charset = 'utf-8',
    this.headers = const <String, String>{},
  });

  final String id;
  final String name;
  final String baseUrl;
  final String charset;
  final Map<String, String> headers;
  final SearchRule search;
  final DetailRule detail;
  final PlayRule play;

  factory SiteRule.fromJson(Map<String, dynamic> json) {
    return SiteRule(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      charset: json['charset'] as String? ?? 'utf-8',
      headers: (json['headers'] as Map<String, dynamic>?)
              ?.map((String k, dynamic v) => MapEntry<String, String>(k, v.toString())) ??
          const <String, String>{},
      search: SearchRule.fromJson(
        (json['search'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      detail: DetailRule.fromJson(
        (json['detail'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      play: PlayRule.fromJson(json['play'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'charset': charset,
        if (headers.isNotEmpty) 'headers': headers,
        'search': search.toJson(),
        'detail': detail.toJson(),
        'play': play.toJson(),
      };

  SiteRule copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? charset,
    Map<String, String>? headers,
    SearchRule? search,
    DetailRule? detail,
    PlayRule? play,
  }) {
    return SiteRule(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      charset: charset ?? this.charset,
      headers: headers ?? this.headers,
      search: search ?? this.search,
      detail: detail ?? this.detail,
      play: play ?? this.play,
    );
  }
}