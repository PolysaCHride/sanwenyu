import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'locale.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

/// 应用根组件。
class SanwenyuApp extends ConsumerWidget {
  const SanwenyuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final AppLocaleMode localeMode = ref.watch(localeModeProvider);
    final Locale locale = LocalePreferences.resolve(
      localeMode,
      PlatformDispatcher.instance.locale,
    );

    return _SyncBootstrap(
      child: MaterialApp.router(
        title: locale.languageCode == 'en' ? 'K-Drama' : '韩剧',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        locale: locale,
        supportedLocales: const <Locale>[LocalePreferences.zh, LocalePreferences.en],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          L10nDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: appRouter,
      ),
    );
  }
}

/// 启动后拉起同步服务（读取配置失败不影响界面）。
class _SyncBootstrap extends ConsumerStatefulWidget {
  const _SyncBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncBootstrap> createState() => _SyncBootstrapState();
}

class _SyncBootstrapState extends ConsumerState<_SyncBootstrap> {
  @override
  void initState() {
    super.initState();
    ref.read(syncServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
