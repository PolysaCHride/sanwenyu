/// 失败类型。页面据此给出不同的下一步动作。
enum FailureKind {
  /// 网络不可达、超时、DNS 失败。
  network,

  /// 容器/编码不支持，或数据损坏。
  decode,

  /// 渲染面创建失败（EGL/D3D/GPU）。
  render,

  /// 播放地址过期、鉴权失败（403/404/签名过期）。
  expired,

  /// 协议或格式不在支持范围。
  unsupported,

  unknown,
}

/// 结构化的播放失败。
class PlayerFailure {
  const PlayerFailure({
    required this.kind,
    this.detail = '',
    this.retryable = true,
  });

  final FailureKind kind;

  /// 原始错误文本，只用于排障，不直接展示给普通用户。
  final String detail;

  final bool retryable;

  @override
  String toString() => 'PlayerFailure(${kind.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// 把底层五花八门的错误文本归类。
///
/// libmpv 的错误没有稳定错误码，只能按关键字归类；归类结果只影响引导文案，
/// 不影响「能不能重试」这件事本身。
class PlayerFailureClassifier {
  const PlayerFailureClassifier._();

  static const List<String> _render = <String>[
    'egl',
    'd3d',
    'direct3d',
    'failed to create surface',
    'cannot create window',
    'failed to create window',
    'vo/gpu',
    'opengl',
    'vulkan',
    'render context',
    'failed to initialize video',
  ];

  static const List<String> _expired = <String>[
    '403',
    '404',
    '410',
    'forbidden',
    'expired',
    'signature',
    '鉴权',
    '地址过期',
  ];

  static const List<String> _decode = <String>[
    'codec',
    'decode',
    'format',
    'moov atom',
    'invalid data',
    'corrupt',
  ];

  static const List<String> _unsupported = <String>[
    'unsupported',
    'protocol not supported',
    'not implemented',
  ];

  static const List<String> _network = <String>[
    'network',
    'timed out',
    'timeout',
    'connection',
    'resolve',
    'dns',
    'socket',
    'refused',
    'unreachable',
    'http error',
    'unexpected eof',
    'failed to open',
  ];

  /// 归类一条原始错误。
  static PlayerFailure classify(String raw) {
    final text = raw.toLowerCase();
    FailureKind kind = FailureKind.unknown;

    if (_containsAny(text, _render)) {
      kind = FailureKind.render;
    } else if (_containsAny(text, _expired)) {
      kind = FailureKind.expired;
    } else if (_containsAny(text, _decode)) {
      kind = FailureKind.decode;
    } else if (_containsAny(text, _unsupported)) {
      kind = FailureKind.unsupported;
    } else if (_containsAny(text, _network)) {
      kind = FailureKind.network;
    }

    return PlayerFailure(
      kind: kind,
      detail: raw.trim(),
      // 渲染失败靠换后端解决，直接重试没有意义。
      retryable: kind != FailureKind.render,
    );
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }
}
