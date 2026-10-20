import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/logger.dart';
import 'player_config.dart';
import 'player_engine.dart';
import 'player_failure.dart';
import 'render_policy.dart';

/// media_kit（libmpv / ExoPlayer）实现。
///
/// 渲染降级策略：
/// - [RenderPolicy.auto]：硬件渲染报错后自动重建控制器并用软件渲染续播；
/// - [RenderPolicy.hardware]：只报错，不降级（用于确认硬件是否可用）；
/// - [RenderPolicy.software]：一开始就用软件渲染。
class MediaKitEngine implements PlayerEngine {
  MediaKitEngine({required PlayerConfig config})
      : _config = config,
        _useHardware = config.renderPolicy.startsWithHardware {
    _createPlayer();
  }

  final PlayerConfig _config;

  Player? _player;
  VideoController? _controller;
  final ValueNotifier<int> _surfaceRevision = ValueNotifier<int>(0);

  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playingCtrl = StreamController<bool>.broadcast();
  final StreamController<bool> _bufferingCtrl =
      StreamController<bool>.broadcast();
  final StreamController<void> _completedCtrl =
      StreamController<void>.broadcast();
  final StreamController<PlayerFailure> _failureCtrl =
      StreamController<PlayerFailure>.broadcast();
  final StreamController<String> _noticeCtrl =
      StreamController<String>.broadcast();

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  MediaRequest? _request;
  bool _useHardware;
  bool _fallbackTried = false;
  bool _disposed = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _volume = 100;
  double _rate = 1.0;

  @override
  Stream<Duration> get position => _positionCtrl.stream;
  @override
  Stream<Duration> get duration => _durationCtrl.stream;
  @override
  Stream<bool> get playing => _playingCtrl.stream;
  @override
  Stream<bool> get buffering => _bufferingCtrl.stream;
  @override
  Stream<void> get completed => _completedCtrl.stream;
  @override
  Stream<PlayerFailure> get failures => _failureCtrl.stream;
  @override
  Stream<String> get notices => _noticeCtrl.stream;

  @override
  Duration get currentPosition => _position;
  @override
  Duration get currentDuration => _duration;
  @override
  bool get isPlaying => _playing;
  @override
  double get currentVolume => _volume;
  @override
  double get currentRate => _rate;

  /// 当前是否在用硬件渲染，调试面板会显示。
  bool get usingHardware => _useHardware;

  PlayerConfiguration _playerConfiguration() {
    return PlayerConfiguration(
      title: 'sanwenyu',
      logLevel: kDebugMode ? MPVLogLevel.info : MPVLogLevel.error,
      bufferSize: _config.bufferSize,
    );
  }

  VideoControllerConfiguration _videoConfiguration(bool hardware) {
    return VideoControllerConfiguration(
      enableHardwareAcceleration: hardware,
      hwdec: hardware ? null : 'no',
      height: _config.maxOutputHeight,
    );
  }

  void _createPlayer() {
    final player = Player(configuration: _playerConfiguration());
    _player = player;
    _controller = VideoController(
      player,
      configuration: _videoConfiguration(_useHardware),
    );
    _bind(player);
  }

  void _bind(Player player) {
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      player.stream.position.listen((Duration value) {
        _position = value;
        _positionCtrl.add(value);
      }),
      player.stream.duration.listen((Duration value) {
        _duration = value;
        _durationCtrl.add(value);
      }),
      player.stream.playing.listen((bool value) {
        _playing = value;
        _playingCtrl.add(value);
      }),
      player.stream.buffering.listen(_bufferingCtrl.add),
      player.stream.completed.listen((bool value) {
        if (value) _completedCtrl.add(null);
      }),
      player.stream.error.listen(_onError),
      player.stream.log.listen((PlayerLog log) {
        appLogger.d('[mpv/${log.prefix}] ${log.text}');
      }),
    ]);
  }

  void _onError(String raw) {
    if (_disposed) return;
    final failure = PlayerFailureClassifier.classify(raw);

    // 渲染面失败且允许自动降级：换软件渲染再试一次，不惊动用户。
    final canFallback = failure.kind == FailureKind.render &&
        _config.renderPolicy == RenderPolicy.auto &&
        _useHardware &&
        !_fallbackTried;
    if (canFallback) {
      unawaited(_switchToSoftware());
      return;
    }

    appLogger.w('播放失败(${failure.kind.name}): $raw');
    _failureCtrl.add(failure);
  }

  Future<void> _switchToSoftware() async {
    _fallbackTried = true;
    final previous = _player;
    final resumeAt = _position;
    final request = _request;

    _noticeCtrl.add('render_fallback');
    appLogger.w('渲染后端创建失败，切换到软件渲染');

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _useHardware = false;
    _createPlayer();
    _surfaceRevision.value++;

    final player = _player;
    if (player == null) return;

    if (request != null) {
      try {
        await player.open(
          Media(request.url, httpHeaders: request.headers),
          play: true,
        );
        if (resumeAt > Duration.zero) await player.seek(resumeAt);
        await player.setVolume(_volume);
        await player.setRate(_rate);
      } on Object catch (e) {
        _failureCtrl.add(
          PlayerFailure(kind: FailureKind.render, detail: e.toString()),
        );
      }
    }

    // 旧控制器要等新画面挂载后再释放，避免纹理被提前销毁。
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        try {
          await previous?.dispose();
        } on Object {
          // 忽略释放期的异常。
        }
      }),
    );
  }

  @override
  Future<void> open(MediaRequest request) async {
    _request = request;
    _volume = _config.volume;
    _rate = _config.speed;

    final player = _player;
    if (player == null) {
      throw StateError('player engine not ready');
    }
    await player.open(
      Media(
        request.url,
        httpHeaders: request.headers,
        start: request.startAt,
      ),
      play: true,
    );
    await player.setVolume(_volume);
    await player.setRate(_rate);
  }

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> playOrPause() async => _player?.playOrPause();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.25, 4);
    await _player?.setRate(_rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 100);
    await _player?.setVolume(_volume);
  }

  @override
  Widget buildSurface() {
    return ValueListenableBuilder<int>(
      valueListenable: _surfaceRevision,
      builder: (BuildContext context, int revision, Widget? child) {
        final controller = _controller;
        if (controller == null) {
          return const ColoredBox(color: Colors.black);
        }
        return Video(
          key: ValueKey<int>(revision),
          controller: controller,
          controls: (VideoState state) => const SizedBox.shrink(),
          fill: Colors.black,
          fit: BoxFit.contain,
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    try {
      await _player?.dispose();
    } on Object {
      // 释放失败不应阻塞页面退出。
    }
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _completedCtrl.close();
    await _failureCtrl.close();
    await _noticeCtrl.close();
    _surfaceRevision.dispose();
  }
}
