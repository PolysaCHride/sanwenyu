import '../models/media.dart';
import '../models/source_config.dart';

/// 所有视频源的统一接口。
abstract class SourceAdapter {
  SourceConfig get config;

  String get id => config.id;
  String get name => config.name;

  /// 关键词搜索。
  Future<List<SearchHit>> search(String keyword, {int page = 1});

  /// 详情与选集。
  Future<SeriesDetail> detail(String sourceKey);

  /// 解析某集的可播放地址。
  Future<PlayInfo> resolve(EpisodeRef ref, {String? detailUrl});

  /// 浏览最新内容（首页用）。默认不支持。
  Future<List<SearchHit>> browse({int page = 1, String? category}) async =>
      const <SearchHit>[];

  /// 是否支持按分类浏览。规则源只有搜索能力，首页不应拿它当数据源。
  bool get supportsBrowse => false;

  /// 该源支持的内容分类（首页筛选）。默认空。
  List<Category> get categories => const <Category>[];
}

/// 分类项。
class Category {
  const Category({required this.id, required this.name});

  /// 源内的分类标识（CMS 的 type id），空表示全部。
  final String id;
  final String name;
}