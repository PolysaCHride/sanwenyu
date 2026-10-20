import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// 轻量 SQLite 封装（手写 DAO，无代码生成）。
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static AppDatabase open(String filePath) {
    final dir = Directory(p.dirname(filePath));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final db = sqlite3.open(filePath);
    final instance = AppDatabase._(db);
    instance._migrate();
    return instance;
  }

  static AppDatabase openInMemory() {
    final instance = AppDatabase._(sqlite3.openInMemory());
    instance._migrate();
    return instance;
  }

  void _migrate() {
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        base_url TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL,
        rule_json TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        priority INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS series (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        title TEXT NOT NULL,
        cover TEXT,
        year INTEGER,
        synopsis TEXT,
        rating REAL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS episodes (
        id TEXT PRIMARY KEY,
        series_id TEXT NOT NULL,
        idx INTEGER NOT NULL,
        title TEXT NOT NULL,
        ref TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_episodes_series ON episodes(series_id, idx);
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS progress (
        series_id TEXT PRIMARY KEY,
        episode_id TEXT,
        position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        series_id TEXT PRIMARY KEY,
        added_at INTEGER NOT NULL,
        last_episode_id TEXT
      );
    ''');

    // 同步需要：源的版本号、删除墓碑、同步元数据。
    _ensureColumn('sources', 'updated_at', 'INTEGER NOT NULL DEFAULT 0');
    db.execute(
      "UPDATE sources SET updated_at = CAST(strftime('%s','now') AS INTEGER) * 1000 "
      'WHERE updated_at = 0',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS tombstones (
        kind TEXT NOT NULL,
        id TEXT NOT NULL,
        deleted_at INTEGER NOT NULL,
        PRIMARY KEY (kind, id)
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    // 演职员缓存（TMDB）。
    db.execute('''
      CREATE TABLE IF NOT EXISTS credits (
        series_id TEXT PRIMARY KEY,
        tmdb_id INTEGER,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    // TMDB 剧名匹配缓存：用于「韩剧」分类，负结果也缓存，避免重复请求。
    db.execute('''
      CREATE TABLE IF NOT EXISTS tmdb_titles (
        cache_key TEXT PRIMARY KEY,
        is_korean INTEGER NOT NULL,
        tmdb_id INTEGER,
        name TEXT,
        original_name TEXT,
        year INTEGER,
        origin_country TEXT,
        original_language TEXT,
        poster_path TEXT,
        overview TEXT,
        checked_at INTEGER NOT NULL
      );
    ''');
  }

  /// 给老库补列（SQLite 没有 IF NOT EXISTS 的 ADD COLUMN）。
  void _ensureColumn(String table, String column, String definition) {
    final List<Row> info = db.select('PRAGMA table_info($table)');
    final bool exists = info.any((Row row) => row['name'] == column);
    if (!exists) {
      db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  String? meta(String key) {
    final List<Row> rows = db.select(
      'SELECT value FROM sync_meta WHERE key = ? LIMIT 1',
      <Object?>[key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setMeta(String key, String value) {
    db.execute(
      'INSERT INTO sync_meta(key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      <Object?>[key, value],
    );
  }

  void close() => db.close();
}
