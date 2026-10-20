import 'dart:io';

import 'package:flutter/services.dart';

/// 系统亮度调节。
///
/// Android 走原生通道改窗口亮度；桌面端没有对应能力，返回 null，
/// 由播放页用一层黑色遮罩模拟。
class BrightnessService {
  const BrightnessService();

  static const MethodChannel _channel = MethodChannel('sanwenyu/brightness');

  bool get supported => Platform.isAndroid;

  Future<double?> read() async {
    if (!supported) return null;
    try {
      final value = await _channel.invokeMethod<double>('get');
      if (value == null) return null;
      return value.clamp(0.0, 1.0);
    } on Object {
      return null;
    }
  }

  Future<bool> write(double value) async {
    if (!supported) return false;
    try {
      await _channel.invokeMethod<void>('set', <String, double>{
        'value': value.clamp(0.01, 1.0),
      });
      return true;
    } on Object {
      return false;
    }
  }

  /// 退出播放页时恢复系统亮度。
  Future<void> reset() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('reset');
    } on Object {
      // 忽略：窗口销毁时系统也会恢复。
    }
  }
}
