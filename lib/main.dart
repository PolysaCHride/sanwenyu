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

/// 启动阶段状态：先出一帧，再逐步初始化，避免插件阻塞时一直停在系统闪屏。
final ValueNotifier<String> _bootStatus = ValueNotifier<String>('正在启动');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootApp());
  _installErrorHooks();

  await _step('加载设置', () async {
    await PlayerPreferences.load().timeout(const Duration(seconds: 4));
    await LocalePreferences.load().timeout(const Duration(seconds: 4));
    await ThemeModeNotifier.load().timeout(const Duration(seconds: 4));
  });

  _bootStatus.value = '打开数据库';
  Directory dir;
  try {
    dir = await getApplicationSupportDirectory().timeout(const Duration(seconds: 4));
  } on Object catch (e) {
    appLogger.w('应用目录不可用，改用缓存目录: $e');
    dir = Directory.systemTemp;
  }
  final AppDatabase db = AppDatabase.open(p.join(dir.path, 'sanwenyu.db'));

  await _step('导入内置规则', () async {
    await BuiltinRules.seedIfEmpty(SourceRepository(db, HttpClient()))
        .timeout(const Duration(seconds: 6));
  });

  _bootStatus.value = '初始化播放器';
  MediaKit.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SanwenyuApp(),
    ),
  );
}

Future<void> _step(String label, Future<void> Function() action) async {
  _bootStatus.value = label;
  try {
    await action();
  } on Object catch (e, stack) {
    appLogger.e('启动步骤失败: $label', error: e, stackTrace: stack);
  }
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

class _BootApp extends StatelessWidget {
  const _BootApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: _bootStatus,
            builder: (BuildContext context, String value, Widget? child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 18),
                  Text(value, style: const TextStyle(fontSize: 15)),
                ],
              );
            },
          ),
        ),
      ),
    );
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
