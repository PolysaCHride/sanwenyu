import 'dart:io';

import 'package:flutter/services.dart';

/// Android 系统媒体音量状态。
class VolumeState {
  const VolumeState({
    required this.current,
    required this.max,
    required this.fixed,
  });

  final int current;
  final int max;
  final bool fixed;

  double get ratio => max <= 0 ? 0 : current / max;
}

/// 系统媒体音量（Android STREAM_MUSIC）。
///
/// 桌面端没有对应通道，调用方继续使用播放器自身音量。
class VolumeService {
  const VolumeService();

  static const MethodChannel _method = MethodChannel('sanwenyu/volume');
  static const EventChannel _events = EventChannel('sanwenyu/volume_events');

  bool get supported => Platform.isAndroid;

  Future<VolumeState?> read() async {
    if (!supported) return null;
    try {
      final dynamic raw = await _method.invokeMethod<dynamic>('get');
      return _parse(raw);
    } on Object {
      return null;
    }
  }

  Future<VolumeState?> write(double ratio) async {
    if (!supported) return null;
    try {
      final dynamic raw = await _method.invokeMethod<dynamic>(
        'set',
        <String, double>{'value': ratio.clamp(0.0, 1.0)},
      );
      return _parse(raw);
    } on Object {
      return null;
    }
  }

  Stream<VolumeState> get changes {
    if (!supported) return const Stream<VolumeState>.empty();
    return _events.receiveBroadcastStream().map((dynamic event) {
      final VolumeState? state = _parse(event);
      if (state == null) {
        throw StateError('invalid volume event');
      }
      return state;
    });
  }

  static VolumeState? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final int current = (raw['current'] as num?)?.toInt() ?? 0;
    final int max = (raw['max'] as num?)?.toInt() ?? 0;
    final bool fixed = raw['fixed'] as bool? ?? false;
    if (max <= 0) return null;
    final int safeCurrent = current < 0 ? 0 : (current > max ? max : current);
    return VolumeState(current: safeCurrent, max: max, fixed: fixed);
  }
}
