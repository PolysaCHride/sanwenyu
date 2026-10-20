/// 搜索结果条目（单个源）。
class SearchHit {
  const SearchHit({
    required this.title,
    required this.sourceId,
    required this.sourceName,
    required this.sourceKey,
    this.cover,
    this.remark,
    this.year,
  });

  final String title;
  final String sourceId;
  final String sourceName;

  /// 源站内定位该剧的标识：详情页 URL、CMS vod_id 等。
  final String sourceKey;
  final String? cover;
  final String? remark;
  final int? year;
}

/// 单个源的剧集详情。
class SeriesDetail {
  const SeriesDetail({
    required this.title,
    required this.sourceId,
    required this.sourceKey,
    required this.episodes,
    this.cover,
    this.synopsis,
    this.year,
    this.tags = const <String>[],
    this.rating,
  });

  final String title;
  final String sourceId;
  final String sourceKey;
  final List<EpisodeRef> episodes;
  final String? cover;
  final String? synopsis;
  final int? year;
  final List<String> tags;
  final double? rating;
}

/// 一集的引用。
class EpisodeRef {
  const EpisodeRef({
    required this.index,
    required this.title,
    required this.ref,
  });

  /// 集号，从 1 开始。
  final int index;
  final String title;

  /// 源站内的引用：播放页 URL 或 CMS 播放地址。
  final String ref;
}

/// 播放方式。
enum PlayMode {
  /// 已解析出可直接播放的地址。
  direct,

  /// 需要 WebView 打开播放页后嗅探。
  webview,

  /// 当前无法解析。
  unsupported,
}

/// 解析结果。
class PlayInfo {
  const PlayInfo({
    required this.mode,
    this.url,
    this.headers = const <String, String>{},
    this.message,
  });

  const PlayInfo.unsupported(String reason)
      : this(mode: PlayMode.unsupported, message: reason);

  final PlayMode mode;
  final String? url;
  final Map<String, String> headers;
  final String? message;
}