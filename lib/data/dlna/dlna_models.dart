/// DLNA / UPnP AVTransport 的最小实现所需的数据与文本工具。
///
/// 全部为纯函数，方便在没有电视的机器上把协议细节测干净。
library;

/// 一台可投屏的设备。
class DlnaDevice {
  const DlnaDevice({
    required this.friendlyName,
    required this.location,
    required this.controlUrl,
    this.modelName,
    this.manufacturer,
  });

  final String friendlyName;

  /// 设备描述 XML 的地址。
  final String location;

  /// AVTransport 控制地址（绝对 URL）。
  final String controlUrl;
  final String? modelName;
  final String? manufacturer;

  DlnaDevice copyWith({
    String? friendlyName,
    String? controlUrl,
    String? modelName,
    String? manufacturer,
  }) {
    return DlnaDevice(
      friendlyName: friendlyName ?? this.friendlyName,
      location: location,
      controlUrl: controlUrl ?? this.controlUrl,
      modelName: modelName ?? this.modelName,
      manufacturer: manufacturer ?? this.manufacturer,
    );
  }
}

/// 一条 SSDP 响应。
class SsdpResponse {
  const SsdpResponse({required this.headers});

  final Map<String, String> headers;

  String? get location => headers['location'];
  String? get server => headers['server'];
  String? get usn => headers['usn'];

  static SsdpResponse parse(String text) {
    final Map<String, String> headers = <String, String>{};
    final List<String> lines = text.split(RegExp(r'\r?\n'));
    for (final String line in lines.skip(1)) {
      final int index = line.indexOf(':');
      if (index <= 0) continue;
      final String key = line.substring(0, index).trim().toLowerCase();
      final String value = line.substring(index + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      headers[key] = value;
    }
    return SsdpResponse(headers: headers);
  }
}

/// 构造 M-SEARCH 请求。
String buildMSearchRequest({String searchTarget = mediaRenderer}) {
  return 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $searchTarget\r\n'
      '\r\n';
}

const String mediaRenderer = 'urn:schemas-upnp-org:device:MediaRenderer:1';
const String avTransportService = 'urn:schemas-upnp-org:service:AVTransport:1';

/// 从设备描述 XML 中取展示名与 AVTransport 控制地址。
///
/// 不引入 XML 解析器：设备描述的结构非常固定，正则足够，
/// 而且能容忍不少国产电视不规范的输出。
DlnaDevice parseDeviceDescription({
  required String xml,
  required String location,
}) {
  final String friendlyName =
      _unescape(_tag(xml, 'friendlyName') ?? _tag(xml, 'modelName') ?? 'DLNA');
  final String? modelName = _tag(xml, 'modelName');
  final String? manufacturer = _tag(xml, 'manufacturer');

  final RegExp servicePattern =
      RegExp(r'<service>(.*?)</service>', dotAll: true, caseSensitive: false);
  String? controlPath;
  for (final RegExpMatch match in servicePattern.allMatches(xml)) {
    final String block = match.group(1) ?? '';
    final String type = _tag(block, 'serviceType') ?? '';
    if (type.contains('AVTransport')) {
      controlPath = _tag(block, 'controlURL');
      if (controlPath != null && controlPath.isNotEmpty) break;
    }
  }

  final String controlUrl = controlPath == null || controlPath.isEmpty
      ? location
      : _resolve(location, controlPath);

  return DlnaDevice(
    friendlyName: friendlyName,
    location: location,
    controlUrl: controlUrl,
    modelName: modelName,
    manufacturer: manufacturer,
  );
}

String? _tag(String xml, String name) {
  final RegExp pattern = RegExp(
    '<$name[^>]*>(.*?)</$name>',
    dotAll: true,
    caseSensitive: false,
  );
  final RegExpMatch? match = pattern.firstMatch(xml);
  final String? value = match?.group(1)?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

String _resolve(String base, String relative) {
  final Uri? uri = Uri.tryParse(relative);
  if (uri != null && uri.hasScheme) return relative;
  final Uri? baseUri = Uri.tryParse(base);
  if (baseUri == null) return relative;
  try {
    return baseUri.resolve(relative).toString();
  } on FormatException {
    return relative;
  }
}

String _unescape(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

/// XML 文本转义（属性与节点内容都适用）。
String escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// 按地址推断 renderer 能接受的 MIME。
String protocolInfoFor(String url) {
  final String lower = url.toLowerCase();
  if (lower.contains('.m3u8')) {
    return 'http-get:*:application/vnd.apple.mpegurl:*';
  }
  if (lower.contains('.mpd')) {
    return 'http-get:*:application/dash+xml:*';
  }
  if (lower.contains('.flv')) {
    return 'http-get:*:video/x-flv:*';
  }
  return 'http-get:*:video/mp4:*';
}

/// DIDL-Lite 元数据。
String buildDidlLite({required String url, required String title}) {
  return '<DIDL-Lite '
      'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="1">'
      '<dc:title>${escapeXml(title)}</dc:title>'
      '<upnp:class>object.item.videoItem</upnp:class>'
      '<res protocolInfo="${protocolInfoFor(url)}">${escapeXml(url)}</res>'
      '</item></DIDL-Lite>';
}

/// AVTransport 的 SOAP 动作。
enum AvTransportAction {
  setUri('SetAVTransportURI'),
  play('Play'),
  pause('Pause'),
  stop('Stop'),
  seek('Seek'),
  getInfo('GetTransportInfo');

  const AvTransportAction(this.action);

  final String action;

  String get soapAction => '"$avTransportService#$action"';
}

/// 构造 SOAP 请求体。
String buildSoapEnvelope({
  required AvTransportAction action,
  String? currentUri,
  String? metadata,
  String? target,
}) {
  final StringBuffer args = StringBuffer();
  if (action == AvTransportAction.setUri) {
    args.write('<InstanceID>0</InstanceID>');
    args.write('<CurrentURI>${escapeXml(currentUri ?? '')}</CurrentURI>');
    args.write('<CurrentURIMetaData>${escapeXml(metadata ?? '')}</CurrentURIMetaData>');
  } else if (action == AvTransportAction.seek) {
    args.write('<InstanceID>0</InstanceID>');
    args.write('<Unit>REL_TIME</Unit>');
    args.write('<Target>${escapeXml(target ?? '00:00:00')}</Target>');
  } else if (action == AvTransportAction.getInfo) {
    args.write('<InstanceID>0</InstanceID>');
  }

  return '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" '
      'xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
      '<s:Body>'
      '<u:${action.action} xmlns:u="$avTransportService">$args</u:${action.action}>'
      '</s:Body></s:Envelope>';
}

/// `HH:MM:SS`，DLNA Seek 用。
String dlnaTime(Duration position) {
  final int hours = position.inHours;
  final String minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
}
