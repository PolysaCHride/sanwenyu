import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/source_config.dart';
import '../../l10n/l10n.dart';
import '../widgets/state_views.dart';
import 'rule_editor_page.dart';

/// 视频源管理。
class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  List<SourceConfig> _sources = const <SourceConfig>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _sources = ref.read(sourceRepositoryProvider).all());
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.sources)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(l.addSource),
      ),
      body: _sources.isEmpty
          ? EmptyView(
              icon: Icons.dns_outlined,
              title: l.sources,
              description: l.addMaccmsHint,
              action: FilledButton.icon(
                onPressed: _showAddSheet,
                icon: const Icon(Icons.add),
                label: Text(l.add),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: _sources.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int i) {
                final SourceConfig source = _sources[i];
                return Card(
                  child: ListTile(
                    onTap: () => _edit(source),
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        source.kind == SourceKind.maccms ? Icons.cloud_outlined : Icons.rule,
                        size: 20,
                      ),
                    ),
                    title: Text(source.name),
                    subtitle: Text(
                      '${_kindLabel(l, source.kind)} · ${source.baseUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Switch(
                          value: source.enabled,
                          onChanged: (bool value) {
                            ref.read(sourceRepositoryProvider).setEnabled(source.id, value);
                            _load();
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (String value) => _onMenu(source, value),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(value: 'edit', child: Text(l.edit)),
                            if (source.kind == SourceKind.rule)
                              PopupMenuItem<String>(value: 'duplicate', child: Text(l.copy)),
                            if (source.kind == SourceKind.rule)
                              PopupMenuItem<String>(value: 'export', child: Text(l.exportJson)),
                            PopupMenuItem<String>(value: 'delete', child: Text(l.delete)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _kindLabel(L10n l, SourceKind kind) {
    return switch (kind) {
      SourceKind.maccms => l.sourceTypeMaccms,
      SourceKind.rule => l.sourceTypeRule,
      SourceKind.adapter => l.sourceTypeAdapter,
    };
  }

  Future<void> _onMenu(SourceConfig source, String action) async {
    final L10n l = L10n.of(context);
    final repo = ref.read(sourceRepositoryProvider);
    switch (action) {
      case 'edit':
        await _edit(source);
      case 'duplicate':
        final SiteRule? rule = repo.ruleOf(source);
        if (rule == null) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => RuleEditorPage(
              initialRule: rule.copyWith(
                id: '${rule.id}-copy',
                name: '${rule.name} ${l.copySuffix}',
              ),
            ),
          ),
        );
        _load();
      case 'export':
        final json = source.ruleJson;
        if (json == null) return;
        await Clipboard.setData(ClipboardData(text: json));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).copied)),
        );
      case 'delete':
        _confirmDelete(source);
    }
  }

  Future<void> _edit(SourceConfig source) async {
    if (source.kind == SourceKind.rule) {
      await context.push('/sources/rule?sourceId=${Uri.encodeComponent(source.id)}');
      _load();
      return;
    }
    await _editMaccms(source);
  }

  void _confirmDelete(SourceConfig source) {
    final L10n l = L10n.of(context);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l.deleteSourceTitle),
        content: Text(source.name),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(sourceRepositoryProvider).remove(source.id);
              Navigator.pop(dialogContext);
              _load();
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }

  void _showAddSheet() {
    final L10n l = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(l.addMaccms),
              subtitle: Text(l.addMaccmsHint),
              onTap: () {
                Navigator.pop(sheetContext);
                _addMaccms();
              },
            ),
            ListTile(
              leading: const Icon(Icons.rule),
              title: Text(l.newRule),
              subtitle: Text(l.ruleEditor),
              onTap: () {
                Navigator.pop(sheetContext);
                _openRuleEditor();
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_object),
              title: Text(l.importRuleJson),
              subtitle: Text(l.importRuleJsonHint),
              onTap: () {
                Navigator.pop(sheetContext);
                _importRule();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openRuleEditor() async {
    await context.push('/sources/rule');
    _load();
  }

  Future<void> _addMaccms() async {
    final L10n l = L10n.of(context);
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController urlCtrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l.addMaccms),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l.ruleName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.add),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final String url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    ref.read(sourceRepositoryProvider).addMaccms(name: nameCtrl.text, baseUrl: url);
    nameCtrl.dispose();
    urlCtrl.dispose();
    _load();
  }

  Future<void> _editMaccms(SourceConfig source) async {
    final L10n l = L10n.of(context);
    final TextEditingController nameCtrl = TextEditingController(text: source.name);
    final TextEditingController urlCtrl = TextEditingController(text: source.baseUrl);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l.ruleName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (ok == true) {
      final String url = urlCtrl.text.trim();
      if (url.isNotEmpty) {
        ref.read(sourceRepositoryProvider).upsert(
              SourceConfig(
                id: source.id,
                name: nameCtrl.text.trim().isEmpty ? source.name : nameCtrl.text.trim(),
                baseUrl: url.replaceAll(RegExp(r'/+$'), ''),
                kind: source.kind,
                ruleJson: source.ruleJson,
                enabled: source.enabled,
                priority: source.priority,
              ),
            );
        _load();
      }
    }
    nameCtrl.dispose();
    urlCtrl.dispose();
  }

  Future<void> _importRule() async {
    final L10n l = L10n.of(context);
    final TextEditingController ctrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l.importRuleJson),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: l.importRuleJsonHint,
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.import),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      ref.read(sourceRepositoryProvider).importRuleJson(ctrl.text.trim());
      _load();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.import}: $e')),
      );
    }
    ctrl.dispose();
  }
}
