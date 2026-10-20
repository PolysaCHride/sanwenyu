/// HLS 主播放列表（master playlist）的最小解析器。
///
/// 只做两件事：认出主列表、把码率/分辨率整理成可选清晰度。
/// 分片与密钥不在这里处理——播放器自己会拉。
library;

/// 一个可选清晰度。
class QualityOption {
  const QualityOption({
    required this.url,
    required this.bandwidth,
    this.width,
    this.height,
    this.name,
  });

  final String url;
  final int bandwidth;
  final int? width;
  final int? height;
  final String? name;

  bool get isResolved => height != null || bandwidth > 0;

  /// 排序权重：优先分辨率，其次码率。
  int get rank => height != null ? height! * 100000 + bandwidth : bandwidth;

  String get label {
    if (height != null) return '${height}p';
    if (bandwidth > 0) return '${(bandwidth / 1000).round()} kbps';
    return name ?? 'Auto';
  }

  @override
  bool operator ==(Object other) => other is QualityOption && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'QualityOption($label, $url)';
}

/// 清晰度偏好。
enum QualityPreference {
  auto(null),
  p1080(1080),
  p720(720),
  p480(480);

  const QualityPreference(this.targetHeight);

  final int? targetHeight;

  String get storageValue => name;

  static QualityPreference fromStorage(String? value) {
    return QualityPreference.values.firstWhere(
      (QualityPreference p) => p.name == value,
      orElse: () => QualityPreference.auto,
    );
  }
}

/// 主播放列表解析。
class M3u8Master {
  const M3u8Master(this.variants);

  final List<QualityOption> variants;

  static const String _streamInf = '#EXT-X-STREAM-INF:';

  /// 是否为主播放列表。
  static bool isMaster(String content) =>
      content.contains(_streamInf) || content.contains('#EXT-X-MEDIA:');

  /// 解析主列表。
  ///
  /// [baseUrl] 用于补全相对分片地址；无法解析的属性按缺省值处理，
  /// 宁愿少一个清晰度，也不要因为一条坏行丢掉整张列表。
  static M3u8Master parse(String content, String baseUrl) {
    final lines = content
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final variants = <QualityOption>[];
    final seen = <String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.startsWith(_streamInf)) continue;

      final attrs = line.substring(_streamInf.length);
      var bandwidth = 0;
      int? width;
      int? height;
      String? name;

      final bw = RegExp(r'BANDWIDTH=(\d+)').firstMatch(attrs);
      if (bw != null) bandwidth = int.tryParse(bw.group(1)!) ?? 0;

      final res = RegExp(r'RESOLUTION=(\d+)[xX](\d+)').firstMatch(attrs);
      if (res != null) {
        width = int.tryParse(res.group(1)!);
        height = int.tryParse(res.group(2)!);
      }

      final nameMatch = RegExp(r'NAME="([^"]*)"').firstMatch(attrs);
      if (nameMatch != null) {
        name = nameMatch.group(1);
      }

      // URI 在随后的第一条非注释行。
      var uriLine = '';
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].startsWith('#')) continue;
        uriLine = lines[j];
        break;
      }
      if (uriLine.isEmpty) continue;

      final resolved = _resolve(baseUrl, uriLine);
      if (resolved.isEmpty || !seen.add(resolved)) continue;

      variants.add(QualityOption(
        url: resolved,
        bandwidth: bandwidth,
        width: width,
        height: height,
        name: name,
      ));
    }

    variants.sort((QualityOption a, QualityOption b) => b.rank.compareTo(a.rank));
    return M3u8Master(List<QualityOption>.unmodifiable(variants));
  }

  /// 按偏好挑一个清晰度。
  ///
  /// 偏好 1080p 时：优先取不超过 1080p 的最高档；全都更高则取最低档，
  /// 避免为了「不超过」而直接放 4K。
  static QualityOption? pick(
    List<QualityOption> variants,
    QualityPreference preference,
  ) {
    if (variants.isEmpty) return null;
    final sorted = List<QualityOption>.of(variants)
      ..sort((QualityOption a, QualityOption b) => b.rank.compareTo(a.rank));
    final target = preference.targetHeight;
    if (target == null) return sorted.first;

    final withHeight = sorted.where((QualityOption v) => v.height != null).toList();
    if (withHeight.isEmpty) return sorted.first;

    QualityOption? best;
    for (final v in withHeight) {
      if (v.height! <= target) {
        best = v;
        break;
      }
    }
    return best ?? withHeight.last;
  }

  static String _resolve(String baseUrl, String relative) {
    if (relative.startsWith('http://') || relative.startsWith('https://')) {
      return relative;
    }
    final base = Uri.tryParse(baseUrl);
    if (base == null) return relative;
    try {
      return base.resolve(relative).toString();
    } on FormatException {
      return relative;
    }
  }
}
