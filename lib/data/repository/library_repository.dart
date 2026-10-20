import 'package:sqlite3/sqlite3.dart';

import '../../core/app_events.dart';
import '../../core/storage/database.dart';
import '../../domain/models/library.dart';
import '../../domain/models/media.dart';
import '../../domain/models/sync.dart';

/// 收藏、历史与剧集持久化。
class LibraryRepository {
  LibraryRepository(this._db);

  final AppDatabase _db;

  Database get _raw => _db.db;

  // ---------- 剧集缓存 ----------

  void upsertSeries(SeriesDetail detail) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _raw.execute(
      '''
      INSERT INTO series(id, source_id, source_key, title, cover, year, synopsis, rating, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        cover = excluded.cover,
        year = excluded.year,
        synopsis = excluded.synopsis,
        rating = excluded.rating,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        seriesIdOf(detail.sourceId, detail.sourceKey),
        detail.sourceId,
        detail.sourceKey,
        detail.title,
        detail.cover,
        detail.year,
        detail.synopsis,
        detail.rating,
        now,
      ],
    );
    replaceEpisodes(detail);
  }

  void replaceEpisodes(SeriesDetail detail) {
    final sid = seriesIdOf(detail.sourceId, detail.sourceKey);
    _raw.execute('DELETE FROM episodes WHERE series_id = ?', <Object?>[sid]);
    final stmt = _raw.prepare(
      'INSERT INTO episodes(id, series_id, idx, title, ref) VALUES (?, ?, ?, ?, ?)',
    );
    try {
      for (final ep in detail.episodes) {
        stmt.execute(<Object?>[
          '$sid#${ep.index}',
          sid,
          ep.index,
          ep.title,
          ep.ref,
        ]);
      }
    } finally {
      stmt.close();
    }
  }

  List<EpisodeRef> episodesOf(String seriesId) {
    final rs = _raw.select(
      'SELECT idx, title, ref FROM episodes WHERE series_id = ? ORDER BY idx ASC',
      <Object?>[seriesId],
    );
    return rs
        .map((Row row) => EpisodeRef(
              index: row['idx'] as int,
              title: row['title'] as String,
              ref: row['ref'] as String,
            ))
        .toList();
  }

  static String seriesIdOf(String sourceId, String sourceKey) =>
      '$sourceId::$sourceKey';

  // ---------- 收藏 ----------

  void addFavorite(String seriesId) {
    _raw.execute(
      'INSERT OR REPLACE INTO favorites(series_id, added_at, last_episode_id) '
      'VALUES (?, ?, (SELECT last_episode_id FROM favorites WHERE series_id = ?))',
      <Object?>[seriesId, DateTime.now().millisecondsSinceEpoch, seriesId],
    );
    _clearTombstone('favorite', seriesId);
    AppEvents.touchFavorites();
  }

  void removeFavorite(String seriesId) {
    _raw.execute('DELETE FROM favorites WHERE series_id = ?', <Object?>[seriesId]);
    _writeTombstone('favorite', seriesId);
    AppEvents.touchFavorites();
  }

  bool isFavorite(String seriesId) {
    final rs = _raw.select(
      'SELECT 1 FROM favorites WHERE series_id = ? LIMIT 1',
      <Object?>[seriesId],
    );
    return rs.isNotEmpty;
  }

  List<FavoriteEntry> favorites() {
    final rs = _raw.select('''
      SELECT f.series_id, f.added_at, s.title, s.cover, s.year
      FROM favorites f LEFT JOIN series s ON s.id = f.series_id
      ORDER BY f.added_at DESC
    ''');
    return rs
        .map((Row row) => FavoriteEntry(
              seriesId: row['series_id'] as String,
              title: (row['title'] as String?) ?? '',
              addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int),
              cover: row['cover'] as String?,
              year: row['year'] as int?,
            ))
        .toList();
  }

  // ---------- 进度 ----------

  void saveProgress({
    required String seriesId,
    required String episodeId,
    required Duration position,
    required Duration duration,
  }) {
    _raw.execute(
      '''
      INSERT INTO progress(series_id, episode_id, position_ms, duration_ms, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(series_id) DO UPDATE SET
        episode_id = excluded.episode_id,
        position_ms = excluded.position_ms,
        duration_ms = excluded.duration_ms,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        seriesId,
        episodeId,
        position.inMilliseconds,
        duration.inMilliseconds,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    _raw.execute(
      'UPDATE favorites SET last_episode_id = ? WHERE series_id = ?',
      <Object?>[episodeId, seriesId],
    );
    AppEvents.touchProgress();
  }

  Duration? progressOf(String seriesId) {
    final rs = _raw.select(
      'SELECT position_ms FROM progress WHERE series_id = ? LIMIT 1',
      <Object?>[seriesId],
    );
    if (rs.isEmpty) return null;
    return Duration(milliseconds: rs.first['position_ms'] as int);
  }

  /// 完整进度记录：续播时要判断「是不是同一集」。
  ProgressRecord? progressRecordOf(String seriesId) {
    final rs = _raw.select(
      'SELECT episode_id, position_ms, duration_ms, updated_at '
      'FROM progress WHERE series_id = ? LIMIT 1',
      <Object?>[seriesId],
    );
    if (rs.isEmpty) return null;
    final Row row = rs.first;
    return ProgressRecord(
      seriesId: seriesId,
      episodeId: (row['episode_id'] as String?) ?? '',
      position: Duration(milliseconds: row['position_ms'] as int),
      duration: Duration(milliseconds: row['duration_ms'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  List<LibraryEntry> history({int limit = 50}) {
    final rs = _raw.select('''
      SELECT p.series_id, p.position_ms, p.duration_ms, p.updated_at,
             s.title, s.cover, s.year, s.source_id, s.source_key,
             e.title AS episode_title
      FROM progress p
      LEFT JOIN series s ON s.id = p.series_id
      LEFT JOIN episodes e ON e.id = p.episode_id
      WHERE s.title IS NOT NULL
      ORDER BY p.updated_at DESC
      LIMIT ?
    ''', <Object?>[limit]);
    return rs
        .map((Row row) => LibraryEntry(
              seriesId: row['series_id'] as String,
              sourceId: (row['source_id'] as String?) ?? '',
              sourceKey: (row['source_key'] as String?) ?? '',
              title: row['title'] as String,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
              cover: row['cover'] as String?,
              year: row['year'] as int?,
              positionMs: row['position_ms'] as int?,
              durationMs: row['duration_ms'] as int?,
              episodeTitle: row['episode_title'] as String?,
            ))
        .toList();
  }

  // ---------- 同步 ----------

  List<SyncFavorite> exportFavorites() {
    final ResultSet rows = _raw.select('SELECT series_id, added_at FROM favorites');
    final List<SyncFavorite> result = rows
        .map((Row row) => SyncFavorite(
              seriesId: row['series_id'] as String,
              addedAt: row['added_at'] as int,
            ))
        .toList();
    final ResultSet tombstones = _raw.select(
      'SELECT id, deleted_at FROM tombstones WHERE kind = ?',
      <Object?>['favorite'],
    );
    for (final Row row in tombstones) {
      result.add(SyncFavorite(
        seriesId: row['id'] as String,
        addedAt: 0,
        deletedAt: row['deleted_at'] as int,
      ));
    }
    return result;
  }

  List<SyncProgress> exportProgress() {
    final ResultSet rows = _raw.select(
      'SELECT series_id, episode_id, position_ms, duration_ms, updated_at FROM progress',
    );
    final List<SyncProgress> result = rows
        .map((Row row) => SyncProgress(
              seriesId: row['series_id'] as String,
              episodeId: (row['episode_id'] as String?) ?? '',
              positionMs: row['position_ms'] as int,
              durationMs: row['duration_ms'] as int,
              updatedAt: row['updated_at'] as int,
            ))
        .toList();
    final ResultSet tombstones = _raw.select(
      'SELECT id, deleted_at FROM tombstones WHERE kind = ?',
      <Object?>['progress'],
    );
    for (final Row row in tombstones) {
      result.add(SyncProgress(
        seriesId: row['id'] as String,
        episodeId: '',
        positionMs: 0,
        durationMs: 0,
        updatedAt: 0,
        deletedAt: row['deleted_at'] as int,
      ));
    }
    return result;
  }

  List<SyncSeries> exportSeries() {
    final ResultSet rows = _raw.select(
      'SELECT id, source_id, source_key, title, cover, year, synopsis, rating, updated_at FROM series',
    );
    return rows
        .map((Row row) => SyncSeries(
              id: row['id'] as String,
              sourceId: row['source_id'] as String,
              sourceKey: row['source_key'] as String,
              title: row['title'] as String,
              cover: row['cover'] as String?,
              year: row['year'] as int?,
              synopsis: row['synopsis'] as String?,
              rating: (row['rating'] as num?)?.toDouble(),
              updatedAt: row['updated_at'] as int,
            ))
        .toList();
  }

  /// 应用合并后的收藏；墓碑只会删掉更旧的本地记录。
  void applyFavorites(List<SyncFavorite> favorites) {
    for (final SyncFavorite favorite in favorites) {
      if (favorite.isDeleted) {
        _raw.execute(
          'DELETE FROM favorites WHERE series_id = ? AND added_at <= ?',
          <Object?>[favorite.seriesId, favorite.deletedAt],
        );
        _writeTombstone('favorite', favorite.seriesId, at: favorite.deletedAt);
        continue;
      }
      _raw.execute(
        'INSERT INTO favorites(series_id, added_at) VALUES (?, ?) '
        'ON CONFLICT(series_id) DO UPDATE SET '
        'added_at = MAX(favorites.added_at, excluded.added_at)',
        <Object?>[favorite.seriesId, favorite.addedAt],
      );
      _clearTombstone('favorite', favorite.seriesId);
    }
    AppEvents.touchFavorites();
  }

  void applyProgress(List<SyncProgress> progress) {
    for (final SyncProgress entry in progress) {
      if (entry.isDeleted) {
        _raw.execute(
          'DELETE FROM progress WHERE series_id = ? AND updated_at <= ?',
          <Object?>[entry.seriesId, entry.deletedAt],
        );
        _writeTombstone('progress', entry.seriesId, at: entry.deletedAt);
        continue;
      }
      _raw.execute(
        '''
        INSERT INTO progress(series_id, episode_id, position_ms, duration_ms, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(series_id) DO UPDATE SET
          episode_id = excluded.episode_id,
          position_ms = excluded.position_ms,
          duration_ms = excluded.duration_ms,
          updated_at = excluded.updated_at
        WHERE excluded.updated_at > progress.updated_at
        ''',
        <Object?>[
          entry.seriesId,
          entry.episodeId,
          entry.positionMs,
          entry.durationMs,
          entry.updatedAt,
        ],
      );
      _clearTombstone('progress', entry.seriesId);
    }
    AppEvents.touchProgress();
  }

  void applySeries(List<SyncSeries> series) {
    for (final SyncSeries item in series) {
      _raw.execute(
        '''
        INSERT INTO series(id, source_id, source_key, title, cover, year, synopsis, rating, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          cover = excluded.cover,
          year = excluded.year,
          synopsis = excluded.synopsis,
          rating = excluded.rating,
          updated_at = excluded.updated_at
        WHERE excluded.updated_at > series.updated_at
        ''',
        <Object?>[
          item.id,
          item.sourceId,
          item.sourceKey,
          item.title,
          item.cover,
          item.year,
          item.synopsis,
          item.rating,
          item.updatedAt,
        ],
      );
    }
  }

  void _writeTombstone(String kind, String id, {int? at}) {
    final int stamp = at ?? DateTime.now().millisecondsSinceEpoch;
    _raw.execute(
      'INSERT INTO tombstones(kind, id, deleted_at) VALUES (?, ?, ?) '
      'ON CONFLICT(kind, id) DO UPDATE SET deleted_at = MAX(deleted_at, excluded.deleted_at)',
      <Object?>[kind, id, stamp],
    );
  }

  void _clearTombstone(String kind, String id) {
    _raw.execute(
      'DELETE FROM tombstones WHERE kind = ? AND id = ?',
      <Object?>[kind, id],
    );
  }
}