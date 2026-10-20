import 'package:shared_preferences/shared_preferences.dart';

import 'm3u8_playlist.dart';
import 'render_policy.dart';

/// 播放器的全部用户可调项。
///
/// 这是一个纯数据对象：所有平台相关的副作用都留在 [PlayerPreferences]，
/// 这样缓冲区、清晰度这些规则可以直接被单测覆盖。
class PlayerConfig {
  const PlayerConfig({
    this.renderPolicy = RenderPolicy.auto,
    this.lowMemory = false,
    this.preferredQuality = QualityPreference.auto,
    this.autoPlayNext = true,
    this.gesturesEnabled = true,
    this.keyboardShortcuts = true,
    this.showDebugOverlay = false,
    this.volume = 100,
    this.speed = 1.0,
  });

  final RenderPolicy renderPolicy;
  final bool lowMemory;
  final QualityPreference preferredQuality;
  final bool autoPlayNext;
  final bool gesturesEnabled;
  final bool keyboardShortcuts;
  final bool showDebugOverlay;

  /// 0..100，跨集保留。
  final double volume;

  /// 0.25..4.0。
  final double speed;

  /// libmpv 的解复用缓存。低内存模式压到 8 MiB，能显著降低常驻内存。
  int get bufferSize => lowMemory ? 8 * 1024 * 1024 : 32 * 1024 * 1024;

  /// 低内存模式下同时限制输出尺寸，减少 GPU/内存压力。
  int? get maxOutputHeight => lowMemory ? 720 : null;

  PlayerConfig copyWith({
    RenderPolicy? renderPolicy,
    bool? lowMemory,
    QualityPreference? preferredQuality,
    bool? autoPlayNext,
    bool? gesturesEnabled,
    bool? keyboardShortcuts,
    bool? showDebugOverlay,
    double? volume,
    double? speed,
  }) {
    return PlayerConfig(
      renderPolicy: renderPolicy ?? this.renderPolicy,
      lowMemory: lowMemory ?? this.lowMemory,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      gesturesEnabled: gesturesEnabled ?? this.gesturesEnabled,
      keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
      showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'renderPolicy': renderPolicy.storageValue,
        'lowMemory': lowMemory,
        'preferredQuality': preferredQuality.storageValue,
        'autoPlayNext': autoPlayNext,
        'gesturesEnabled': gesturesEnabled,
        'keyboardShortcuts': keyboardShortcuts,
        'showDebugOverlay': showDebugOverlay,
        'volume': volume,
        'speed': speed,
      };

  factory PlayerConfig.fromJson(Map<String, Object?> json) {
    return PlayerConfig(
      renderPolicy: RenderPolicy.fromStorage(json['renderPolicy'] as String?),
      lowMemory: json['lowMemory'] as bool? ?? false,
      preferredQuality:
          QualityPreference.fromStorage(json['preferredQuality'] as String?),
      autoPlayNext: json['autoPlayNext'] as bool? ?? true,
      gesturesEnabled: json['gesturesEnabled'] as bool? ?? true,
      keyboardShortcuts: json['keyboardShortcuts'] as bool? ?? true,
      showDebugOverlay: json['showDebugOverlay'] as bool? ?? false,
      volume: ((json['volume'] as num?) ?? 100).toDouble().clamp(0, 100),
      speed: ((json['speed'] as num?) ?? 1).toDouble().clamp(0.25, 4),
    );
  }
}

/// 配置的读写入口。
class PlayerPreferences {
  const PlayerPreferences._();

  static const String keyRenderPolicy = 'player.renderPolicy';
  static const String keyLowMemory = 'player.lowMemory';
  static const String keyQuality = 'player.quality';
  static const String keyAutoNext = 'player.autoNext';
  static const String keyGestures = 'player.gestures';
  static const String keyKeyboard = 'player.keyboard';
  static const String keyDebugOverlay = 'player.debugOverlay';
  static const String keyVolume = 'player.volume';
  static const String keySpeed = 'player.speed';

  /// 0.2 之前只存了「硬件加速开关」，读一次做迁移。
  static const String legacyHardware = 'player.hardwareAcceleration';

  static PlayerConfig _current = const PlayerConfig();

  static PlayerConfig get current => _current;

  static Future<PlayerConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    _current = read(prefs);
    return _current;
  }

  /// 纯读取，便于测试。
  static PlayerConfig read(SharedPreferences prefs) {
    final bool? legacyValue = prefs.getBool(legacyHardware);
    final String? storedPolicy = prefs.getString(keyRenderPolicy);
    final RenderPolicy policy = storedPolicy == null && legacyValue == false
        ? RenderPolicy.software
        : RenderPolicy.fromStorage(storedPolicy);

    return PlayerConfig(
      renderPolicy: policy,
      lowMemory: prefs.getBool(keyLowMemory) ?? false,
      preferredQuality: QualityPreference.fromStorage(prefs.getString(keyQuality)),
      autoPlayNext: prefs.getBool(keyAutoNext) ?? true,
      gesturesEnabled: prefs.getBool(keyGestures) ?? true,
      keyboardShortcuts: prefs.getBool(keyKeyboard) ?? true,
      showDebugOverlay: prefs.getBool(keyDebugOverlay) ?? false,
      volume: (prefs.getDouble(keyVolume) ?? 100).clamp(0, 100),
      speed: (prefs.getDouble(keySpeed) ?? 1).clamp(0.25, 4),
    );
  }

  static Future<void> update(PlayerConfig config) async {
    _current = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRenderPolicy, config.renderPolicy.storageValue);
    await prefs.setBool(keyLowMemory, config.lowMemory);
    await prefs.setString(keyQuality, config.preferredQuality.storageValue);
    await prefs.setBool(keyAutoNext, config.autoPlayNext);
    await prefs.setBool(keyGestures, config.gesturesEnabled);
    await prefs.setBool(keyKeyboard, config.keyboardShortcuts);
    await prefs.setBool(keyDebugOverlay, config.showDebugOverlay);
    await prefs.setDouble(keyVolume, config.volume.clamp(0, 100));
    await prefs.setDouble(keySpeed, config.speed.clamp(0.25, 4));
    await prefs.remove(legacyHardware);
  }
}
