import 'package:dio/dio.dart';

/// 统一 HTTP 客户端。
class HttpClient {
  HttpClient({this.userAgent = _defaultUa}) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.plain,
        headers: <String, dynamic>{
          'User-Agent': userAgent,
          'Accept-Language': 'zh-CN,zh;q=0.9,ko;q=0.8',
        },
        validateStatus: (int? s) => s != null && s < 500,
      ),
    );
  }

  static const String _defaultUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  final String userAgent;
  late final Dio _dio;

  Dio get raw => _dio;

  void setReferer(String? referer) {
    if (referer == null || referer.isEmpty) {
      _dio.options.headers.remove('Referer');
    } else {
      _dio.options.headers['Referer'] = referer;
    }
  }

  Future<Response<String>> getText(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? query,
  }) {
    return _dio.get<String>(
      url,
      queryParameters: query,
      options: Options(headers: headers),
    );
  }

  Future<Response<String>> postForm(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) {
    return _dio.post<String>(
      url,
      data: body,
      options: Options(
        headers: headers,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  /// 直接读字节，供二进制/编码兜底使用。
  Future<Response<List<int>>> getBytes(String url, {Map<String, String>? headers}) {
    return _dio.get<List<int>>(
      url,
      options: Options(headers: headers, responseType: ResponseType.bytes),
    );
  }

  Future<Response<dynamic>> getJson(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    return _dio.get<dynamic>(
      url,
      queryParameters: query,
      options: Options(headers: headers, responseType: ResponseType.json),
    );
  }
}