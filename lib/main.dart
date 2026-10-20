import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/locale.dart';
import 'app/providers.dart';
import 'core/logger.dart';
import 'core/network/http_client.dart';
import 'core/player/player_config.dart';
import 'core/storage/database.dart';
import 'data/builtin_rules.dart';
import 'data/repository/source_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  _installErrorHooks();

  await PlayerPreferences.load();
  await LocalePreferences.load();
  await ThemeModeNotifier.load();

  final Directory dir = await getApplicationSupportDirectory();
  final String dbPath = p.join(dir.path, 'sanwenyu.db');
  final AppDatabase db = AppDatabase.open(dbPath);

  // 首次启动导入内置规则，失败不阻塞启动。
  try {
    await BuiltinRules.seedIfEmpty(SourceRepository(db, HttpClient()));
  } on Object catch (e, stack) {
    appLogger.e('内置规则导入失败', error: e, stackTrace: stack);
  }

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SanwenyuApp(),
    ),
  );
}

/// 未捕获异常进日志缓冲，用户可以在「我的 → 运行日志」里直接复制出来。
void _installErrorHooks() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    LogBuffer.instance.add(LogRecord(
      time: DateTime.now(),
      level: Level.error,
      message: 'FlutterError: ${details.exceptionAsString()}',
      error: details.stack?.toString(),
    ));
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    LogBuffer.instance.add(LogRecord(
      time: DateTime.now(),
      level: Level.fatal,
      message: '未捕获异常: $error',
      error: stack.toString(),
    ));
    return true;
  };
  if (kDebugMode) {
    appLogger.i('应用启动（debug）');
  }
}

/// 测试与桌面调试用：使用内存数据库启动。
Future<void> mainInMemory() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await PlayerPreferences.load();
  final AppDatabase db = AppDatabase.openInMemory();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SanwenyuApp(),
    ),
  );
}

/// 暴露给测试的路径工具。
String defaultDatabaseName() => 'sanwenyu.db';

/// 避免 tree-shake。
bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

