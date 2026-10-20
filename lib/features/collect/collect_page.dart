import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/style.dart';
import '../../domain/models/library.dart';
import '../../l10n/l10n.dart';
import '../widgets/catalog_card.dart';
import '../widgets/state_views.dart';

/// 追剧：收藏的剧集。
class CollectPage extends ConsumerStatefulWidget {
  const CollectPage({super.key});

  @override
  ConsumerState<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends ConsumerState<CollectPage> {
  List<FavoriteEntry> _items = const <FavoriteEntry>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    setState(() => _items = ref.read(libraryRepositoryProvider).favorites());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int columns = Style.gridColumns(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              titleSpacing: 0,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: SafeArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      L10n.of(context).tabCollect,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 28),
                    ),
                  ),
                ),
              ),
            ),
            if (_items.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  icon: Icons.video_library_outlined,
                  title: L10n.of(context).collectEmptyTitle,
                  description: L10n.of(context).collectEmptyDesc,
                ),
              )
            else
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
                      final f = _items[i];
                      return CatalogCard(
                        title: f.title.isEmpty ? L10n.of(context).unknown : f.title,
                        cover: f.cover,
                        badge: f.year?.toString(),
                        onTap: () {
                          final parts = f.seriesId.split('::');
                          if (parts.length != 2) return;
                          context.push(
                            '/detail?sourceId=${Uri.encodeComponent(parts[0])}'
                            '&key=${Uri.encodeComponent(parts[1])}'
                            '&title=${Uri.encodeComponent(f.title)}',
                          );
                        },
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}
