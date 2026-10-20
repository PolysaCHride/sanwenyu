import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/utils/text_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../domain/models/rule.dart';

/// 基于 CSS 选择器 + 正则的节点提取器。
class RuleExtractor {
  const RuleExtractor._();

  static Document parse(String text) => html_parser.parse(text);

  /// 按字段规则从节点取值。
  static String? field(
    Element? root,
    FieldRule? rule, {
    required String baseUrl,
  }) {
    if (root == null) return null;
    final active = rule ?? const FieldRule();
    Element? target = root;
    final sel = active.selector;
    if (sel != null && sel.trim().isNotEmpty) {
      target = root.querySelector(sel.trim());
    }
    if (target == null) return null;

    String? raw;
    switch (active.attr) {
      case 'text':
        raw = target.text.trim();
        break;
      case 'html':
        raw = target.innerHtml;
        break;
      default:
        raw = target.attributes[active.attr];
        break;
    }
    if (raw == null || raw.trim().isEmpty) return null;

    var value = raw.trim();
    final regex = active.regex;
    if (regex != null && regex.isNotEmpty) {
      final extracted = firstGroup(value, regex, group: active.group);
      if (extracted == null) return null;
      value = extracted;
    }
    if (value.startsWith('//') || value.startsWith('/')) {
      return resolveUrl(value, baseUrl) ?? value;
    }
    return value;
  }

  /// 解析列表：返回每项的字段映射。
  static List<Map<String, String>> list(
    Document doc,
    ListRule rule, {
    required String baseUrl,
  }) {
    final selector = rule.list.trim();
    if (selector.isEmpty) return const <Map<String, String>>[];
    final List<Element> nodes;
    try {
      nodes = doc.querySelectorAll(selector);
    } on Object {
      return const <Map<String, String>>[];
    }
    final out = <Map<String, String>>[];
    for (final node in nodes) {
      final title = field(node, rule.title, baseUrl: baseUrl);
      final url = field(node, rule.url, baseUrl: baseUrl);
      if (title == null || url == null) continue;
      out.add(<String, String>{
        'title': title,
        'url': url,
        if (rule.cover != null)
          'cover': field(node, rule.cover, baseUrl: baseUrl) ?? '',
        if (rule.remark != null)
          'remark': field(node, rule.remark, baseUrl: baseUrl) ?? '',
      });
    }
    return out;
  }

  /// 对整页文本做多组正则提取，返回首个命中。
  static String? extractStream(String content, List<String> patterns) {
    for (final p in patterns) {
      final v = firstGroup(content, p);
      if (v != null) return v;
    }
    return null;
  }
}