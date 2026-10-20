import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../core/app_events.dart';
import '../../core/network/http_client.dart';
import '../../core/storage/database.dart';
import '../../core/utils/url_utils.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/source_config.dart';
import '../../domain/models/sync.dart';
import '../../domain/source/source_adapter.dart';
import '../adapters/maccms_adapter.dart';
import '../rule_engine/rule_source_adapter.dart';

/// 源的持久化与适配器构造。
class SourceRepository {
  SourceRepository(this._db, this._http);

  final AppDatabase _db;
  final HttpClient _http;

  static const String _tombstoneKind = 'source';

  List<SourceConfig> all() {
    final ResultSet rs = _db.db.select(
      'SELECT * FROM sources ORDER BY priority ASC, name ASC',
    );
    return rs.map(_fromRow).toList();
  }

  List<SourceConfig> enabled() =>
      all().where((SourceConfig s) => s.enabled).toList();

  SourceConfig? byId(String id) {
    final ResultSet rs = _db.db.select(
      'SELECT * FROM sources WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rs.isEmpty) return null;
    return _fromRow(rs.first);
  }

  void upsert(SourceConfig config) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    _db.db.execute(
      '''
      INSERT INTO sources(id, name, base_url, kind, rule_json, enabled, priority, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        base_url = excluded.base_url,
        kind = excluded.kind,
        rule_json = excluded.rule_json,
        enabled = excluded.enabled,
        priority = excluded.priority,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        config.id,
        config.name,
        config.baseUrl,
        config.kind.name,
        config.ruleJson,
        config.enabled ? 1 : 0,
        config.priority,
        now,
      ],
    );
    _clearTombstone(config.id);
    AppEvents.touchSources();
  }

  void setEnabled(String id, bool enabled) {
    _db.db.execute(
      'UPDATE sources SET enabled = ?, updated_at = ? WHERE id = ?',
      <Object?>[enabled ? 1 : 0, DateTime.now().millisecondsSinceEpoch, id],
    );
    AppEvents.touchSources();
  }

  void remove(String id) {
    _db.db.execute('DELETE FROM sources WHERE id = ?', <Object?>[id]);
    _writeTombstone(id);
    AppEvents.touchSources();
  }

  bool isEmpty() {
    final ResultSet rs = _db.db.select('SELECT COUNT(*) AS c FROM sources');
    return (rs.first['c'] as int) == 0;
  }

  /// 添加 CMS10 源。
  SourceConfig addMaccms({
    required String name,
    required String baseUrl,
    int priority = 50,
  }) {
    final String cleaned = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final SourceConfig config = SourceConfig(
      id: 'maccms:${hostOf(cleaned)}',
      name: name.trim().isEmpty ? hostOf(cleaned) : name.trim(),
      baseUrl: cleaned,
      kind: SourceKind.maccms,
      priority: priority,
    );
    upsert(config);
    return config;
  }

  /// 导入规则 JSON 文本，返回生成的源配置。
  SourceConfig importRuleJson(String jsonText, {int priority = 100}) {
    final Map<String, dynamic> map = jsonDecode(jsonText) as Map<String, dynamic>;
    final SiteRule rule = SiteRule.fromJson(map);
    final SourceConfig config = SourceConfig(
      id: 'rule:${rule.id}',
      name: rule.name,
      baseUrl: rule.baseUrl,
      kind: SourceKind.rule,
      ruleJson: jsonText,
      priority: priority,
    );
    upsert(config);
    return config;
  }

  /// 解析出规则对象；规则源才有。
  SiteRule? ruleOf(SourceConfig config) {
    final String? json = config.ruleJson;
    if (json == null || json.trim().isEmpty) return null;
    try {
      return SiteRule.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// 保存规则（新建或编辑）。
  ///
  /// [existingSourceId] 用于编辑场景：规则 id 改掉后要删掉旧记录，
  /// 否则列表里会留一条打不开的孤儿源。
  SourceConfig saveRule(
    SiteRule rule, {
    String? existingSourceId,
    int priority = 100,
  }) {
    final String json = const JsonEncoder.withIndent('  ').convert(rule.toJson());
    final SourceConfig config = SourceConfig(
      id: 'rule:${rule.id.trim()}',
      name: rule.name.trim(),
      baseUrl: rule.baseUrl.trim(),
      kind: SourceKind.rule,
      ruleJson: json,
      priority: existingSourceId == null ? priority : (byId(existingSourceId)?.priority ?? priority),
    );
    upsert(config);
    if (existingSourceId != null && existingSourceId != config.id) {
      remove(existingSourceId);
    }
    return config;
  }

  SourceAdapter? adapterFor(SourceConfig config) {
    switch (config.kind) {
      case SourceKind.maccms:
        return MaccmsAdapter(config: config, http: _http);
      case SourceKind.rule:
        final String? json = config.ruleJson;
        if (json == null || json.isEmpty) return null;
        try {
          return buildRuleAdapter(config, _http);
        } on Object {
          return null;
        }
      case SourceKind.adapter:
        return null;
    }
  }

  List<SourceAdapter> adapters() {
    return enabled()
        .map(adapterFor)
        .whereType<SourceAdapter>()
        .toList();
  }

  // ---------- 同步 ----------

  List<SyncSource> exportSources() {
    final ResultSet rows = _db.db.select('SELECT * FROM sources');
    final List<SyncSource> result = rows.map((Row row) {
      return SyncSource(
        id: row['id'] as String,
        name: row['name'] as String,
        baseUrl: row['base_url'] as String,
        kind: row['kind'] as String,
        ruleJson: row['rule_json'] as String?,
        enabled: (row['enabled'] as int) == 1,
        priority: row['priority'] as int,
        updatedAt: (row['updated_at'] as int?) ?? 0,
      );
    }).toList();

    final ResultSet tombstones = _db.db.select(
      'SELECT id, deleted_at FROM tombstones WHERE kind = ?',
      <Object?>[_tombstoneKind],
    );
    for (final Row row in tombstones) {
      result.add(SyncSource(
        id: row['id'] as String,
        name: '',
        baseUrl: '',
        kind: SourceKind.rule.name,
        enabled: false,
        priority: 0,
        updatedAt: 0,
        deletedAt: row['deleted_at'] as int,
      ));
    }
    return result;
  }

  /// 把合并后的源写回本地；只覆盖更旧的记录。
  void applySources(List<SyncSource> sources) {
    for (final SyncSource source in sources) {
      if (source.isDeleted) {
        _db.db.execute(
          'DELETE FROM sources WHERE id = ? AND updated_at <= ?',
          <Object?>[source.id, source.deletedAt],
        );
        _writeTombstone(source.id, at: source.deletedAt);
        continue;
      }
      _db.db.execute(
        '''
        INSERT INTO sources(id, name, base_url, kind, rule_json, enabled, priority, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          base_url = excluded.base_url,
          kind = excluded.kind,
          rule_json = excluded.rule_json,
          enabled = excluded.enabled,
          priority = excluded.priority,
          updated_at = excluded.updated_at
        WHERE excluded.updated_at > sources.updated_at
        ''',
        <Object?>[
          source.id,
          source.name,
          source.baseUrl,
          source.kind,
          source.ruleJson,
          source.enabled ? 1 : 0,
          source.priority,
          source.updatedAt,
        ],
      );
      _clearTombstone(source.id);
    }
    AppEvents.touchSources();
  }

  void _writeTombstone(String id, {int? at}) {
    final int stamp = at ?? DateTime.now().millisecondsSinceEpoch;
    _db.db.execute(
      'INSERT INTO tombstones(kind, id, deleted_at) VALUES (?, ?, ?) '
      'ON CONFLICT(kind, id) DO UPDATE SET deleted_at = MAX(deleted_at, excluded.deleted_at)',
      <Object?>[_tombstoneKind, id, stamp],
    );
  }

  void _clearTombstone(String id) {
    _db.db.execute(
      'DELETE FROM tombstones WHERE kind = ? AND id = ?',
      <Object?>[_tombstoneKind, id],
    );
  }

  SourceConfig _fromRow(Row row) {
    return SourceConfig(
      id: row['id'] as String,
      name: row['name'] as String,
      baseUrl: row['base_url'] as String,
      kind: SourceKind.values.firstWhere(
        (SourceKind k) => k.name == row['kind'],
        orElse: () => SourceKind.rule,
      ),
      ruleJson: row['rule_json'] as String?,
      enabled: (row['enabled'] as int) == 1,
      priority: row['priority'] as int,
    );
  }
}
