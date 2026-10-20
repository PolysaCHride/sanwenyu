import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/style.dart';
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
        _hasMore &&
        !_loading &&
        _error == null) {
      _loadMore();
    }
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
    setState(() {
      _adapter = adapter;
      _categories = adapter.categories.isEmpty
          ? <Category>[Category(id: '', name: l.latestUpdates)]
          : adapter.categories
              .map((Category c) => Category(id: c.id, name: l.categoryName(c.id, c.name)))
              .toList();
      _category = _categories.first.id;
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
        _items = <SearchHit>[..._items, ...list];
        _loadingMore = false;
        _hasMore = list.isNotEmpty;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _selectCategory(String id) {
    if (id == _category) return;
    setState(() => _category = id);
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
              const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 3)),
            ..._body(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_scroll.hasClients) {
            _scroll.animateTo(0,
                duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
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
            final double t = (1 -
                    ((constraints.maxHeight - kToolbarHeight) /
                            (maxExtent - kToolbarHeight))
                        .clamp(0.0, 1.0))
                .toDouble();
            final double fontSize = 28 + (20 - 28) * t;
            final FontWeight weight = t < 0.5 ? FontWeight.w700 : FontWeight.w500;
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 60),
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
                          categories.firstWhere(
                            (Category c) => c.id == _category,
                            orElse: () => categories.first,
                          ).name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: weight,
                            fontSize: fontSize,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down,
                            size: fontSize, color: theme.iconTheme.color),
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
      return const <Widget>[
        SliverFillRemaining(child: LoadingView()),
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
            title: noBrowser ? l.noBrowseTitle : l.noContentTitle,
            description: noBrowser ? l.noBrowseDesc : l.noContentDesc,
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
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int i) {
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
            },
            childCount: _items.length,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
    ];
  }
}

