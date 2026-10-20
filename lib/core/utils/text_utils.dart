/// 文本归一化与相似度工具。
library;

final RegExp _brackets = RegExp(r'[\(（\[【][^\)）\]】]*[\)）\]】]');
final RegExp _season = RegExp(
  r'(第\s*[0-9一二三四五六七八九十]+\s*季|Season\s*\d+)',
  caseSensitive: false,
);
final RegExp _punct = RegExp(r"""[\s\-_:：·,，.。!！?？"“”'’、/|]""");
final RegExp _nonWord = RegExp(r'[^\w\u4e00-\u9fa5]');

/// 归一化剧名：去括号补充、去「第N季」、去标点与空白、转小写。
String normalizeTitle(String input) {
  var s = input.trim().toLowerCase();
  s = s.replaceAll(_brackets, '');
  s = s.replaceAll(_season, '');
  s = s.replaceAll(_nonWord, '');
  return s;
}

/// 展示用简洁标题。
String cleanTitle(String input) {
  var s = input.replaceAll(_brackets, '').trim();
  s = s.replaceAll(_punct, ' ').trim();
  return s.isEmpty ? input.trim() : s;
}

/// Levenshtein 距离。
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (int i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// 0..1 相似度，基于编辑距离。
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final d = editDistance(a, b);
  final maxLen = a.length > b.length ? a.length : b.length;
  return 1 - d / maxLen;
}

/// 是否可视为同一部剧。
bool isSameSeries(String a, String b, {int? yearA, int? yearB}) {
  final na = normalizeTitle(a);
  final nb = normalizeTitle(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) {
    if (yearA != null && yearB != null && (yearA - yearB).abs() > 1)
      return false;
    return true;
  }
  if (similarity(na, nb) >= 0.86 &&
      (yearA == null || yearB == null || (yearA - yearB).abs() <= 1)) {
    return true;
  }
  return false;
}

/// 从文本中按正则取第一个分组。
String? firstGroup(String text, String pattern, {int group = 1}) {
  try {
    final m = RegExp(
      pattern,
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (m == null) return null;
    final v = m.group(group);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  } on FormatException {
    return null;
  }
}

/// 解析年份。
int? parseYear(String? text) {
  if (text == null) return null;
  final m = RegExp(r'(19|20)\d{2}').firstMatch(text);
  if (m == null) return null;
  final v = int.tryParse(m.group(0)!);
  if (v == null || v < 1950 || v > 2100) return null;
  return v;
}

/// 集号解析：支持「第3集」「EP03」「03」「3」。
int parseEpisodeIndex(String text, int fallback) {
  final patterns = <RegExp>[
    RegExp(r'第\s*(\d+)\s*[集话話期]'),
    RegExp(r'\bEP?\s*(\d+)\b', caseSensitive: false),
    RegExp(r'(\d{1,4})'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(text);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v > 0) return v;
    }
  }
  return fallback;
}
