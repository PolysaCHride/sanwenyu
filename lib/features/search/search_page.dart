import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/style.dart';
import '../../data/metadata/tmdb_classifier.dart';
import '../../data/metadata/tmdb_settings.dart';
import '../../domain/models/media.dart';
import '../../domain/models/search_result.dart';
import '../../domain/source/source_adapter.dart';
import '../../l10n/l10n.dart';
import '../widgets/catalog_card.dart';
import '../widgets/state_views.dart';

/// 多源聚合搜索。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _searching = false;
  bool _classifying = false;
  bool _koreanOnly = false;
  String _keyword = '';
  List<AggregatedResult> _results = const <AggregatedResult>[];
  List<SourceSearchState> _states = const <SourceSearchState>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final kw = _controller.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _keyword = kw;
      _results = const <AggregatedResult>[];
      _states = const <SourceSearchState>[];
      _error = null;
    });
    try {
      final L10n l = L10n.of(context);
      final List<SourceAdapter> adapters = ref
          .read(sourceRepositoryProvider)
          .adapters();
      if (adapters.isEmpty) {
        setState(() {
          _searching = false;
          _error = l.noSourcesHint;
        });
        return;
      }
      final response = await ref
          .read(searchServiceProvider)
          .searchAll(kw, adapters);
      if (!mounted) return;
      List<AggregatedResult> results = response.results;

      if (_koreanOnly && results.isNotEmpty) {
        final TmdbSettings settings = await TmdbSettings.load();
        if (!settings.enabled) {
          if (!mounted) return;
          setState(() => _koreanOnly = false);
          _snack(L10n.of(context).tmdbNoKey);
        } else {
          setState(() => _classifying = true);
          final List<SearchHit> all = results
              .expand((AggregatedResult r) => r.hits)
              .toList(growable: false);
          final List<ClassifiedHit> classified = await ref
              .read(tmdbClassifierProvider)
              .classify(all);
          if (!mounted) return;
          final bool anyKnown = classified.any((ClassifiedHit c) => c.known);
          if (anyKnown) {
            final Set<String> koreanKeys = <String>{
              for (final ClassifiedHit c in classified)
                if (c.isKorean) '${c.hit.sourceId}|${c.hit.sourceKey}',
            };
            results = <AggregatedResult>[
              for (final AggregatedResult r in results)
                if (r.hits.any(
                  (SearchHit h) =>
                      koreanKeys.contains('${h.sourceId}|${h.sourceKey}'),
                ))
                  AggregatedResult(
                    title: r.title,
                    cover: r.cover,
                    year: r.year,
                    hits: r.hits
                        .where(
                          (SearchHit h) => koreanKeys.contains(
                            '${h.sourceId}|${h.sourceKey}',
                          ),
                        )
                        .toList(),
                  ),
            ];
          } else {
            _snack(L10n.of(context).tmdbClassifyFailed);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _searching = false;
        _classifying = false;
        _results = results;
        _states = response.states;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _classifying = false;
        _error = e.toString();
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleKorean() {
    setState(() => _koreanOnly = !_koreanOnly);
    if (_keyword.isNotEmpty) {
      _run();
    }
  }

  void _open(AggregatedResult item) {
    final L10n l = L10n.of(context);
    if (item.hits.length == 1) {
      _push(item.hits.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    l.sourceCount(item.hits.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(c).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            for (final hit in item.hits)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(hit.sourceName),
                subtitle: hit.remark == null ? null : Text(hit.remark!),
                onTap: () {
                  Navigator.pop(c);
                  _push(hit);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _push(SearchHit hit) {
    context.push(
      '/detail?sourceId=${Uri.encodeComponent(hit.sourceId)}'
      '&key=${Uri.encodeComponent(hit.sourceKey)}'
      '&title=${Uri.encodeComponent(hit.title)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int columns = Style.gridColumns(MediaQuery.sizeOf(context).width);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _run(),
          decoration: InputDecoration(
            hintText: L10n.of(context).searchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: L10n.of(context).koreanOnly,
            onPressed: _toggleKorean,
            icon: Icon(
              _koreanOnly ? Icons.filter_alt : Icons.filter_alt_off,
              color: _koreanOnly ? scheme.primary : null,
            ),
          ),
          TextButton(onPressed: _run, child: Text(L10n.of(context).search)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_states.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _states.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (BuildContext c, int i) {
                  final s = _states[i];
                  final ok = s.error == null;
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      ok ? Icons.check_circle : Icons.error_outline,
                      size: 14,
                      color: ok ? scheme.primary : scheme.error,
                    ),
                    label: Text(
                      ok
                          ? '${s.sourceName} ${s.count}'
                          : '${s.sourceName} ${L10n.of(context).sourceFailed}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          Expanded(child: _body(scheme, columns)),
        ],
      ),
    );
  }

  Widget _body(ColorScheme scheme, int columns) {
    final L10n l = L10n.of(context);
    if (_searching) {
      return LoadingView(
        message: _classifying ? l.tmdbClassifying : l.searchingSources,
      );
    }
    if (_error != null) return ErrorView(message: _error!, onRetry: _run);
    if (_results.isEmpty) {
      if (_keyword.isEmpty) {
        return EmptyView(
          icon: Icons.travel_explore,
          title: l.searchEmptyTitle,
          description: l.searchEmptyDesc,
        );
      }
      if (_koreanOnly) {
        return EmptyView(
          icon: Icons.search_off,
          title: l.tmdbNoKorean,
          description: l.tmdbNoKoreanDesc,
        );
      }
      return EmptyView(
        icon: Icons.search_off,
        title: l.noResultsTitle,
        description: l.noResultsDesc,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(Style.cardSpace),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: Style.cardSpace,
        crossAxisSpacing: Style.cardSpace,
        mainAxisExtent: Style.gridExtent(
          context,
          MediaQuery.sizeOf(context).width,
          columns,
        ),
      ),
      itemCount: _results.length,
      itemBuilder: (BuildContext c, int i) {
        final item = _results[i];
        return CatalogCard(
          title: item.title,
          cover: item.cover,
          badge: item.hits.length > 1
              ? l.sourceBadge(item.hits.length)
              : item.remark,
          enableHero: false,
          onTap: () => _open(item),
        );
      },
    );
  }
}
