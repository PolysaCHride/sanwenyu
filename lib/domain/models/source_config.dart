/// 源的种类。
enum SourceKind {
  /// 苹果 CMS10 采集接口。
  maccms,

  /// 通用规则（JSON 描述）。
  rule,

  /// 代码级适配器。
  adapter,
}

/// 一个可用的视频源配置。
class SourceConfig {
  const SourceConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.kind,
    this.ruleJson,
    this.enabled = true,
    this.priority = 0,
  });

  final String id;
  final String name;
  final String baseUrl;
  final SourceKind kind;

  /// 规则源的 JSON 文本；适配器源为 null。
  final String? ruleJson;

  final bool enabled;

  /// 数值越小越靠前。
  final int priority;

  SourceConfig copyWith({
    String? name,
    String? baseUrl,
    SourceKind? kind,
    String? ruleJson,
    bool? enabled,
    int? priority,
  }) {
    return SourceConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      kind: kind ?? this.kind,
      ruleJson: ruleJson ?? this.ruleJson,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'kind': kind.name,
        'ruleJson': ruleJson,
        'enabled': enabled,
        'priority': priority,
      };

  factory SourceConfig.fromJson(Map<String, dynamic> json) {
    return SourceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String? ?? '',
      kind: SourceKind.values.firstWhere(
        (SourceKind k) => k.name == json['kind'],
        orElse: () => SourceKind.rule,
      ),
      ruleJson: json['ruleJson'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
    );
  }
}