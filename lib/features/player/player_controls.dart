import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'player_gesture_layer.dart';

/// 播放页顶栏。
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.qualityLabel,
    this.onQuality,
    this.onCast,
    this.casting = false,
    this.onMenu,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final String? qualityLabel;
  final VoidCallback? onQuality;
  final VoidCallback? onCast;
  final bool casting;
  final ValueChanged<String>? onMenu;

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                tooltip: l.back,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (qualityLabel != null)
                TextButton(
                  onPressed: onQuality,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '${l.qualityLabel} · $qualityLabel',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (onCast != null)
                IconButton(
                  onPressed: onCast,
                  tooltip: l.cast,
                  icon: Icon(
                    casting ? Icons.cast_connected : Icons.cast,
                    color: casting ? Theme.of(context).colorScheme.primary : Colors.white,
                  ),
                ),
              if (onMenu != null)
                PopupMenuButton<String>(
                  tooltip: l.settings,
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: onMenu,
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'copy',
                      child: Text(l.copyStreamUrl),
                    ),
                    PopupMenuItem<String>(
                      value: 'player-settings',
                      child: Text(l.playerSettings),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放页底栏。
class PlayerBottomBar extends StatefulWidget {
  const PlayerBottomBar({
    required this.position,
    required this.duration,
    required this.playing,
    required this.speed,
    required this.onSeek,
    required this.onTogglePlay,
    required this.onSpeed,
    this.onEpisodes,
    this.onNext,
    this.onFullscreen,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
  final double speed;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSpeed;
  final VoidCallback? onEpisodes;
  final VoidCallback? onNext;
  final VoidCallback? onFullscreen;

  @override
  State<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends State<PlayerBottomBar> {
  double? _dragValue;

  static const List<double> _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final int totalMs = widget.duration.inMilliseconds;
    final double ratio = totalMs <= 0
        ? 0
        : (_dragValue ?? (widget.position.inMilliseconds / totalMs)).clamp(0.0, 1.0);
    final Duration shown = _dragValue == null
        ? widget.position
        : Duration(milliseconds: (ratio * totalMs).round());

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: ratio,
                  onChanged: totalMs <= 0
                      ? null
                      : (double value) => setState(() => _dragValue = value),
                  onChangeEnd: totalMs <= 0
                      ? null
                      : (double value) {
                          setState(() => _dragValue = null);
                          widget.onSeek(
                            Duration(milliseconds: (value * totalMs).round()),
                          );
                        },
                ),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: widget.onTogglePlay,
                    tooltip: widget.playing ? l.pause : l.play,
                    icon: Icon(
                      widget.playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${formatDuration(shown)} / ${formatDuration(widget.duration)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<double>(
                    tooltip: l.speedLabel,
                    initialValue: widget.speed,
                    onSelected: widget.onSpeed,
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                      for (final double s in _speeds)
                        PopupMenuItem<double>(value: s, child: Text('${s}x')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${widget.speed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  if (widget.onEpisodes != null)
                    IconButton(
                      onPressed: widget.onEpisodes,
                      tooltip: l.episodes,
                      icon: const Icon(Icons.list, color: Colors.white),
                    ),
                  if (widget.onNext != null)
                    IconButton(
                      onPressed: widget.onNext,
                      tooltip: l.nextEpisode,
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                    ),
                  if (widget.onFullscreen != null)
                    IconButton(
                      onPressed: widget.onFullscreen,
                      tooltip: l.fullscreen,
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手势反馈浮层。
class PlayerHudOverlay extends StatelessWidget {
  const PlayerHudOverlay({required this.feedback, super.key});

  final GestureFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final GestureFeedback? data = feedback;
    if (data == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (data.icon != null) ...<Widget>[
                Icon(data.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                data.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `mm:ss` / `h:mm:ss`。
String formatDuration(Duration d) {
  if (d.isNegative) return '00:00';
  final int hours = d.inHours;
  final String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
