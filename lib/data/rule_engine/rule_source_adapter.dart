import 'dart:convert';

import '../../core/utils/text_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../domain/models/media.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/source_config.dart';
import '../../domain/source/source_adapter.dart';
import '../../core/network/http_client.dart';
import 'extractor.dart';

/// 由 JSON 规则驱动的通用源。
class RuleSourceAdapter extends SourceAdapter {
  RuleSourceAdapter({
    required SourceConfig config,
    required this.rule,
    required HttpClient http,
  })  : _config = config,
        _http = http;

  final SourceConfig _config;
  final SiteRule rule;
  final HttpClient _http;

  @override
  SourceConfig get config => _config;

  String _absolute(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = rule.baseUrl.endsWith('/') ? rule.baseUrl : '${rule.baseUrl}/';
    return resolveUrl(path, base) ?? path;
  }

  Map<String, String> get _headers => <String, String>{
        ...rule.headers,
        'Referer': rule.baseUrl,
      };

  @override
  Future<List<SearchHit>> search(String keyword, {int page = 1}) async {
    final encoded = Uri.encodeQueryComponent(keyword);
    final path = rule.search.url
        .replaceAll('{keyword}', encoded)
        .replaceAll('{page}', '$page');
    final url = _absolute(path);
    final String body;
    if (rule.search.method == 'POST') {
      final form = (rule.search.body ?? 'wd={keyword}')
          .replaceAll('{keyword}', keyword)
          .split('&')
          .where((String e) => e.contains('='))
          .fold<Map<String, dynamic>>(<String, dynamic>{}, (Map<String, dynamic> acc, String pair) {
        final i = pair.indexOf('=');
        acc[Uri.decodeComponent(pair.substring(0, i))] =
            Uri.decodeComponent(pair.substring(i + 1));
        return acc;
      });
      final resp = await _http.postForm(url, body: form, headers: _headers);
      body = resp.data ?? '';
    } else {
      final resp = await _http.getText(url, headers: _headers);
      body = resp.data ?? '';
    }
    if (body.trim().isEmpty) return const <SearchHit>[];

    final doc = RuleExtractor.parse(body);
    final rows = RuleExtractor.list(doc, rule.search.list, baseUrl: rule.baseUrl);
    return rows
        .map((Map<String, String> row) => SearchHit(
              title: row['title'] ?? '',
              sourceId: _config.id,
              sourceName: _config.name,
              sourceKey: row['url'] ?? '',
              cover: (row['cover']?.isEmpty ?? true) ? null : row['cover'],
              remark: (row['remark']?.isEmpty ?? true) ? null : row['remark'],
              year: parseYear(row['remark']),
            ))
        .where((SearchHit h) => h.title.isNotEmpty && h.sourceKey.isNotEmpty)
        .toList();
  }

  @override
  Future<SeriesDetail> detail(String sourceKey) async {
    final url = _absolute(sourceKey);
    final resp = await _http.getText(url, headers: _headers);
    final doc = RuleExtractor.parse(resp.data ?? '');

    final title = RuleExtractor.field(
          doc.documentElement,
          rule.detail.title,
          baseUrl: rule.baseUrl,
        ) ??
        '';
    final rows = RuleExtractor.list(doc, rule.detail.episodes, baseUrl: rule.baseUrl);

    final episodes = <EpisodeRef>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = row['title'] ?? 'EP${i + 1}';
      episodes.add(EpisodeRef(
        index: parseEpisodeIndex(name, i + 1),
        title: name,
        ref: row['url'] ?? '',
      ));
    }

    return SeriesDetail(
      title: title,
      sourceId: _config.id,
      sourceKey: sourceKey,
      episodes: episodes,
      cover: RuleExtractor.field(doc.documentElement, rule.detail.cover, baseUrl: rule.baseUrl),
      synopsis: RuleExtractor.field(doc.documentElement, rule.detail.synopsis, baseUrl: rule.baseUrl),
      year: parseYear(
        RuleExtractor.field(doc.documentElement, rule.detail.year, baseUrl: rule.baseUrl) ??
            title,
      ),
      rating: double.tryParse(
        RuleExtractor.field(doc.documentElement, rule.detail.rating, baseUrl: rule.baseUrl) ?? '',
      ),
    );
  }

  @override
  Future<PlayInfo> resolve(EpisodeRef ref, {String? detailUrl}) async {
    if (rule.play.mode == 'direct' || looksLikeStream(ref.ref)) {
      return PlayInfo(
        mode: PlayMode.direct,
        url: ref.ref,
        headers: <String, String>{
          ...rule.play.headers,
          if (rule.play.referer != null)
            'Referer': _absolute(rule.play.referer!.replaceAll('{detailUrl}', detailUrl ?? rule.baseUrl)),
        },
      );
    }
    final url = _absolute(ref.ref);
    final resp = await _http.getText(url, headers: _headers);
    final content = resp.data ?? '';
    final stream = RuleExtractor.extractStream(
      content,
      rule.play.extract.isEmpty ? _defaultPatterns : rule.play.extract,
    );
    if (stream == null) {
      return const PlayInfo.unsupported('no video url found on play page');
    }
    return PlayInfo(
      mode: PlayMode.direct,
      url: stream,
      headers: <String, String>{
        ...rule.play.headers,
        'Referer': url,
      },
    );
  }

  static const List<String> _defaultPatterns = <String>[
    r'''https?://[^\s"''<>]+?\.m3u8[^\s"''<>]*''',
    r'''https?://[^\s"''<>]+?\.mp4[^\s"''<>]*''',
  ];
}

/// 从 JSON 文本构造规则源。
RuleSourceAdapter buildRuleAdapter(
  SourceConfig config,
  HttpClient http,
) {
  final map = jsonDecode(config.ruleJson ?? '{}') as Map<String, dynamic>;
  return RuleSourceAdapter(
    config: config,
    rule: SiteRule.fromJson(map),
    http: http,
  );
}
