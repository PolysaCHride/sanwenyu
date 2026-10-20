import 'package:flutter/material.dart';

/// 统一的视觉常量。
class Style {
  const Style._();

  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(10));
  static const Radius imgRadius = Radius.circular(12);

  /// 卡片封面宽高比。
  static const double coverAspect = 0.65;

  /// 首页网格列数。
  static int gridColumns(double width) {
    if (width > 900) return 6;
    if (width > 600) return 5;
    return 3;
  }

  /// 卡片总高度：封面 + 文字区。
  static double gridExtent(BuildContext context, double width, int columns) {
    final scale = MediaQuery.textScalerOf(context).scale(32.0);
    return width / columns / coverAspect + scale;
  }
}