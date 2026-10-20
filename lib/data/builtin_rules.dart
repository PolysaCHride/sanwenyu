import 'package:flutter/services.dart' show rootBundle;

import 'repository/source_repository.dart';

/// 首次启动时导入随包分发的规则。
class BuiltinRules {
  const BuiltinRules._();

  /// 规则文件（assets/rules 下）。
  static const List<String> files = <String>[
    'hanju_co.json',
    'duboku.json',
    'ikanbot.json',
    'cms_demo.json',
  ];

  /// 数据库为空时才导入，避免覆盖用户改动。
  static Future<int> seedIfEmpty(SourceRepository repo) async {
    if (!repo.isEmpty()) return 0;
    var count = 0;
    for (final f in files) {
      try {
        final text = await rootBundle.loadString('assets/rules/$f');
        repo.importRuleJson(text, priority: 100);
        count++;
      } on Object {
        // 单个规则损坏不影响其它规则导入。
        continue;
      }
    }
    return count;
  }
}