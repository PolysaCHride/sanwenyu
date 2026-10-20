import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../data/sync/sync_settings.dart';
import '../../data/sync/webdav_client.dart';
import '../../domain/models/sync.dart';
import '../../l10n/l10n.dart';

/// WebDAV 同步设置。
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final TextEditingController _server = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _path = TextEditingController(text: SyncSettings.defaultPath);

  bool _enabled = false;
  bool _syncSources = true;
  SyncConflictPolicy _policy = SyncConflictPolicy.newest;
  DateTime? _lastSync;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(syncServiceProvider).status.addListener(_onStatus);
  }

  @override
  void dispose() {
    ref.read(syncServiceProvider).status.removeListener(_onStatus);
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _path.dispose();
    super.dispose();
  }

  void _onStatus() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final SyncSettings settings = await SyncSettings.load();
    final DateTime? last = await SyncSettings.lastSyncAt();
    if (!mounted) return;
    setState(() {
      _server.text = settings.serverUrl;
      _username.text = settings.username;
      _password.text = settings.password;
      _path.text = settings.remotePath;
      _enabled = settings.enabled;
      _syncSources = settings.syncSources;
      _policy = settings.policy;
      _lastSync = last;
    });
  }

  SyncSettings _formSettings() {
    return SyncSettings(
      serverUrl: _server.text.trim(),
      username: _username.text,
      password: _password.text,
      remotePath: _path.text.trim().isEmpty ? SyncSettings.defaultPath : _path.text.trim(),
      enabled: _enabled,
      syncSources: _syncSources,
      policy: _policy,
    );
  }

  Future<bool> _save() async {
    final L10n l = L10n.of(context);
    final SyncSettings settings = _formSettings();
    if (settings.serverUrl.isEmpty) {
      _snack(l.syncNeedServer);
      return false;
    }
    await SyncSettings.save(settings);
    return true;
  }

  Future<void> _testConnection() async {
    final L10n l = L10n.of(context);
    final SyncSettings settings = _formSettings();
    if (settings.serverUrl.isEmpty) {
      _snack(l.syncNeedServer);
      return;
    }
    setState(() => _busy = true);
    try {
      await WebDavClient(settings).testConnection();
      if (!mounted) return;
      _snack(l.syncSuccess);
    } on Object catch (e) {
      if (!mounted) return;
      _snack('${l.syncFailed}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    final L10n l = L10n.of(context);
    if (!await _save()) return;
    setState(() => _busy = true);
    final SyncOutcome outcome = await ref.read(syncServiceProvider).syncNow(force: true);
    final DateTime? last = await SyncSettings.lastSyncAt();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastSync = last;
    });
    _snack(outcome.ok ? l.syncSuccess : '${l.syncFailed}: ${outcome.message ?? ''}');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final SyncStatus status = ref.watch(syncServiceProvider).status.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.sync),
        actions: <Widget>[
          IconButton(
            tooltip: l.save,
            onPressed: _busy
                ? null
                : () async {
                    if (await _save() && mounted) _snack(l.ruleSaved);
                  },
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _server,
                    decoration: InputDecoration(
                      labelText: l.syncServer,
                      hintText: l.syncServerHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    decoration: InputDecoration(labelText: l.syncUsername),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l.syncPassword),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _path,
                    decoration: InputDecoration(labelText: l.syncPath),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: _enabled,
                  onChanged: (bool value) => setState(() => _enabled = value),
                  title: Text(l.syncEnabled),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _syncSources,
                  onChanged: (bool value) => setState(() => _syncSources = value),
                  title: Text(l.syncSourcesToo),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l.syncConflict),
                  trailing: DropdownButton<SyncConflictPolicy>(
                    value: _policy,
                    underline: const SizedBox.shrink(),
                    onChanged: (SyncConflictPolicy? value) {
                      if (value != null) setState(() => _policy = value);
                    },
                    items: <DropdownMenuItem<SyncConflictPolicy>>[
                      DropdownMenuItem<SyncConflictPolicy>(
                        value: SyncConflictPolicy.newest,
                        child: Text(l.syncConflictNewest),
                      ),
                      DropdownMenuItem<SyncConflictPolicy>(
                        value: SyncConflictPolicy.local,
                        child: Text(l.syncConflictLocal),
                      ),
                      DropdownMenuItem<SyncConflictPolicy>(
                        value: SyncConflictPolicy.remote,
                        child: Text(l.syncConflictRemote),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    status.state == SyncState.failed ? Icons.error_outline : Icons.cloud_sync,
                    color: status.state == SyncState.failed ? scheme.error : scheme.primary,
                  ),
                  title: Text(_statusText(l, status)),
                  subtitle: Text(
                    _lastSync == null
                        ? '${l.syncLastAt}: ${l.syncNever}'
                        : '${l.syncLastAt}: ${_formatTime(_lastSync!)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                if (status.state == SyncState.failed && status.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SelectableText(
                      status.message!,
                      style: TextStyle(fontSize: 11, color: scheme.error),
                    ),
                  ),
                const Divider(height: 1),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : _testConnection,
                        icon: const Icon(Icons.wifi_tethering, size: 18),
                        label: Text(l.syncTest),
                      ),
                    ),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _syncNow,
                        icon: _busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(l.syncNow),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l.syncPasswordWarning,
              style: TextStyle(fontSize: 12, color: scheme.outline, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(L10n l, SyncStatus status) {
    return switch (status.state) {
      SyncState.idle => l.sync,
      SyncState.syncing => l.syncRunning,
      SyncState.success => l.syncSuccess,
      SyncState.failed => l.syncFailed,
      SyncState.disabled => l.syncAutoOff,
    };
  }

  String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}
