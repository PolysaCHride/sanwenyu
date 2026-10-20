import 'package:flutter/material.dart';

/// 手势反馈的类型。
enum HudKind { seek, volume, brightness }

/// 手势层向上层报告的一条反馈。
class GestureFeedback {
  const GestureFeedback(this.kind, this.text, {this.icon});

  final HudKind kind;
  final String text;
  final IconData? icon;
}

/// 播放器手势层。
///
/// 只负责识别手势并把「意图」交给页面，不碰播放器，也不碰亮度/音量实现。
/// 这样手势逻辑可以单独演进，也不会和控制器状态耦合。
class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({
    required this.enabled,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSeekPreview,
    required this.onSeekCommit,
    required this.onVerticalStart,
    required this.onVerticalUpdate,
    required this.onVerticalEnd,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    super.key,
  });

  final bool enabled;
  final Duration position;
  final Duration duration;

  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  final ValueChanged<Duration> onSeekPreview;
  final ValueChanged<Duration> onSeekCommit;

  /// [vertical] 为 0 表示亮度区，1 表示音量区。
  final ValueChanged<int> onVerticalStart;

  /// [ratio] 为相对手势起点的位移比例（向上为正）。
  final void Function(int zone, double ratio) onVerticalUpdate;
  final VoidCallback onVerticalEnd;

  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  double _accumDx = 0;
  double _accumDy = 0;
  int _zone = 0;
  bool _seeking = false;
  bool _adjusting = false;

  Duration _preview = Duration.zero;

  void _startSeek(DragStartDetails details) {
    if (!widget.enabled) return;
    _seeking = true;
    _accumDx = 0;
    _preview = widget.position;
    widget.onSeekPreview(widget.position);
  }

  void _updateSeek(DragUpdateDetails details) {
    if (!_seeking) return;
    final width = context.size?.width ?? 1;
    final durationMs = widget.duration.inMilliseconds;
    if (durationMs <= 0) return;
    _accumDx += details.delta.dx;
    // 拖满整屏约等于整片时长，短视频不会因为一点位移就跳几十秒。
    final deltaMs = (_accumDx / width * durationMs).round();
    final targetMs = (widget.position.inMilliseconds + deltaMs).clamp(0, durationMs);
    _preview = Duration(milliseconds: targetMs);
    widget.onSeekPreview(_preview);
  }

  void _endSeek(DragEndDetails details) {
    if (!_seeking) return;
    _seeking = false;
    widget.onSeekCommit(_preview);
  }

  void _startVertical(DragStartDetails details) {
    if (!widget.enabled) return;
    final width = context.size?.width ?? 1;
    final x = details.localPosition.dx;
    _zone = x < width * 0.4 ? 0 : (x > width * 0.6 ? 1 : -1);
    if (_zone < 0) return;
    _adjusting = true;
    _accumDy = 0;
    widget.onVerticalStart(_zone);
  }

  void _updateVertical(DragUpdateDetails details) {
    if (!_adjusting) return;
    final height = context.size?.height ?? 1;
    _accumDy -= details.delta.dy;
    widget.onVerticalUpdate(_zone, (_accumDy / height).clamp(-1.0, 1.0));
  }

  void _endVertical(DragEndDetails details) {
    if (!_adjusting) return;
    _adjusting = false;
    widget.onVerticalEnd();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onHorizontalDragStart: _startSeek,
      onHorizontalDragUpdate: _updateSeek,
      onHorizontalDragEnd: _endSeek,
      onVerticalDragStart: _startVertical,
      onVerticalDragUpdate: _updateVertical,
      onVerticalDragEnd: _endVertical,
      onLongPressStart: (_) {
        if (widget.enabled) widget.onLongPressStart();
      },
      onLongPressEnd: (_) {
        if (widget.enabled) widget.onLongPressEnd();
      },
      child: const SizedBox.expand(),
    );
  }
}
