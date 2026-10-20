import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/metadata/tmdb_settings.dart';
import '../../data/repository/library_repository.dart';
import '../../domain/models/credits.dart';
import '../../domain/models/source_config.dart';

import '../../app/providers.dart';
import '../../domain/models/media.dart';
import '../../l10n/l10n.dart';
import '../widgets/state_views.dart';
import 'widgets/cast_section.dart';

/// 剧集详情与选集。
class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({
    required this.sourceId,
    required this.sourceKey,
    this.fallbackTitle,
    super.key,
  });

  final String sourceId;
  final String sourceKey;
  final String? fallbackTitle;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  SeriesDetail? _detail;
  SeriesCredits? _credits;
  bool _loading = true;
  String? _error;
  bool _favorite = false;

  String get _seriesId => LibraryRepository.seriesIdOf(widget.sourceId, widget.sourceKey);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(sourceRepositoryProvider);
      final SourceConfig? config =
          repo.all().where((SourceConfig s) => s.id == widget.sourceId).firstOrNull;
      if (config == null) {
        throw StateError('source not found: ${widget.sourceId}');
      }
      final adapter = repo.adapterFor(config);
      if (adapter == null) {
        throw StateError('adapter unavailable');
      }
      final detail = await adapter.detail(widget.sourceKey);
      ref.read(libraryRepositoryProvider).upsertSeries(detail);
      final fav = ref.read(libraryRepositoryProvider).isFavorite(_seriesId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _favorite = fav;
        _loading = false;
      });
      unawaited(_loadCredits(detail));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 演职员是「有则更好」的数据：任何失败都静默跳过，不阻塞详情页。
  Future<void> _loadCredits(SeriesDetail detail) async {
    try {
      final TmdbSettings settings = await TmdbSettings.load();
      if (!settings.enabled) return;
      final SeriesCredits? credits = await ref.read(creditsRepositoryProvider).forSeries(
            seriesId: _seriesId,
            title: detail.title,
            year: detail.year,
            settings: settings,
          );
      if (!mounted || credits == null) return;
      setState(() => _credits = credits);
    } on Object {
      // 无 Key、失效、网络问题都不影响主流程。
    }
  }

  void _toggleFavorite() {
    final lib = ref.read(libraryRepositoryProvider);
    if (_favorite) {
      lib.removeFavorite(_seriesId);
    } else {
      lib.addFavorite(_seriesId);
    }
    setState(() => _favorite = !_favorite);
  }

  void _play(EpisodeRef ep) {
    final d = _detail;
    if (d == null) return;
    context.push(
      '/player?seriesId=${Uri.encodeComponent(_seriesId)}'
      '&ep=${ep.index}'
      '&sourceId=${Uri.encodeComponent(widget.sourceId)}'
      '&key=${Uri.encodeComponent(widget.sourceKey)}'
      '&title=${Uri.encodeComponent(d.title)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _body(),
    );
  }

  Widget _body() {
    final L10n l = L10n.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fallbackTitle ?? l.detailTitle)),
        body: const LoadingView(),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fallbackTitle ?? l.detailTitle)),
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    final d = _detail!;
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          actions: <Widget>[
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border),
              tooltip: _favorite ? l.removeFavorite : l.addFavorite,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (d.cover != null)
                  CachedNetworkImage(imageUrl: d.cover!, fit: BoxFit.cover)
                else
                  ColoredBox(color: scheme.surfaceContainerHigh),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  d.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  <String>[
                    if (d.year != null) '${d.year}',
                    if (d.tags.isNotEmpty) d.tags.take(3).join(' / '),
                    l.episodeCountLabel(d.episodes.length),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
                if (d.rating != null && d.rating! > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.star_rounded, size: 16, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '${l.rating} ${d.rating!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (d.synopsis != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    d.synopsis!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
                if (_credits != null && !_credits!.isEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  CastSection(credits: _credits!),
                ],
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Text(l.episodes, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (d.episodes.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _play(d.episodes.first),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l.startFromFirst),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 84,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int i) {
                final ep = d.episodes[i];
                return OutlinedButton(
                  onPressed: () => _play(ep),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(
                    ep.title.length > 8 ? '${ep.index}' : ep.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
              childCount: d.episodes.length,
            ),
          ),
        ),
      ],
    );
  }
}

