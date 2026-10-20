import 'rule.dart';

/// 规则校验的问题码。
///
/// 只存码不存文案：UI 负责本地化，测试只断言「有没有这一类问题」。
enum RuleIssue {
  missingId,
  missingName,
  invalidBaseUrl,
  missingSearchUrl,
  missingSearchList,
  missingEpisodeList,
  unknownPlayMode,
}

/// 规则校验。
class RuleValidator {
  const RuleValidator._();

  static List<RuleIssue> validate(SiteRule rule) {
    final List<RuleIssue> issues = <RuleIssue>[];

    if (rule.id.trim().isEmpty) issues.add(RuleIssue.missingId);
    if (rule.name.trim().isEmpty) issues.add(RuleIssue.missingName);
    final String base = rule.baseUrl.trim();
    if (!(base.startsWith('http://') || base.startsWith('https://'))) {
      issues.add(RuleIssue.invalidBaseUrl);
    }
    if (rule.search.url.trim().isEmpty) issues.add(RuleIssue.missingSearchUrl);
    if (rule.search.list.list.trim().isEmpty) {
      issues.add(RuleIssue.missingSearchList);
    }
    if (rule.detail.episodes.list.trim().isEmpty) {
      issues.add(RuleIssue.missingEpisodeList);
    }
    if (rule.play.mode != 'page' && rule.play.mode != 'direct') {
      issues.add(RuleIssue.unknownPlayMode);
    }
    return issues;
  }
}
