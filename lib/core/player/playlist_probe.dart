import '../network/http_client.dart';
import 'm3u8_playlist.dart';

/// 读取播放地址的播放列表，给 UI 提供清晰度列表。
///
/// 失败一律返回空列表：拿不到清晰度不应该影响播放。
class PlaylistProbe {
  const PlaylistProbe(this._http);

  final HttpClient _http;

  Future<List<QualityOption>> inspect(
    String url, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (!_looksLikeM3u8(url)) return const <QualityOption>[];
    try {
      final resp = await _http.getText(url, headers: headers);
      final body = resp.data ?? '';
      if (!M3u8Master.isMaster(body)) return const <QualityOption>[];
      return M3u8Master.parse(body, url).variants;
    } on Object {
      return const <QualityOption>[];
    }
  }

  static bool _looksLikeM3u8(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.contains('.m3u8') || path.contains('/playlist');
  }
}
