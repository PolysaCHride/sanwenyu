import 'dart:async';

import 'package:flutter/widgets.dart';

import 'player_failure.dart';

/// 一次播放请求。
///
/// 只描述「放什么」，不关心底层是 libmpv、ExoPlayer 还是系统播放器。
class MediaRequest {
  const MediaRequest({
    required this.url,
    this.headers = const <String, String>{},
    this.startAt,
    this.title,
  });

  final String url;
  final Map<String, String> headers;

  /// 起播位置（续播）。
  final Duration? startAt;
  final String? title;

  MediaRequest copyWith({
    String? url,
    Map<String, String>? headers,
    Duration? startAt,
    String? title,
  }) {
    return MediaRequest(
      url: url ?? this.url,
      headers: headers ?? this.headers,
      startAt: startAt ?? this.startAt,
      title: title ?? this.title,
    );
  }
}

/// 播放器内核的统一接口。
///
/// 抽象的目的只有一个：把 media_kit 的细节挡在播放页之外，后续换内核
/// （fvp、系统播放器、WebView）时播放页不用动。
abstract class PlayerEngine {
  /// 打开一个媒体并开始播放。
  Future<void> open(MediaRequest request);

  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);

  /// 0..100。
  Future<void> setVolume(double volume);

  Future<void> dispose();

  /// 渲染面。内核自己决定怎么画（video texture / platform view / 占位）。
  Widget buildSurface();

  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<void> get completed;

  /// 结构化失败。一个失败只上报一次，页面负责决定重试还是换源。
  Stream<PlayerFailure> get failures;

  /// 内核自身的提示（例如「已切换到软件渲染」）。
  Stream<String> get notices;

  Duration get currentPosition;
  Duration get currentDuration;
  bool get isPlaying;
  double get currentVolume;
  double get currentRate;
}

/// 播放器工厂：页面只依赖这个签名，便于测试注入假引擎。
typedef PlayerEngineBuilder = PlayerEngine Function();
