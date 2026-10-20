import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../features/collect/collect_page.dart';
import '../features/detail/detail_page.dart';
import '../features/logs/logs_page.dart';
import '../features/my/my_page.dart';
import '../features/player/player_page.dart';
import '../features/popular/popular_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/history_page.dart';
import '../features/settings/language_page.dart';
import '../features/settings/player_settings_page.dart';
import '../features/settings/sync_settings_page.dart';
import '../features/settings/theme_settings_page.dart';
import '../features/settings/tmdb_settings_page.dart';
import '../features/sources/rule_editor_page.dart';
import '../features/sources/sources_page.dart';
import '../features/timeline/timeline_page.dart';
import '../l10n/l10n.dart';
import 'feature_flags.dart';

/// 全局路由。
final GoRouter appRouter = GoRouter(
  initialLocation: '/popular',
  redirect: (BuildContext context, GoRouterState state) {
    // WebDAV 未完成时隐藏入口，同时阻止旧链接/深链进入半成品页。
    if (!AppFeatures.webDavSync && state.uri.path == '/settings/sync') {
      return '/my';
    }
    return null;
  },
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return AppShell(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/popular',
          builder: (BuildContext context, GoRouterState state) =>
              const PopularPage(),
        ),
        GoRoute(
          path: '/timeline',
          builder: (BuildContext context, GoRouterState state) =>
              const TimelinePage(),
        ),
        GoRoute(
          path: '/collect',
          builder: (BuildContext context, GoRouterState state) =>
              const CollectPage(),
        ),
        GoRoute(
          path: '/my',
          builder: (BuildContext context, GoRouterState state) =>
              const MyPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (BuildContext c, GoRouterState s) => const SearchPage(),
    ),
    GoRoute(
      path: '/detail',
      builder: (BuildContext c, GoRouterState s) => DetailPage(
        sourceId: s.uri.queryParameters['sourceId'] ?? '',
        sourceKey: s.uri.queryParameters['key'] ?? '',
        fallbackTitle: s.uri.queryParameters['title'],
      ),
    ),
    GoRoute(
      path: '/player',
      builder: (BuildContext c, GoRouterState s) => PlayerPage(
        seriesId: s.uri.queryParameters['seriesId'] ?? '',
        episodeIndex: int.tryParse(s.uri.queryParameters['ep'] ?? '') ?? 1,
        sourceId: s.uri.queryParameters['sourceId'] ?? '',
        sourceKey: s.uri.queryParameters['key'] ?? '',
        title: s.uri.queryParameters['title'],
      ),
    ),
    GoRoute(
      path: '/sources',
      builder: (BuildContext c, GoRouterState s) => const SourcesPage(),
    ),
    GoRoute(
      path: '/sources/rule',
      builder: (BuildContext c, GoRouterState s) =>
          RuleEditorPage(sourceId: s.uri.queryParameters['sourceId']),
    ),
    GoRoute(
      path: '/settings/theme',
      builder: (BuildContext c, GoRouterState s) => const ThemeSettingsPage(),
    ),
    GoRoute(
      path: '/settings/player',
      builder: (BuildContext c, GoRouterState s) => const PlayerSettingsPage(),
    ),
    GoRoute(
      path: '/settings/history',
      builder: (BuildContext c, GoRouterState s) => const HistoryPage(),
    ),
    GoRoute(
      path: '/settings/sync',
      builder: (BuildContext c, GoRouterState s) => const SyncSettingsPage(),
    ),
    GoRoute(
      path: '/settings/metadata',
      builder: (BuildContext c, GoRouterState s) => const TmdbSettingsPage(),
    ),
    GoRoute(
      path: '/settings/logs',
      builder: (BuildContext c, GoRouterState s) => const LogsPage(),
    ),
    GoRoute(
      path: '/settings/language',
      builder: (BuildContext c, GoRouterState s) =>
          const LanguageSettingsPage(),
    ),
    GoRoute(
      path: '/settings/about',
      builder: (BuildContext c, GoRouterState s) => const AboutPage(),
    ),
  ],
);

/// 主导航外壳：竖屏底部栏，横屏侧边栏。
class AppShell extends StatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBack;

  String get location => widget.location;
  Widget get child => widget.child;

  static const List<String> _tabs = <String>[
    '/popular',
    '/timeline',
    '/collect',
    '/my',
  ];

  int get _index {
    final i = _tabs.indexWhere(
      (String t) => location == t || location.startsWith('$t/'),
    );
    return i < 0 ? 0 : i;
  }

  void _handleBack() {
    final now = DateTime.now();
    final last = _lastBack;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastBack = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).exitConfirm),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final bool portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    final List<NavigationDestination> destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.explore_outlined),
        selectedIcon: const Icon(Icons.explore),
        label: l.tabDiscover,
      ),
      NavigationDestination(
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: const Icon(Icons.calendar_month),
        label: l.tabTimeline,
      ),
      NavigationDestination(
        icon: const Icon(Icons.video_library_outlined),
        selectedIcon: const Icon(Icons.video_library),
        label: l.tabCollect,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l.tabMy,
      ),
    ];

    final List<NavigationRailDestination> railDestinations =
        <NavigationRailDestination>[
          NavigationRailDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: Text(l.tabDiscover),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: Text(l.tabTimeline),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: Text(l.tabCollect),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: Text(l.tabMy),
          ),
        ];

    final Widget shell = portrait
        ? Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (int i) => context.go(_tabs[i]),
              destinations: destinations,
            ),
          )
        : Scaffold(
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (int i) => context.go(_tabs[i]),
                  labelType: NavigationRailLabelType.all,
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_index != 0) {
          context.go(_tabs[0]);
          return;
        }
        _handleBack();
      },
      child: shell,
    );
  }
}
