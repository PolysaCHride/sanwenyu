import 'dart:convert';

import '../../core/network/http_client.dart';
import '../../core/utils/text_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../domain/models/media.dart';
import '../../domain/models/source_config.dart';
import '../../domain/source/source_adapter.dart';

/// 苹果 CMS10 采集接口适配器。
///
/// 只需配置站点根地址，即可完成搜索、详情与选集。
class MaccmsAdapter extends SourceAdapter {
  MaccmsAdapter({required SourceConfig config, required HttpClient http})
      : _config = config,
        _http = http;

  final SourceConfig _config;
  final HttpClient _http;

  @override
  SourceConfig get config => _config;

  String get _base {
    final b = _config.baseUrl;
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  String get _api => '$_base/api.php/provide/vod/';

  Map<String, String> get _headers => <String, String>{
        'Referer': _base,
        'Accept': 'application/json, text/plain, */*',
      };

  @override
  Future<List<SearchHit>> search(String keyword, {int page = 1}) async {
    final resp = await _http.getJson(
      _api,
      query: <String, dynamic>{'ac': 'detail', 'wd': keyword, 'pg': page},
      headers: _headers,
    );
    return _toHits(asList(decodeJson(resp.data)));
  }

  @override
  Future<List<SearchHit>> browse({int page = 1, String? category}) async {
    final resp = await _http.getJson(
      _api,
      query: <String, dynamic>{
        'ac': 'detail',
        'pg': page,
        if (category != null && category.isNotEmpty) 't': category,
      },
      headers: _headers,
    );
    return _toHits(asList(decodeJson(resp.data)));
  }

  @override
  bool get supportsBrowse => true;

  @override
  List<Category> get categories => _categories;

  static const List<Category> _categories = <Category>[
    Category(id: '', name: '最新更新'),
    Category(id: '1', name: '电影'),
    Category(id: '2', name: '连续剧'),
    Category(id: '3', name: '综艺'),
    Category(id: '4', name: '动漫'),
  ];

  List<SearchHit> _toHits(List<Map<String, dynamic>> list) {
    return list
        .map((Map<String, dynamic> item) => SearchHit(
              title: (item['vod_name'] ?? '').toString(),
              sourceId: _config.id,
              sourceName: _config.name,
              sourceKey: (item['vod_id'] ?? '').toString(),
              cover: _nonEmpty(item['vod_pic']?.toString()),
              remark: _nonEmpty(item['vod_remarks']?.toString()),
              year: parseYear(item['vod_year']?.toString() ?? item['vod_name']?.toString()),
            ))
        .where((SearchHit h) => h.title.isNotEmpty && h.sourceKey.isNotEmpty)
        .toList();
  }

  @override
  Future<SeriesDetail> detail(String sourceKey) async {
    final resp = await _http.getJson(
      _api,
      query: <String, dynamic>{'ac': 'detail', 'ids': sourceKey},
      headers: _headers,
    );
    final list = asList(decodeJson(resp.data));
    if (list.isEmpty) {
      throw StateError('empty detail response: $sourceKey');
    }
    final item = list.first;
    final playUrl = (item['vod_play_url'] ?? '').toString();
    return SeriesDetail(
      title: (item['vod_name'] ?? '').toString(),
      sourceId: _config.id,
      sourceKey: sourceKey,
      episodes: parseEpisodes(playUrl),
      cover: _nonEmpty(item['vod_pic']?.toString()),
      synopsis: stripHtml(item['vod_content']?.toString()),
      year: parseYear(item['vod_year']?.toString()),
      tags: splitTags(item['vod_class']?.toString()),
      rating: double.tryParse((item['vod_score'] ?? '').toString()),
    );
  }

  @override
  Future<PlayInfo> resolve(EpisodeRef ref, {String? detailUrl}) async {
    final url = ref.ref;
    if (looksLikeStream(url)) {
      return PlayInfo(
        mode: PlayMode.direct,
        url: url,
        headers: <String, String>{'Referer': _base},
      );
    }
    final resolved = resolveUrl(url, _base);
    if (resolved == null) {
      return const PlayInfo.unsupported('empty playback url');
    }
    final resp = await _http.getText(resolved, headers: _headers);
    final content = resp.data ?? '';
    final stream = extractStream(content);
    if (stream == null) {
      return const PlayInfo.unsupported('no m3u8/mp4 found on play page');
    }
    return PlayInfo(
      mode: PlayMode.direct,
      url: stream,
      headers: <String, String>{'Referer': resolved},
    );
  }

  /// 解析 vod_play_url：`第1集$url#第2集$url`，多线路以 $$$ 分隔。
  static List<EpisodeRef> parseEpisodes(String raw) {
    if (raw.trim().isEmpty) return const <EpisodeRef>[];
    final firstLine = raw.split(r'$$$').first;
    final out = <EpisodeRef>[];
    final parts = firstLine.split('#');
    for (var i = 0; i < parts.length; i++) {
      final seg = parts[i].trim();
      if (seg.isEmpty) continue;
      final idx = seg.indexOf(r'$');
      final name = idx >= 0 ? seg.substring(0, idx) : 'EP${i + 1}';
      final link = idx >= 0 ? seg.substring(idx + 1) : seg;
      if (link.trim().isEmpty) continue;
      out.add(EpisodeRef(
        index: parseEpisodeIndex(name, i + 1),
        title: name.trim().isEmpty ? 'EP${i + 1}' : name.trim(),
        ref: link.trim(),
      ));
    }
    return out;
  }

  static const List<String> _patterns = <String>[
    r'''"url"\s*:\s*"(https?:\\?/\\?/[^"]+?\.m3u8[^"]*)"''',
    r'''https?://[^\s"''<>]+?\.m3u8[^\s"''<>]*''',
    r'''https?://[^\s"''<>]+?\.mp4[^\s"''<>]*''',
  ];

  /// 从播放页 HTML 中提取流地址。
  static String? extractStream(String content) {
    for (final p in _patterns) {
      final v = firstGroup(content, p);
      if (v != null) return v.replaceAll(r'\/', '/');
    }
    return null;
  }

  /// 兼容 dio 返回 String 或已解析对象的情况。
  static dynamic decodeJson(dynamic data) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        return jsonDecode(trimmed);
      } on FormatException {
        return null;
      }
    }
    return data;
  }

  /// 归一化 CMS 的 list 字段。
  static List<Map<String, dynamic>> asList(dynamic data) {
    if (data is Map) {
      final raw = data['list'];
      if (raw is List) {
        return raw.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> e) {
          return e.map((dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v));
        }).toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static String? stripHtml(String? s) {
    if (s == null) return null;
    final clean = s.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    return clean.isEmpty ? null : clean;
  }

  static List<String> splitTags(String? s) {
    if (s == null || s.trim().isEmpty) return const <String>[];
    return s
        .split(RegExp(r'[,，/]'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
