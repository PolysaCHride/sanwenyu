import 'package:dio/dio.dart';

import '../../core/network/http_client.dart';
import 'dlna_models.dart';

/// 投屏控制失败。
class DlnaException implements Exception {
  const DlnaException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// 一台设备的 AVTransport 控制器。
class DlnaClient {
  DlnaClient(this.device, this._http);

  final DlnaDevice device;
  final HttpClient _http;

  Future<void> cast({
    required String url,
    required String title,
    Duration? position,
  }) async {
    await _invoke(
      AvTransportAction.setUri,
      currentUri: url,
      metadata: buildDidlLite(url: url, title: title),
    );
    await play();
    if (position != null && position > Duration.zero) {
      await seek(position);
    }
  }

  Future<void> play() => _invoke(AvTransportAction.play);

  Future<void> pause() => _invoke(AvTransportAction.pause);

  Future<void> stop() => _invoke(AvTransportAction.stop);

  Future<void> seek(Duration position) => _invoke(
        AvTransportAction.seek,
        target: dlnaTime(position),
      );

  /// 读取 `CurrentTransportState`，失败返回 null（轮询用，不抛）。
  Future<String?> transportState() async {
    try {
      final String body = await _invoke(AvTransportAction.getInfo);
      final RegExpMatch? match =
          RegExp(r'<CurrentTransportState>([^<]+)</CurrentTransportState>').firstMatch(body);
      return match?.group(1);
    } on Object {
      return null;
    }
  }

  Future<String> _invoke(
    AvTransportAction action, {
    String? currentUri,
    String? metadata,
    String? target,
  }) async {
    final Response<String> resp = await _http.raw.post<String>(
      device.controlUrl,
      data: buildSoapEnvelope(
        action: action,
        currentUri: currentUri,
        metadata: metadata,
        target: target,
      ),
      options: Options(
        responseType: ResponseType.plain,
        contentType: 'text/xml; charset="utf-8"',
        headers: <String, String>{
          'SOAPACTION': action.soapAction,
          'Connection': 'close',
        },
      ),
    );
    final int code = resp.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw DlnaException('${action.action} failed', statusCode: code);
    }
    return resp.data ?? '';
  }
}
