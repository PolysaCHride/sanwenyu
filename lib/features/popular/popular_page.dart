import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/style.dart';
import '../../data/metadata/tmdb_classifier.dart';
import '../../data/metadata/tmdb_settings.dart';
import '../../data/repository/source_repository.dart';
import '../../domain/models/media.dart';
import '../../domain/source/source_adapter.dart';
import '../../l10n/l10n.dart';
import '../widgets/catalog_card.dart';
import '../widgets/state_views.dart';

/// 发现页：按分类浏览源站最新内容。
class PopularPage extends ConsumerStatefulWidget {
  const PopularPage({super.key});

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends ConsumerState<PopularPage> {
  final ScrollController _scroll = ScrollController();

  List<SearchHit> _items = const <SearchHit>[];
  List<Category> _categories = const <Category>[];
  String _category = '';
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _koreanOnly = false;
  bool _classifying = false;
  bool _noKeyNotified = false;
  final Set<String> _koreanCategoryIds = <String>{};
  String? _error;
  SourceAdapter? _adapter;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        !_loading &&
        !_classifying &&
        _hasMore &&
        _error == null) {
      _loadMore();
    }
  }

  static bool _isKoreanName(String name) {
    return name.contains('韩剧') ||
        name.contains('韩国剧') ||
        name.contains('韩国电视剧');
  }

  SourceAdapter? _pickAdapter(List<SourceAdapter> adapters) {
    // 首页只接受能按分类浏览的源；规则源只有搜索能力，拿它当首页数据源只会得到空列表。
    for (final SourceAdapter a in adapters) {
      if (a.supportsBrowse && a.categories.isNotEmpty) return a;
    }
    for (final SourceAdapter a in adapters) {
      if (a.supportsBrowse) return a;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    final SourceRepository repo = ref.read(sourceRepositoryProvider);
    final List<SourceAdapter> adapters = repo.adapters();
    final adapter = _pickAdapter(adapters);
    if (adapter == null) {
      setState(() {
        _loading = false;
        _items = const <SearchHit>[];
      });
      return;
    }
    final L10n l = L10n.of(context);
    final List<Category> rawCategories = await adapter.loadCategories();
    final List<Category> categories = rawCategories.isEmpty
        ? <Category>[Category(id: '', name: l.latestUpdates)]
        : rawCategories;
    final Set<String> koreanIds = <String>{
      for (final Category c in categories)
        if (_isKoreanName(c.name)) c.id,
    };
    final String firstKorean = koreanIds.isEmpty ? '' : koreanIds.first;
    final List<Category> localized = categories
        .map(
          (Category c) => Category(
            id: c.id,
            name: _isKoreanName(c.name)
                ? l.koreanDramas
                : l.categoryName(c.id, c.name),
          ),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _adapter = adapter;
      _categories = localized;
      _koreanCategoryIds
        ..clear()
        ..addAll(koreanIds);
      _category = firstKorean.isNotEmpty ? firstKorean : localized.first.id;
      _koreanOnly = firstKorean.isNotEmpty;
    });
    await _reload();
  }

  Future<void> _reload() async {
    final adapter = _adapter;
    if (adapter == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final list = await adapter.browse(page: 1, category: _category);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _hasMore = list.isNotEmpty;
      });
      if (_koreanOnly) {
        await _applyKorean(list, replace: true);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    final adapter = _adapter;
    if (adapter == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final list = await adapter.browse(page: _page + 1, category: _category);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _hasMore = list.isNotEmpty;
        if (!_koreanOnly) _items = <SearchHit>[..._items, ...list];
        _loadingMore = false;
      });
      if (_koreanOnly) {
        await _applyKorean(list, replace: false);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _applyKorean(
    List<SearchHit> raw, {
    required bool replace,
  }) async {
    if (raw.isEmpty) return;
    final TmdbSettings settings = await TmdbSettings.load();
    if (!settings.enabled) {
      if (!mounted) return;
      setState(() {
        _koreanOnly = false;
        _classifying = false;
        if (!replace) _items = <SearchHit>[..._items, ...raw];
      });
      _notifyNoKey();
      return;
    }

    setState(() => _classifying = true);
    final List<ClassifiedHit> classified = await ref
        .read(tmdbClassifierProvider)
        .classify(raw);
    if (!mounted) return;

    final bool anyKnown = classified.any((ClassifiedHit c) => c.known);
    final List<SearchHit> filtered = anyKnown
        ? classified
              .where((ClassifiedHit c) => c.isKorean)
              .map((ClassifiedHit c) => c.hit)
              .toList()
        : raw;
    setState(() {
      _classifying = false;
      // 识别失败时关闭过滤开关，避免列表仍混着非韩剧却显示“过滤中”。
      if (!anyKnown) _koreanOnly = false;
      if (replace) {
        _items = filtered;
      } else {
        _items = <SearchHit>[..._items, ...filtered];
      }
    });
    if (!anyKnown) {
      _snack(L10n.of(context).tmdbClassifyFailed);
    }
  }

  void _notifyNoKey() {
    if (_noKeyNotified || !mounted) return;
    _noKeyNotified = true;
    _snack(L10n.of(context).tmdbNoKey);
  }

  void _toggleKorean() {
    setState(() => _koreanOnly = !_koreanOnly);
    _reload();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectCategory(String id) {
    if (id == _category) return;
    setState(() {
      _category = id;
      _koreanOnly = _koreanCategoryIds.contains(id);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          slivers: <Widget>[
            _appBar(context),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_classifying)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const LinearProgressIndicator(minHeight: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Text(
                        L10n.of(context).tmdbClassifying,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ..._body(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            );
          }
        },
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    final theme = Theme.of(context);
    final L10n l = L10n.of(context);
    final List<Category> categories = _categories.isEmpty
        ? <Category>[Category(id: '', name: l.latestUpdates)]
        : _categories;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 120,
      titleSpacing: 0,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      actions: <Widget>[
        IconButton(
          tooltip: l.koreanOnly,
          onPressed: _toggleKorean,
          icon: Icon(
            _koreanOnly ? Icons.filter_alt : Icons.filter_alt_off,
            color: _koreanOnly ? theme.colorScheme.primary : null,
          ),
        ),
        IconButton(
          tooltip: l.search,
          onPressed: () => context.push('/search'),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: l.history,
          onPressed: () => context.push('/settings/history'),
          icon: const Icon(Icons.history),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double maxExtent = 120;
            final double t =
                (1 -
                        ((constraints.maxHeight - kToolbarHeight) /
                                (maxExtent - kToolbarHeight))
                            .clamp(0.0, 1.0))
                    .toDouble();
            final double fontSize = 28 + (20 - 28) * t;
            final FontWeight weight = t < 0.5
                ? FontWeight.w700
                : FontWeight.w500;
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 8,
                  bottom: 8,
                  right: 60,
                ),
                child: SizedBox(
                  height: 44,
                  child: PopupMenuButton<String>(
                    tooltip: l.chooseCategory,
                    initialValue: _category,
                    onSelected: _selectCategory,
                    itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
                      for (final cat in categories)
                        PopupMenuItem<String>(
                          value: cat.id,
                          child: Text(cat.name),
                        ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          categories
                              .firstWhere(
                                (Category c) => c.id == _category,
                                orElse: () => categories.first,
                              )
                              .name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: weight,
                            fontSize: fontSize,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: fontSize,
                          color: theme.iconTheme.color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final L10n l = L10n.of(context);
    if (_loading) {
      return const <Widget>[SliverFillRemaining(child: LoadingView())];
    }
    if (_classifying && _items.isEmpty) {
      return <Widget>[
        SliverFillRemaining(child: LoadingView(message: l.tmdbClassifying)),
      ];
    }
    if (_error != null) {
      return <Widget>[
        SliverFillRemaining(
          child: ErrorView(message: _error!, onRetry: _reload),
        ),
      ];
    }
    if (_items.isEmpty) {
      final bool noBrowser = _adapter == null;
      return <Widget>[
        SliverFillRemaining(
          child: EmptyView(
            icon: noBrowser ? Icons.travel_explore : Icons.live_tv_outlined,
            title: noBrowser
                ? l.noBrowseTitle
                : (_koreanOnly ? l.tmdbNoKorean : l.noContentTitle),
            description: noBrowser
                ? l.noBrowseDesc
                : (_koreanOnly ? l.tmdbNoKoreanDesc : l.noContentDesc),
            action: Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: () => context.push('/search'),
                  child: Text(l.goSearch),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/sources'),
                  child: Text(l.sources),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final int columns = Style.gridColumns(MediaQuery.sizeOf(context).width);
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.all(Style.cardSpace),
        sliver: SliverGrid(
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
          delegate: SliverChildBuilderDelegate((BuildContext context, int i) {
            final item = _items[i];
            return CatalogCard(
              title: item.title,
              cover: item.cover,
              badge: item.remark,
              onTap: () => context.push(
                '/detail?sourceId=${Uri.encodeComponent(item.sourceId)}'
                '&key=${Uri.encodeComponent(item.sourceKey)}'
                '&title=${Uri.encodeComponent(item.title)}',
              ),
            );
          }, childCount: _items.length),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
    ];
  }
}
