import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 一条应用内日志。
class LogRecord {
  const LogRecord({
    required this.time,
    required this.level,
    required this.message,
    this.error,
  });

  final DateTime time;
  final Level level;
  final String message;
  final String? error;

  bool get isError => level == Level.error || level == Level.fatal;
  bool get isWarning => level == Level.warning || isError;
}

/// 内存环形日志。
///
/// 只保留最近 [capacity] 条：运行日志的用途是「出问题时能看」，
/// 不需要完整持久化，也不应该拖慢播放。
class LogBuffer {
  LogBuffer._();

  static final LogBuffer instance = LogBuffer._();

  static const int capacity = 400;

  final List<LogRecord> _entries = <LogRecord>[];

  /// 供页面监听的版本号。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<LogRecord> get entries => List<LogRecord>.unmodifiable(_entries);

  int get length => _entries.length;

  void add(LogRecord record) {
    _entries.add(record);
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
    revision.value++;
  }

  void clear() {
    _entries.clear();
    revision.value++;
  }

  /// 直接记录一条，供崩溃钩子使用。
  void addMessage(String message, {Level level = Level.error, Object? error}) {
    add(LogRecord(
      time: DateTime.now(),
      level: level,
      message: message,
      error: error?.toString(),
    ));
  }
}

/// 把 logger 输出接进内存缓冲。
class LogBufferOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    final String text = event.lines.join('\n').trim();
    final Object? error = event.origin.error;
    if (text.isEmpty && error == null) return;
    LogBuffer.instance.add(LogRecord(
      time: event.origin.time,
      level: event.level,
      message: text.isEmpty ? '${event.origin.message}' : text,
      error: error?.toString(),
    ));
  }
}

/// 全局日志实例。
final Logger appLogger = Logger(
  output: MultiOutput(<LogOutput>[
    ConsoleOutput(),
    LogBufferOutput(),
  ]),
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 3,
    lineLength: 100,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
