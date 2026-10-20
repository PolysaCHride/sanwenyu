/// URL 处理工具。
library;

/// 将相对地址补全为绝对地址。
String? resolveUrl(String? raw, String baseUrl) {
  if (raw == null) return null;
  var v = raw.trim();
  if (v.isEmpty) return null;
  if (v.startsWith('//')) return 'https:$v';
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  final uri = Uri.tryParse(baseUrl);
  if (uri == null) return v;
  try {
    return uri.resolve(v).toString();
  } on FormatException {
    return v;
  }
}

/// 取主机名用于展示。
String hostOf(String url) {
  final uri = Uri.tryParse(url);
  return uri?.host ?? url;
}

/// 简单判断是否像视频流地址。
bool looksLikeStream(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') ||
      lower.contains('.mp4') ||
      lower.contains('.flv') ||
      lower.contains('.mpd');
}