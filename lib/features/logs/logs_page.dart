import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../../core/logger.dart';
import '../../l10n/l10n.dart';

/// 运行日志：出问题时用户可以直接复制给开发者。
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

enum _LogFilter { all, warning, error }

class _LogsPageState extends State<LogsPage> {
  _LogFilter _filter = _LogFilter.all;

  List<LogRecord> _visible() {
    final List<LogRecord> all = LogBuffer.instance.entries.reversed.toList();
    return switch (_filter) {
      _LogFilter.all => all,
      _LogFilter.warning => all.where((LogRecord r) => r.isWarning).toList(),
      _LogFilter.error => all.where((LogRecord r) => r.isError).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.logs),
        actions: <Widget>[
          IconButton(
            tooltip: l.copyLogs,
            onPressed: _copyAll,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: l.clearLogs,
            onPressed: () => setState(LogBuffer.instance.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: LogBuffer.instance.revision,
        builder: (BuildContext context, int revision, Widget? child) {
          final List<LogRecord> records = _visible();
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: <Widget>[
                    SegmentedButton<_LogFilter>(
                      showSelectedIcon: false,
                      segments: <ButtonSegment<_LogFilter>>[
                        ButtonSegment<_LogFilter>(
                          value: _LogFilter.all,
                          label: Text(l.logLevelAll),
                        ),
                        ButtonSegment<_LogFilter>(
                          value: _LogFilter.warning,
                          label: Text(l.logLevelWarning),
                        ),
                        ButtonSegment<_LogFilter>(
                          value: _LogFilter.error,
                          label: Text(l.logLevelError),
                        ),
                      ],
                      selected: <_LogFilter>{_filter},
                      onSelectionChanged: (Set<_LogFilter> value) {
                        setState(() => _filter = value.first);
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${records.length}',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text(
                          l.logsEmpty,
                          style: TextStyle(color: scheme.outline),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          return _LogTile(record: records[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyAll() async {
    final String text = LogBuffer.instance.entries
        .map((LogRecord r) => '${_time(r.time)} [${r.level.name}] ${r.message}'
            '${r.error == null ? '' : '\n${r.error}'}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).copied)),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.record});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = switch (record.level) {
      Level.error || Level.fatal => scheme.error,
      Level.warning => Colors.orange,
      _ => scheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _time(record.time),
            style: TextStyle(
              fontSize: 11,
              color: scheme.outline,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              record.error == null
                  ? record.message
                  : '${record.message}\n${record.error}',
              style: TextStyle(fontSize: 12, height: 1.45, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _time(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
