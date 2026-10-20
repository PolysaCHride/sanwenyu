import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/library.dart';
import '../../l10n/l10n.dart';
import '../widgets/state_views.dart';

/// 观看历史。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  List<LibraryEntry> _items = const <LibraryEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!mounted) return;
    setState(() => _items = ref.read(libraryRepositoryProvider).history());
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.history)),
      body: _items.isEmpty
          ? EmptyView(
              icon: Icons.history,
              title: l.historyEmptyTitle,
              description: l.historyEmptyDesc,
            )
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (BuildContext context, int i) {
                final LibraryEntry entry = _items[i];
                return ListTile(
                  title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    <String>[
                      if (entry.episodeTitle != null) entry.episodeTitle!,
                      '${(entry.progressRatio * 100).round()}%',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: () => context.push(
                    '/player?seriesId=${Uri.encodeComponent(entry.seriesId)}'
                    '&ep=1&sourceId=${Uri.encodeComponent(entry.sourceId)}'
                    '&key=${Uri.encodeComponent(entry.sourceKey)}'
                    '&title=${Uri.encodeComponent(entry.title)}',
                  ),
                );
              },
            ),
    );
  }
}
