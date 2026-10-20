import 'package:flutter/foundation.dart';

/// 应用内的轻量变更信号。
///
/// 仓储只负责「改了」，不关心谁在听；同步服务据此做防抖上传，
/// 页面也可以在需要时监听刷新。
class AppEvents {
  const AppEvents._();

  /// 收藏变化。
  static final ValueNotifier<int> favorites = ValueNotifier<int>(0);

  /// 播放进度变化（播放中每 5 秒一次，只在暂停/退出后才有意义）。
  static final ValueNotifier<int> progress = ValueNotifier<int>(0);

  /// 视频源变化。
  static final ValueNotifier<int> sources = ValueNotifier<int>(0);

  static void touchFavorites() => favorites.value++;
  static void touchProgress() => progress.value++;
  static void touchSources() => sources.value++;
}
