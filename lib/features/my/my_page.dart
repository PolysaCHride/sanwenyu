import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';

/// 我的：入口列表。
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final L10n l = L10n.of(context);
    final int favorites = ref.read(libraryRepositoryProvider).favorites().length;
    final int history = ref.read(libraryRepositoryProvider).history(limit: 999).length;
    final int sources = ref.read(sourceRepositoryProvider).all().length;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            titleSpacing: 0,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            actions: <Widget>[
              IconButton(
                tooltip: l.settings,
                onPressed: () => context.push('/settings/player'),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    l.myTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: <Widget>[
                  _stat(context, '$favorites', l.statFollowing),
                  _stat(context, '$history', l.statWatched),
                  _stat(context, '$sources', l.statSources),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              _group(context, <_Entry>[
                _Entry(Icons.dns_outlined, l.sources, l.sourcesHint, () => context.push('/sources')),
                _Entry(Icons.play_circle_outline, l.playerSettings, l.playerSettingsHint,
                    () => context.push('/settings/player')),
                _Entry(Icons.palette_outlined, l.theme, l.themeHint,
                    () => context.push('/settings/theme')),
                _Entry(Icons.translate, l.language, l.languageHint,
                    () => context.push('/settings/language')),
                _Entry(Icons.theaters_outlined, l.metadataTitle, l.metadataHint,
                    () => context.push('/settings/metadata')),
                _Entry(Icons.history, l.history, l.historyHint,
                    () => context.push('/settings/history')),
              ]),
              _group(context, <_Entry>[
                _Entry(Icons.cloud_sync_outlined, l.sync, l.syncHint,
                    () => context.push('/settings/sync')),
                _Entry(Icons.bug_report_outlined, l.logs, l.logsHint,
                    () => context.push('/settings/logs')),
                _Entry(Icons.info_outline, l.about, l.aboutHint,
                    () => context.push('/settings/about')),
              ]),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.outline)),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, List<_Entry> entries) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Card(
        color: scheme.surfaceContainerLow,
        child: Column(
          children: <Widget>[
            for (var i = 0; i < entries.length; i++) ...<Widget>[
              ListTile(
                leading: Icon(entries[i].icon, size: 22),
                title: Text(entries[i].title, style: const TextStyle(fontSize: 15)),
                subtitle: Text(
                  entries[i].subtitle,
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: entries[i].onTap,
              ),
              if (i != entries.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _Entry {
  const _Entry(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
