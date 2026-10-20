/// 渲染后端策略。
///
/// 虚拟机、远程桌面、老显卡上 libmpv 的 EGL/D3D 面会创建失败，
/// 这时需要一条明确的降级路径，而不是留一块黑屏。
enum RenderPolicy {
  /// 先硬件，渲染失败自动降级软件。
  auto,

  /// 强制硬件加速。
  hardware,

  /// 强制软件渲染（CPU 拷贝），兼容性最好、功耗最高。
  software;

  bool get startsWithHardware => this != software;

  static RenderPolicy fromStorage(String? value) {
    return switch (value) {
      'hardware' => RenderPolicy.hardware,
      'software' => RenderPolicy.software,
      _ => RenderPolicy.auto,
    };
  }

  String get storageValue => name;
}
