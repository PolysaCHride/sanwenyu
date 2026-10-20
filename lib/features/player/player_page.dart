import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_flags.dart';
import '../../app/providers.dart';
import '../../core/logger.dart';
import '../../core/platform/brightness_service.dart';
import '../../core/platform/volume_service.dart';
import '../../core/player/m3u8_playlist.dart';
import '../../core/player/media_kit_engine.dart';
import '../../core/player/player_config.dart';
import '../../core/player/player_engine.dart';
import '../../core/player/player_failure.dart';
import '../../core/player/playlist_probe.dart';
import '../../core/player/render_policy.dart';
import '../../data/dlna/dlna_client.dart';
import '../../data/dlna/dlna_models.dart';
import '../../data/repository/library_repository.dart';
import '../../domain/models/library.dart';
import '../../domain/models/media.dart';
import '../../domain/models/source_config.dart';
import '../../domain/source/source_adapter.dart';
import '../../l10n/l10n.dart';
import 'dlna_sheet.dart';
import 'player_controls.dart';
import 'player_gesture_layer.dart';

/// 内置播放器。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    required this.seriesId,
    required this.episodeIndex,
    required this.sourceId,
    required this.sourceKey,
    this.title,
    super.key,
  });

  final String seriesId;
  final int episodeIndex;
  final String sourceId;
  final String sourceKey;
  final String? title;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  final BrightnessService _brightnessService = const BrightnessService();
  final VolumeService _volumeService = const VolumeService();
  bool _systemVolume = false;
  StreamSubscription<VolumeState>? _volumeSub;
  Timer? _volumeWriteTimer;
  double _volumeBeforeMute = 100;
  final ValueNotifier<Duration> _position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> _duration = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _buffering = ValueNotifier<bool>(false);
  final ValueNotifier<GestureFeedback?> _hud = ValueNotifier<GestureFeedback?>(
    null,
  );

  late PlayerConfig _config = PlayerPreferences.current;
  late final LibraryRepository _library;
  PlayerEngine? _engine;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  List<EpisodeRef> _episodes = const <EpisodeRef>[];
  EpisodeRef? _current;
  List<QualityOption> _qualities = const <QualityOption>[];
  QualityOption? _selectedQuality;
  bool _qualityIsAuto = true;

  String? _resolvedUrl;
  Map<String, String> _resolvedHeaders = const <String, String>{};
  bool _resolving = false;
  bool _bootLoading = true;
  PlayerFailure? _failure;
  bool _noEpisodes = false;
  bool _autoReResolved = false;

  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _hudTimer;

  double _speed = 1.0;
  double _volume = 100;
  final ValueNotifier<double> _brightness = ValueNotifier<double>(1.0);
  bool _brightnessNative = false;
  double _verticalBase = 1.0;
  int _verticalZone = 0;
  double? _speedBeforeLongPress;

  bool _immersive = false;
  bool _usingHardware = true;
  bool _fallbackNotified = false;
  DlnaDevice? _castingDevice;
  bool _wasPlayingBeforeCast = false;

  bool get _loading => _resolving || _bootLoading;

  @override
  void initState() {
    super.initState();
    _library = ref.read(libraryRepositoryProvider);
    _config = PlayerPreferences.current;
    _speed = _config.speed;
    _volume = _config.volume;
    _buildEngine();
    _loadBrightness();
    _initVolume();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveProgress(),
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _saveProgress();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _hudTimer?.cancel();
    _volumeWriteTimer?.cancel();
    unawaited(_volumeSub?.cancel() ?? Future<void>.value());
    _detachEngine();
    unawaited(_engine?.dispose() ?? Future<void>.value());
    _position.dispose();
    _duration.dispose();
    _playing.dispose();
    _buffering.dispose();
    _hud.dispose();
    _brightness.dispose();
    unawaited(_brightnessService.reset());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  // ---------- 引擎 ----------

  void _buildEngine() {
    final MediaKitEngine engine = MediaKitEngine(config: _config);
    _engine = engine;
    _usingHardware = _config.renderPolicy.startsWithHardware;
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      engine.position.listen((Duration value) => _position.value = value),
      engine.duration.listen((Duration value) => _duration.value = value),
      engine.playing.listen((bool value) {
        _playing.value = value;
        if (value) {
          _scheduleHide();
        } else {
          _cancelHide();
        }
      }),
      engine.buffering.listen((bool value) => _buffering.value = value),
      engine.completed.listen((_) => _onCompleted()),
      engine.failures.listen(_onFailure),
      engine.notices.listen(_onEngineNotice),
    ]);
  }

  void _detachEngine() {
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }

  Future<void> _recreateEngine({
    PlayerConfig? config,
    Duration? resumeAt,
  }) async {
    final Duration position = resumeAt ?? _position.value;
    final String? url = _resolvedUrl;
    final Map<String, String> headers = _resolvedHeaders;
    final EpisodeRef? current = _current;

    _detachEngine();
    final PlayerEngine? old = _engine;
    _engine = null;
    setState(() {
      _config = config ?? _config;
      _failure = null;
      _resolving = true;
    });
    await old?.dispose();
    if (!mounted) return;
    setState(_buildEngine);
    if (url == null) {
      setState(() => _resolving = false);
      return;
    }
    try {
      await _engine!.open(
        MediaRequest(
          url: url,
          headers: headers,
          startAt: position > Duration.zero ? position : null,
          title: current?.title,
        ),
      );
      if (!mounted) return;
      setState(() => _resolving = false);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _failure = PlayerFailure(
          kind: FailureKind.unknown,
          detail: e.toString(),
        );
      });
    }
  }

  Future<void> _switchRenderer(RenderPolicy policy) async {
    final PlayerConfig next = _config.copyWith(renderPolicy: policy);
    _config = next;
    await PlayerPreferences.update(next);
    await _recreateEngine(config: next);
  }

  void _onEngineNotice(String notice) {
    if (notice != 'render_fallback') return;
    _usingHardware = false;
    if (_fallbackNotified) return;
    _fallbackNotified = true;
    if (!mounted) return;
    final L10n l = L10n.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l.rendererFallback),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onFailure(PlayerFailure failure) {
    if (!mounted) return;
    if (failure.kind == FailureKind.expired && !_autoReResolved) {
      _autoReResolved = true;
      final EpisodeRef? ep = _current;
      if (ep != null) {
        // 重新解析一次；不要重置过期守卫，否则同一条坏地址会无限重试。
        unawaited(_playEpisode(ep, resetExpiredGuard: false));
        return;
      }
    }
    appLogger.w('播放失败: $failure');
    setState(() {
      _failure = failure;
      _resolving = false;
      _bootLoading = false;
      _controlsVisible = true;
    });
    _cancelHide();
  }

  void _onCompleted() {
    if (!mounted) return;
    if (!_config.autoPlayNext) {
      setState(() => _controlsVisible = true);
      return;
    }
    final EpisodeRef? next = _next;
    if (next != null) {
      unawaited(_playEpisode(next));
    } else {
      setState(() => _controlsVisible = true);
    }
  }

  // ---------- 数据 ----------

  SourceAdapter? _adapter() {
    final repo = ref.read(sourceRepositoryProvider);
    final SourceConfig? config = repo
        .all()
        .where((SourceConfig s) => s.id == widget.sourceId)
        .firstOrNull;
    if (config == null) return null;
    return repo.adapterFor(config);
  }

  Future<void> _bootstrap() async {
    try {
      final repo = ref.read(sourceRepositoryProvider);

      List<EpisodeRef> episodes = _library.episodesOf(widget.seriesId);
      if (episodes.isEmpty) {
        final SourceConfig? config = repo
            .all()
            .where((SourceConfig s) => s.id == widget.sourceId)
            .firstOrNull;
        if (config == null) throw StateError('source not found');
        final SourceAdapter? adapter = repo.adapterFor(config);
        if (adapter == null) throw StateError('adapter unavailable');
        final SeriesDetail detail = await adapter.detail(widget.sourceKey);
        _library.upsertSeries(detail);
        episodes = detail.episodes;
      }

      if (!mounted) return;
      if (episodes.isEmpty) {
        setState(() {
          _bootLoading = false;
          _noEpisodes = true;
          _failure = const PlayerFailure(kind: FailureKind.unsupported);
        });
        return;
      }

      final EpisodeRef current = episodes.firstWhere(
        (EpisodeRef e) => e.index == widget.episodeIndex,
        orElse: () => episodes.first,
      );
      setState(() {
        _episodes = episodes;
        _current = current;
        _bootLoading = false;
      });
      await _playEpisode(current, initial: true);
    } on Object catch (e) {
      appLogger.e('播放初始化失败: $e');
      if (!mounted) return;
      setState(() {
        _bootLoading = false;
        _failure = PlayerFailure(
          kind: FailureKind.unknown,
          detail: e.toString(),
        );
      });
    }
  }

  Future<void> _playEpisode(
    EpisodeRef episode, {
    bool initial = false,
    Duration? startAt,
    bool resetExpiredGuard = true,
  }) async {
    if (!mounted) return;
    if (_castingDevice != null) {
      unawaited(_stopCasting(resume: false));
    }
    setState(() {
      _resolving = true;
      _failure = null;
      _noEpisodes = false;
      _current = episode;
      _qualities = const <QualityOption>[];
      _selectedQuality = null;
      _qualityIsAuto = true;
      _resolvedUrl = null;
      if (resetExpiredGuard) _autoReResolved = false;
    });

    try {
      final SourceAdapter? adapter = _adapter();
      if (adapter == null) throw StateError('source unavailable');
      final PlayInfo info = await adapter.resolve(
        episode,
        detailUrl: widget.sourceKey,
      );
      final String? directUrl = info.url;
      if (info.mode != PlayMode.direct ||
          directUrl == null ||
          directUrl.isEmpty) {
        throw StateError(info.message ?? 'resolve failed');
      }

      final List<QualityOption> qualities =
          await PlaylistProbe(ref.read(httpClientProvider))
              .inspect(directUrl, headers: info.headers)
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => const <QualityOption>[],
              );
      final QualityOption? picked = M3u8Master.pick(
        qualities,
        _config.preferredQuality,
      );
      final String url = picked?.url ?? directUrl;

      _resolvedUrl = url;
      _resolvedHeaders = info.headers;
      final Duration? resume =
          startAt ?? (initial ? _resumePositionFor(episode) : null);

      await _engine?.open(
        MediaRequest(
          url: url,
          headers: info.headers,
          startAt: resume,
          title: episode.title,
        ),
      );
      await _engine?.setRate(_speed);
      await _engine?.setVolume(_volumeService.supported ? 100 : _volume);

      if (!mounted) return;
      setState(() {
        _resolving = false;
        _qualities = qualities;
        _selectedQuality = picked;
      });
      _scheduleHide();
    } on Object catch (e) {
      appLogger.e('解析播放地址失败: $e');
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _bootLoading = false;
        _failure = PlayerFailure(
          kind: FailureKind.unknown,
          detail: e.toString(),
        );
      });
    }
  }

  Duration? _resumePositionFor(EpisodeRef episode) {
    final ProgressRecord? record = _library.progressRecordOf(widget.seriesId);
    if (record == null) return null;
    final String expected = '${widget.seriesId}#${episode.index}';
    if (record.episodeId != expected) return null;
    if (record.duration <= Duration.zero) return null;
    final double ratio =
        record.position.inMilliseconds / record.duration.inMilliseconds;
    if (ratio >= 0.95) return null;
    return record.position > const Duration(seconds: 5)
        ? record.position
        : null;
  }

  void _saveProgress() {
    final EpisodeRef? current = _current;
    final Duration duration = _duration.value;
    if (current == null || duration.inMilliseconds <= 0) return;
    _library.saveProgress(
      seriesId: widget.seriesId,
      episodeId: '${widget.seriesId}#${current.index}',
      position: _position.value,
      duration: duration,
    );
  }

  EpisodeRef? get _next {
    final EpisodeRef? cur = _current;
    if (cur == null) return null;
    final int i = _episodes.indexWhere((EpisodeRef e) => e.index == cur.index);
    if (i < 0 || i + 1 >= _episodes.length) return null;
    return _episodes[i + 1];
  }

  // ---------- 交互 ----------

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing.value) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    if (_failure != null) {
      await _retry();
      return;
    }
    await _engine?.playOrPause();
  }

  Future<void> _retry() async {
    final String? url = _resolvedUrl;
    if (url == null) {
      final EpisodeRef? ep = _current;
      if (ep != null) await _playEpisode(ep);
      return;
    }
    setState(() {
      _failure = null;
      _resolving = true;
    });
    try {
      await _engine?.open(
        MediaRequest(
          url: url,
          headers: _resolvedHeaders,
          startAt: _position.value > Duration.zero ? _position.value : null,
          title: _current?.title,
        ),
      );
      if (!mounted) return;
      setState(() => _resolving = false);
      _scheduleHide();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _failure = PlayerFailure(
          kind: FailureKind.unknown,
          detail: e.toString(),
        );
      });
    }
  }

  Future<void> _reResolve() async {
    final EpisodeRef? ep = _current;
    if (ep == null) return;
    await _playEpisode(ep);
  }

  void _showHud(GestureFeedback feedback) {
    _hud.value = feedback;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _hud.value = null;
    });
  }

  void _onSeekPreview(Duration target) {
    _showHud(
      GestureFeedback(
        HudKind.seek,
        '${formatDuration(target)} / ${formatDuration(_duration.value)}',
        icon: Icons.fast_forward,
      ),
    );
  }

  void _onSeekCommit(Duration target) {
    _engine?.seek(target);
    _position.value = target;
    _hud.value = null;
  }

  void _onVerticalStart(int zone) {
    _verticalZone = zone;
    _verticalBase = zone == 0 ? _brightness.value : _volume;
  }

  void _onVerticalUpdate(int zone, double ratio) {
    if (zone == 0) {
      final double value = (_verticalBase + ratio).clamp(0.05, 1.0);
      _brightness.value = value;
      if (_brightnessNative) {
        unawaited(_writeBrightness(value));
      }
      _showHud(
        GestureFeedback(
          HudKind.brightness,
          '${(value * 100).round()}%',
          icon: Icons.brightness_6,
        ),
      );
    } else {
      final double value = (_verticalBase + ratio * 100).clamp(0.0, 100.0);
      _setVolume(value);
      _showHud(
        GestureFeedback(
          HudKind.volume,
          '${value.round()}%',
          icon: value == 0 ? Icons.volume_off : Icons.volume_up,
        ),
      );
    }
  }

  Future<void> _writeBrightness(double value) async {
    final bool ok = await _brightnessService.write(value);
    if (!ok && mounted && _brightnessNative) {
      setState(() => _brightnessNative = false);
    }
  }

  void _onVerticalEnd() {
    if (_verticalZone == 1) {
      if (_systemVolume) {
        _setVolume(_volume, immediate: true);
      } else {
        _config = _config.copyWith(volume: _volume);
        unawaited(PlayerPreferences.update(_config));
      }
    }
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _hud.value = null;
    });
  }

  void _onLongPressStart() {
    _speedBeforeLongPress = _speed;
    unawaited(_engine?.setRate(2.0));
    _showHud(
      const GestureFeedback(HudKind.seek, '2.0x', icon: Icons.fast_forward),
    );
  }

  void _onLongPressEnd() {
    final double? restore = _speedBeforeLongPress;
    if (restore != null) unawaited(_engine?.setRate(restore));
    _speedBeforeLongPress = null;
  }

  Future<void> _loadBrightness() async {
    final double? value = await _brightnessService.read();
    if (!mounted) return;
    setState(() {
      _brightnessNative = value != null;
    });
    _brightness.value = value ?? 1.0;
  }

  Future<void> _initVolume() async {
    final VolumeState? state = await _volumeService.read();
    if (!mounted || state == null || state.fixed) return;
    setState(() {
      _systemVolume = true;
      _volume = state.ratio * 100;
    });
    unawaited(_engine?.setVolume(100));
    _volumeSub = _volumeService.changes.listen((VolumeState next) {
      _volume = next.ratio * 100;
    });
  }

  void _setVolume(double percent, {bool immediate = false}) {
    _volume = percent.clamp(0, 100);
    if (!_systemVolume) {
      unawaited(_engine?.setVolume(_volume));
      return;
    }
    _volumeWriteTimer?.cancel();
    if (immediate) {
      unawaited(_writeSystemVolume());
    } else {
      _volumeWriteTimer = Timer(const Duration(milliseconds: 40), () {
        unawaited(_writeSystemVolume());
      });
    }
  }

  Future<void> _writeSystemVolume() async {
    final VolumeState? state = await _volumeService.write(_volume / 100);
    if (!mounted) return;
    if (state == null) {
      setState(() => _systemVolume = false);
      unawaited(_engine?.setVolume(_volume));
      return;
    }
    _volume = state.ratio * 100;
  }

  Future<void> _toggleImmersive() async {
    final bool next = !_immersive;
    setState(() => _immersive = next);
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _openPlayerSettings() async {
    final RenderPolicy before = _config.renderPolicy;
    await context.push('/settings/player');
    if (!mounted) return;
    final PlayerConfig latest = PlayerPreferences.current;
    setState(() {
      _config = latest;
      _speed = latest.speed;
      _volume = latest.volume;
    });
    if (latest.renderPolicy != before) {
      await _recreateEngine(config: latest);
    }
  }

  Future<void> _copyStreamUrl() async {
    final String? url = _resolvedUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).copied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _selectQuality(QualityOption option) {
    final EpisodeRef? ep = _current;
    if (ep == null) return;
    _resolvedUrl = option.url;
    setState(() {
      _selectedQuality = option;
      _qualityIsAuto = false;
      _resolving = true;
    });
    final Duration position = _position.value;
    _engine
        ?.open(
          MediaRequest(
            url: option.url,
            headers: _resolvedHeaders,
            startAt: position > Duration.zero ? position : null,
            title: ep.title,
          ),
        )
        .then((_) {
          if (!mounted) return;
          setState(() => _resolving = false);
          _scheduleHide();
        })
        .catchError((Object e) {
          if (!mounted) return;
          setState(() {
            _resolving = false;
            _failure = PlayerFailure(
              kind: FailureKind.unknown,
              detail: e.toString(),
            );
          });
        });
  }

  Future<void> _setSpeed(double value) async {
    setState(() => _speed = value);
    await _engine?.setRate(value);
    _config = _config.copyWith(speed: value);
    await PlayerPreferences.update(_config);
  }

  // ---------- 投屏 ----------

  Future<void> _openCast() async {
    final L10n l = L10n.of(context);
    final String? url = _resolvedUrl;
    if (url == null) {
      _snack(l.castNeedUrl);
      return;
    }

    final DlnaDevice? current = _castingDevice;
    if (current != null) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext sheetContext) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.cast_connected),
            title: Text('${l.castCastingTo} ${current.friendlyName}'),
            trailing: TextButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_stopCasting());
              },
              child: Text(l.castDisconnect),
            ),
          ),
        ),
      );
      return;
    }

    final DlnaDevice? device = await showDlnaSheet(
      context,
      url: url,
      title: widget.title ?? _current?.title ?? '',
      position: _position.value,
    );
    if (device == null || !mounted) return;
    _wasPlayingBeforeCast = _playing.value;
    await _engine?.pause();
    if (!mounted) return;
    setState(() => _castingDevice = device);
    _snack('${l.castCastingTo} ${device.friendlyName}');
  }

  Future<void> _stopCasting({bool resume = true}) async {
    final DlnaDevice? device = _castingDevice;
    if (device == null) return;
    try {
      await DlnaClient(device, ref.read(httpClientProvider)).stop();
    } on Object {
      // 电视可能已经断电/退出，忽略。
    }
    if (!mounted) return;
    setState(() => _castingDevice = null);
    if (resume && _wasPlayingBeforeCast) {
      await _engine?.play();
    }
    _wasPlayingBeforeCast = false;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // ---------- 键盘 ----------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_config.keyboardShortcuts) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool shift = HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _seekBy(Duration(seconds: shift ? -30 : -5));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _seekBy(Duration(seconds: shift ? 30 : 5));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _nudgeVolume(5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _nudgeVolume(-5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      unawaited(_toggleImmersive());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_immersive) {
        unawaited(_toggleImmersive());
      } else {
        context.pop();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft) {
      _nudgeSpeed(-0.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketRight) {
      _nudgeSpeed(0.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _seekBy(Duration delta) {
    final Duration total = _duration.value;
    final Duration target = _position.value + delta;
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (total > Duration.zero && target > total ? total : target);
    _engine?.seek(clamped);
    _position.value = clamped;
    _showHud(
      GestureFeedback(
        HudKind.seek,
        '${delta.isNegative ? '-' : '+'}${formatDuration(delta.abs())}  ${formatDuration(clamped)}',
        icon: delta.isNegative ? Icons.fast_rewind : Icons.fast_forward,
      ),
    );
  }

  void _nudgeVolume(double delta) {
    _setVolume(_volume + delta);
    if (!_systemVolume) {
      _config = _config.copyWith(volume: _volume);
      unawaited(PlayerPreferences.update(_config));
    }
    _showHud(
      GestureFeedback(
        HudKind.volume,
        '${_volume.round()}%',
        icon: _volume == 0 ? Icons.volume_off : Icons.volume_up,
      ),
    );
  }

  void _nudgeSpeed(double delta) {
    const List<double> steps = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
    final int index = steps.indexWhere((double s) => s >= _speed - 0.001);
    final int next = (index < 0 ? 2 : index + (delta > 0 ? 1 : -1)).clamp(
      0,
      steps.length - 1,
    );
    unawaited(_setSpeed(steps[next]));
    _showHud(
      GestureFeedback(HudKind.seek, '${steps[next]}x', icon: Icons.speed),
    );
  }

  void _toggleMute() {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      _setVolume(0, immediate: true);
    } else {
      _setVolume(
        _volumeBeforeMute > 0 ? _volumeBeforeMute : 100,
        immediate: true,
      );
    }
    _showHud(
      GestureFeedback(
        HudKind.volume,
        '${_volume.round()}%',
        icon: _volume == 0 ? Icons.volume_off : Icons.volume_up,
      ),
    );
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _engine?.buildSurface() ?? const ColoredBox(color: Colors.black),
            if (!_brightnessNative)
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _brightness,
                    builder:
                        (BuildContext context, double value, Widget? child) {
                          return ColoredBox(
                            color: Colors.black.withValues(
                              alpha: (1 - value) * 0.65,
                            ),
                          );
                        },
                  ),
                ),
              ),
            Positioned.fill(
              child: PlayerGestureLayer(
                enabled: _config.gesturesEnabled,
                position: _position.value,
                duration: _duration.value,
                onTap: _toggleControls,
                onDoubleTap: () => unawaited(_togglePlay()),
                onSeekPreview: _onSeekPreview,
                onSeekCommit: _onSeekCommit,
                onVerticalStart: _onVerticalStart,
                onVerticalUpdate: _onVerticalUpdate,
                onVerticalEnd: _onVerticalEnd,
                onLongPressStart: _onLongPressStart,
                onLongPressEnd: _onLongPressEnd,
              ),
            ),
            if (_config.showDebugOverlay) _debugOverlay(l),
            ValueListenableBuilder<bool>(
              valueListenable: _buffering,
              builder: (BuildContext context, bool buffering, Widget? child) {
                if (!buffering || _failure != null)
                  return const SizedBox.shrink();
                return const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
            ),
            if (_failure != null) _problemPanel(l),
            ValueListenableBuilder<bool>(
              valueListenable: _playing,
              builder: (BuildContext context, bool playing, Widget? child) {
                if (playing || _failure != null || _loading) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: IconButton.filled(
                    onPressed: () => unawaited(_togglePlay()),
                    iconSize: 42,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.play_arrow),
                  ),
                );
              },
            ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: PlayerTopBar(
                        title: widget.title ?? _current?.title ?? '',
                        subtitle: _current?.title,
                        onBack: () => context.pop(),
                        qualityLabel: _selectedQuality?.label,
                        onQuality: _qualities.isEmpty
                            ? null
                            : _showQualitySheet,
                        onCast: AppFeatures.dlna ? _openCast : null,
                        casting: _castingDevice != null,
                        onMenu: (String value) {
                          if (value == 'copy') {
                            unawaited(_copyStreamUrl());
                          } else if (value == 'player-settings') {
                            unawaited(_openPlayerSettings());
                          }
                        },
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: _position,
                        builder:
                            (
                              BuildContext context,
                              Duration position,
                              Widget? child,
                            ) {
                              return ValueListenableBuilder<Duration>(
                                valueListenable: _duration,
                                builder:
                                    (
                                      BuildContext context,
                                      Duration duration,
                                      Widget? _,
                                    ) {
                                      return ValueListenableBuilder<bool>(
                                        valueListenable: _playing,
                                        builder:
                                            (
                                              BuildContext context,
                                              bool playing,
                                              Widget? __,
                                            ) {
                                              return PlayerBottomBar(
                                                position: position,
                                                duration: duration,
                                                playing: playing,
                                                speed: _speed,
                                                onSeek: (Duration target) {
                                                  _engine?.seek(target);
                                                  _position.value = target;
                                                },
                                                onTogglePlay: () =>
                                                    unawaited(_togglePlay()),
                                                onSpeed: (double value) =>
                                                    unawaited(_setSpeed(value)),
                                                onEpisodes: _episodes.length > 1
                                                    ? _showEpisodes
                                                    : null,
                                                onNext: _next == null
                                                    ? null
                                                    : () => unawaited(
                                                        _playEpisode(_next!),
                                                      ),
                                                onFullscreen: () => unawaited(
                                                  _toggleImmersive(),
                                                ),
                                              );
                                            },
                                      );
                                    },
                              );
                            },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<GestureFeedback?>(
              valueListenable: _hud,
              builder:
                  (
                    BuildContext context,
                    GestureFeedback? feedback,
                    Widget? child,
                  ) {
                    return PlayerHudOverlay(feedback: feedback);
                  },
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  Widget _debugOverlay(L10n l) {
    final int mb = _config.bufferSize ~/ (1024 * 1024);
    final String renderer = _usingHardware
        ? l.renderModeHardware
        : l.renderModeSoftware;
    return Positioned(
      left: 8,
      top: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$renderer · ${_config.lowMemory ? 'low-mem' : 'std'} · ${mb}MB',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _problemPanel(L10n l) {
    final PlayerFailure failure = _failure!;
    final (String message, IconData icon) = switch (failure.kind) {
      FailureKind.network => (l.errorNetwork, Icons.wifi_off),
      FailureKind.decode => (l.errorDecode, Icons.movie_filter_outlined),
      FailureKind.render => (l.errorRender, Icons.display_settings),
      FailureKind.expired => (l.errorExpired, Icons.link_off),
      FailureKind.unsupported => (l.errorUnsupported, Icons.extension_off),
      FailureKind.unknown => (l.errorUnknown, Icons.error_outline),
    };
    final String primary = _noEpisodes ? l.noPlayableEpisode : message;
    final bool renderIssue = failure.kind == FailureKind.render;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: const Color(0xE61A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white70, size: 34),
              const SizedBox(height: 10),
              Text(
                l.playbackFailed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                primary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (failure.detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  iconColor: Colors.white38,
                  collapsedIconColor: Colors.white38,
                  title: Text(
                    l.errorDetail,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  children: <Widget>[
                    SelectableText(
                      failure.detail,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  if (_resolvedUrl != null)
                    TextButton(
                      onPressed: () => unawaited(_retry()),
                      child: Text(l.retry),
                    ),
                  TextButton(
                    onPressed: () => unawaited(_reResolve()),
                    child: Text(l.resolveAgain),
                  ),
                  if (renderIssue && _usingHardware)
                    TextButton(
                      onPressed: () =>
                          unawaited(_switchRenderer(RenderPolicy.software)),
                      child: Text(l.switchToSoftware),
                    ),
                  TextButton(
                    onPressed: () => unawaited(_copyStreamUrl()),
                    child: Text(l.copyStreamUrl),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l.back),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEpisodes() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.6,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 80,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
              ),
              itemCount: _episodes.length,
              itemBuilder: (BuildContext context, int i) {
                final EpisodeRef ep = _episodes[i];
                final bool active = ep.index == _current?.index;
                return TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_playEpisode(ep));
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: active ? Colors.white24 : Colors.white10,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    '${ep.index}',
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showQualitySheet() {
    final L10n l = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: <Widget>[
                    Text(
                      l.qualityLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  l.qualityAuto,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: _qualityIsAuto
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  final EpisodeRef? ep = _current;
                  if (ep != null) {
                    unawaited(_playEpisode(ep, startAt: _position.value));
                  }
                },
              ),
              for (final QualityOption option in _qualities)
                ListTile(
                  title: Text(
                    option.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing:
                      !_qualityIsAuto && _selectedQuality?.url == option.url
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _selectQuality(option);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
