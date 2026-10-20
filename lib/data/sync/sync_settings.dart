import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/sync.dart';

/// WebDAV 同步配置。
class SyncSettings {
  const SyncSettings({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.remotePath = defaultPath,
    this.enabled = false,
    this.syncSources = true,
    this.policy = SyncConflictPolicy.newest,
  });

  static const String defaultPath = '/sanwenyu/sync.json';

  static const String keyServer = 'sync.server';
  static const String keyUsername = 'sync.username';
  static const String keyPassword = 'sync.password';
  static const String keyPath = 'sync.path';
  static const String keyEnabled = 'sync.enabled';
  static const String keySources = 'sync.sources';
  static const String keyPolicy = 'sync.policy';
  static const String keyLastSync = 'sync.lastAt';

  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final bool enabled;
  final bool syncSources;
  final SyncConflictPolicy policy;

  bool get isConfigured => serverUrl.trim().isNotEmpty;

  String get fileUrl => joinUrl(serverUrl, remotePath);

  SyncSettings copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
    bool? enabled,
    bool? syncSources,
    SyncConflictPolicy? policy,
  }) {
    return SyncSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
      enabled: enabled ?? this.enabled,
      syncSources: syncSources ?? this.syncSources,
      policy: policy ?? this.policy,
    );
  }

  static Future<SyncSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return read(prefs);
  }

  static SyncSettings read(SharedPreferences prefs) {
    return SyncSettings(
      serverUrl: prefs.getString(keyServer) ?? '',
      username: prefs.getString(keyUsername) ?? '',
      password: prefs.getString(keyPassword) ?? '',
      remotePath: prefs.getString(keyPath) ?? defaultPath,
      enabled: prefs.getBool(keyEnabled) ?? false,
      syncSources: prefs.getBool(keySources) ?? true,
      policy: SyncConflictPolicy.fromStorage(prefs.getString(keyPolicy)),
    );
  }

  static Future<void> save(SyncSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyServer, settings.serverUrl.trim());
    await prefs.setString(keyUsername, settings.username);
    await prefs.setString(keyPassword, settings.password);
    await prefs.setString(keyPath, settings.remotePath.trim().isEmpty
        ? defaultPath
        : settings.remotePath.trim());
    await prefs.setBool(keyEnabled, settings.enabled);
    await prefs.setBool(keySources, settings.syncSources);
    await prefs.setString(keyPolicy, settings.policy.storageValue);
  }

  static Future<DateTime?> lastSyncAt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? value = prefs.getInt(keyLastSync);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  static Future<void> setLastSyncAt(DateTime time) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyLastSync, time.millisecondsSinceEpoch);
  }

  /// 拼接 base 与远端路径，保证只有一个斜杠。
  static String joinUrl(String base, String path) {
    final String left = base.trim().replaceAll(RegExp(r'/+$'), '');
    var normalized = path.trim();
    if (normalized.isEmpty) return left;
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    return '$left$normalized';
  }
}
