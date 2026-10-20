import 'dart:convert';

import 'package:dio/dio.dart';

import 'sync_settings.dart';

/// WebDAV 调用失败。
class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// 最小 WebDAV 客户端。
///
/// 只依赖标准方法：GET / PUT / MKCOL / PROPFIND。不引入额外依赖，
/// 也避免被第三方库的「目录树缓存」等行为绑住。
class WebDavClient {
  WebDavClient(this.settings, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 15),
              responseType: ResponseType.plain,
              validateStatus: (int? status) => status != null && status < 600,
            ));

  final SyncSettings settings;
  final Dio _dio;

  static const String _propfindBody = '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';

  Map<String, String> get _headers {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
    };
    if (settings.username.isNotEmpty || settings.password.isNotEmpty) {
      final String token =
          base64Encode(utf8.encode('${settings.username}:${settings.password}'));
      headers['Authorization'] = 'Basic $token';
    }
    return headers;
  }

  /// 读取远端文档；不存在返回 null。
  Future<String?> read() async {
    final Response<String> resp = await _dio.get<String>(
      settings.fileUrl,
      options: Options(headers: _headers),
    );
    final int code = resp.statusCode ?? 0;
    if (code == 404 || code == 410) return null;
    if (code >= 200 && code < 300) return resp.data ?? '';
    throw WebDavException(_messageFor(code), statusCode: code);
  }

  /// 写入远端文档；父目录不存在时自动创建。
  Future<void> write(String content) async {
    Response<String> resp = await _put(content);
    if (resp.statusCode == 404 || resp.statusCode == 409) {
      await ensureDirectories();
      resp = await _put(content);
    }
    final int code = resp.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw WebDavException(_messageFor(code), statusCode: code);
    }
  }

  Future<Response<String>> _put(String content) {
    return _dio.put<String>(
      settings.fileUrl,
      data: content,
      options: Options(
        headers: <String, String>{
          ..._headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
      ),
    );
  }

  /// 逐级创建 remotePath 的父目录。
  Future<void> ensureDirectories() async {
    final Uri uri = Uri.parse(settings.fileUrl);
    final List<String> segments = uri.pathSegments;
    if (segments.length <= 1) return;

    String current = '${uri.scheme}://${uri.authority}';
    for (final String segment in segments.sublist(0, segments.length - 1)) {
      if (segment.isEmpty) continue;
      current = '$current/${Uri.encodeComponent(segment)}';
      final Response<String> resp = await _dio.request<String>(
        current,
        options: Options(method: 'MKCOL', headers: _headers),
      );
      final int code = resp.statusCode ?? 0;
      // 201 创建成功；405 已存在；301/302 视为已存在（部分服务端会跳转）。
      if (code == 201 || code == 200 || code == 405 || code == 301 || code == 302) {
        continue;
      }
      if (code == 401 || code == 403) {
        throw WebDavException(_messageFor(code), statusCode: code);
      }
      // 其它状态不阻塞：PUT 会再报一次，错误信息更准确。
    }
  }

  /// 连接测试：优先 PROPFIND，服务端不支持时退回 GET。
  Future<void> testConnection() async {
    final String base = settings.serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final Response<String> resp = await _dio.request<String>(
      base,
      data: _propfindBody,
      options: Options(
        method: 'PROPFIND',
        headers: <String, String>{
          ..._headers,
          'Depth': '0',
          'Content-Type': 'application/xml; charset=utf-8',
        },
      ),
    );
    final int code = resp.statusCode ?? 0;
    if (code == 401 || code == 403) {
      throw WebDavException(_messageFor(code), statusCode: code);
    }
    if (code == 200 || code == 207 || code == 301 || code == 302) return;

    if (code == 405 || code == 501) {
      final Response<String> probe = await _dio.get<String>(
        settings.fileUrl,
        options: Options(headers: _headers),
      );
      final int probeCode = probe.statusCode ?? 0;
      if (probeCode == 401 || probeCode == 403) {
        throw WebDavException(_messageFor(probeCode), statusCode: probeCode);
      }
      // 404 说明服务器可达，只是文件还没建。
      if (probeCode == 404 || (probeCode >= 200 && probeCode < 300)) return;
      throw WebDavException(_messageFor(probeCode), statusCode: probeCode);
    }
    throw WebDavException(_messageFor(code), statusCode: code);
  }

  String _messageFor(int code) {
    return switch (code) {
      401 => 'Authentication failed — check the username and app password',
      403 => 'Access to this path is forbidden',
      404 => 'Path not found',
      409 => 'Parent collection missing',
      423 => 'File is locked',
      507 => 'Server storage is full',
      _ => 'WebDAV request failed',
    };
  }
}
