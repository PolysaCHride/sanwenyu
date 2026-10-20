import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/http_client.dart';
import '../core/storage/database.dart';
import '../data/repository/library_repository.dart';
import '../data/repository/source_repository.dart';
import '../data/metadata/credits_repository.dart';
import '../data/metadata/tmdb_classifier.dart';
import '../data/search_service.dart';
import '../data/sync/sync_service.dart';
import 'locale.dart';

/// 数据库（在 main 中覆盖）。
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final Provider<HttpClient> httpClientProvider = Provider<HttpClient>(
  (Ref ref) => HttpClient(),
);

final Provider<SourceRepository> sourceRepositoryProvider =
    Provider<SourceRepository>((Ref ref) {
      return SourceRepository(
        ref.watch(databaseProvider),
        ref.watch(httpClientProvider),
      );
    });

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>((Ref ref) {
      return LibraryRepository(ref.watch(databaseProvider));
    });

final Provider<SearchService> searchServiceProvider = Provider<SearchService>(
  (Ref ref) => const SearchService(),
);

/// 演职员缓存（TMDB）。
final Provider<CreditsRepository> creditsRepositoryProvider =
    Provider<CreditsRepository>((Ref ref) {
      return CreditsRepository(
        ref.watch(databaseProvider),
        ref.watch(httpClientProvider),
      );
    });

/// 用 TMDB 判断条目是否属于韩剧（带 SQLite 缓存）。
final Provider<TmdbClassifier> tmdbClassifierProvider =
    Provider<TmdbClassifier>(
      (Ref ref) => TmdbClassifier(
        ref.watch(databaseProvider),
        ref.watch(httpClientProvider),
      ),
    );

/// 跨设备同步（WebDAV）。
final Provider<SyncService> syncServiceProvider = Provider<SyncService>((
  Ref ref,
) {
  final SyncService service = SyncService(
    library: ref.watch(libraryRepositoryProvider),
    sources: ref.watch(sourceRepositoryProvider),
    database: ref.watch(databaseProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// 主题模式。
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _key = 'app.themeMode';

  @override
  ThemeMode build() {
    // 启动时由 main 预读，避免首帧闪烁。
    return _initial;
  }

  static ThemeMode _initial = ThemeMode.system;

  static Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? value = prefs.getString(_key);
    _initial = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

/// 界面语言。
final NotifierProvider<LocaleModeNotifier, AppLocaleMode> localeModeProvider =
    NotifierProvider<LocaleModeNotifier, AppLocaleMode>(LocaleModeNotifier.new);

class LocaleModeNotifier extends Notifier<AppLocaleMode> {
  @override
  AppLocaleMode build() => LocalePreferences.mode;

  Future<void> set(AppLocaleMode value) async {
    state = value;
    await LocalePreferences.save(value);
  }
}
