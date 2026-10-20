import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/rule_engine/rule_source_adapter.dart';
import '../../domain/models/media.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/rule_validation.dart';
import '../../domain/models/source_config.dart';
import '../../l10n/l10n.dart';

/// 表单化的规则编辑器。
///
/// 设计目标是「不写 JSON 也能加一个源」：
/// 选择器、属性、正则都用表单编辑，底部提供真实站点的即时测试。
class RuleEditorPage extends ConsumerStatefulWidget {
  const RuleEditorPage({this.sourceId, this.initialRule, super.key});

  /// 编辑已有规则源时传入。
  final String? sourceId;

  /// 以某个规则为模板新建时传入。
  final SiteRule? initialRule;

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  late final SiteRule _initial = _resolveInitial();

  late final TextEditingController _name;
  late final TextEditingController _id;
  late final TextEditingController _baseUrl;
  late final TextEditingController _searchUrl;
  late final TextEditingController _searchBody;
  late final TextEditingController _searchList;
  late final TextEditingController _episodeList;
  late final TextEditingController _patterns;
  late final TextEditingController _referer;
  late final TextEditingController _headers;

  late FieldRule _searchTitle;
  late FieldRule _searchUrlField;
  late FieldRule? _searchCover;
  late FieldRule? _searchRemark;
  late FieldRule _detailTitle;
  late FieldRule? _detailSynopsis;
  late FieldRule? _detailCover;
  late FieldRule? _detailYear;
  late FieldRule? _detailRating;
  late FieldRule _episodeTitle;
  late FieldRule _episodeUrl;
  late String _method;
  late String _playMode;

  final TextEditingController _keyword = TextEditingController();
  bool _busy = false;
  String? _testError;
  List<SearchHit> _hits = const <SearchHit>[];
  SeriesDetail? _detailPreview;

  @override
  void initState() {
    super.initState();
    final SiteRule rule = _initial;
    _name = TextEditingController(text: rule.name);
    _id = TextEditingController(text: rule.id);
    _baseUrl = TextEditingController(text: rule.baseUrl);
    _searchUrl = TextEditingController(text: rule.search.url);
    _searchBody = TextEditingController(text: rule.search.body ?? '');
    _searchList = TextEditingController(text: rule.search.list.list);
    _episodeList = TextEditingController(text: rule.detail.episodes.list);
    _patterns = TextEditingController(text: rule.play.extract.join('\n'));
    _referer = TextEditingController(text: rule.play.referer ?? '');
    _headers = TextEditingController(text: _formatHeaders(rule.headers));
    _searchTitle = rule.search.list.title;
    _searchUrlField = rule.search.list.url;
    _searchCover = rule.search.list.cover;
    _searchRemark = rule.search.list.remark;
    _detailTitle = rule.detail.title;
    _detailSynopsis = rule.detail.synopsis;
    _detailCover = rule.detail.cover;
    _detailYear = rule.detail.year;
    _detailRating = rule.detail.rating;
    _episodeTitle = rule.detail.episodes.title;
    _episodeUrl = rule.detail.episodes.url;
    _method = rule.search.method;
    _playMode = rule.play.mode;
  }

  SiteRule _resolveInitial() {
    if (widget.initialRule != null) return widget.initialRule!;
    final String? id = widget.sourceId;
    if (id != null) {
      final repo = ref.read(sourceRepositoryProvider);
      final SourceConfig? config = repo.byId(id);
      final SiteRule? rule = config == null ? null : repo.ruleOf(config);
      if (rule != null) return rule;
    }
    return SiteRule(
      id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      baseUrl: '',
      search: const SearchRule(
        url: '/search?wd={keyword}',
        list: ListRule(
          list: '',
          title: FieldRule(),
          url: FieldRule(attr: 'href'),
        ),
      ),
      detail: const DetailRule(
        title: FieldRule(),
        episodes: ListRule(
          list: '',
          title: FieldRule(),
          url: FieldRule(attr: 'href'),
        ),
      ),
      play: const PlayRule(),
    );
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _id,
      _baseUrl,
      _searchUrl,
      _searchBody,
      _searchList,
      _episodeList,
      _patterns,
      _referer,
      _headers,
      _keyword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------- 组装与校验 ----------

  SiteRule _buildRule() {
    return SiteRule(
      id: _id.text.trim(),
      name: _name.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      headers: _parseHeaders(_headers.text),
      search: SearchRule(
        url: _searchUrl.text.trim(),
        method: _method,
        body: _method == 'POST' ? _searchBody.text : null,
        list: ListRule(
          list: _searchList.text.trim(),
          title: _searchTitle,
          url: _searchUrlField,
          cover: _optional(_searchCover),
          remark: _optional(_searchRemark),
        ),
      ),
      detail: DetailRule(
        title: _detailTitle,
        cover: _optional(_detailCover),
        synopsis: _optional(_detailSynopsis),
        year: _optional(_detailYear),
        rating: _optional(_detailRating),
        episodes: ListRule(
          list: _episodeList.text.trim(),
          title: _episodeTitle,
          url: _episodeUrl,
        ),
      ),
      play: PlayRule(
        mode: _playMode,
        extract: _patterns.text
            .split('\n')
            .map((String line) => line.trim())
            .where((String line) => line.isNotEmpty)
            .toList(),
        referer: _referer.text.trim().isEmpty ? null : _referer.text.trim(),
      ),
    );
  }

  static FieldRule? _optional(FieldRule? rule) {
    if (rule == null) return null;
    final bool emptySelector = rule.selector == null || rule.selector!.trim().isEmpty;
    final bool emptyRegex = rule.regex == null || rule.regex!.trim().isEmpty;
    return emptySelector && emptyRegex ? null : rule;
  }

  Future<void> _save() async {
    final L10n l = L10n.of(context);
    final SiteRule rule = _buildRule();
    final List<RuleIssue> issues = RuleValidator.validate(rule);
    if (issues.isNotEmpty) {
      _snack(_issueText(l, issues.first));
      return;
    }
    ref.read(sourceRepositoryProvider).saveRule(rule, existingSourceId: widget.sourceId);
    if (!mounted) return;
    _snack(l.ruleSaved);
    Navigator.of(context).pop(true);
  }

  String _issueText(L10n l, RuleIssue issue) {
    return switch (issue) {
      RuleIssue.missingId => l.ruleNeedId,
      RuleIssue.missingName => l.ruleNeedName,
      RuleIssue.invalidBaseUrl => l.ruleNeedBaseUrl,
      RuleIssue.missingSearchUrl => l.ruleNeedSearchUrl,
      RuleIssue.missingSearchList => l.ruleNeedList,
      RuleIssue.missingEpisodeList => l.ruleNeedEpisodeList,
      RuleIssue.unknownPlayMode => l.ruleNeedPlayMode,
    };
  }

  RuleSourceAdapter _draftAdapter(SiteRule rule) {
    final SourceConfig config = SourceConfig(
      id: 'draft',
      name: rule.name.isEmpty ? 'draft' : rule.name,
      baseUrl: rule.baseUrl,
      kind: SourceKind.rule,
      ruleJson: jsonEncode(rule.toJson()),
    );
    return RuleSourceAdapter(config: config, rule: rule, http: ref.read(httpClientProvider));
  }

  Future<void> _testSearch() async {
    final L10n l = L10n.of(context);
    final String keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      _snack(l.ruleTestKeyword);
      return;
    }
    final SiteRule rule = _buildRule();
    final List<RuleIssue> issues = RuleValidator.validate(rule);
    final List<RuleIssue> blocking = issues
        .where((RuleIssue i) => i != RuleIssue.missingEpisodeList)
        .toList();
    if (blocking.isNotEmpty) {
      _snack(_issueText(l, blocking.first));
      return;
    }
    setState(() {
      _busy = true;
      _testError = null;
      _hits = const <SearchHit>[];
      _detailPreview = null;
    });
    try {
      final List<SearchHit> hits = await _draftAdapter(rule).search(keyword);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _busy = false;
        if (hits.isEmpty) _testError = l.ruleTestEmpty;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _testError = e.toString();
      });
    }
  }

  Future<void> _testDetail() async {
    final L10n l = L10n.of(context);
    if (_hits.isEmpty) {
      _snack(l.ruleTestEmpty);
      return;
    }
    setState(() {
      _busy = true;
      _testError = null;
      _detailPreview = null;
    });
    try {
      final SeriesDetail detail = await _draftAdapter(_buildRule()).detail(_hits.first.sourceKey);
      if (!mounted) return;
      setState(() {
        _detailPreview = detail;
        _busy = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _testError = e.toString();
      });
    }
  }

  // ---------- 交互辅助 ----------

  Future<FieldRule?> _editField(String title, FieldRule current) async {
    final L10n l = L10n.of(context);
    final TextEditingController selector =
        TextEditingController(text: current.selector ?? '');
    final TextEditingController attr = TextEditingController(text: current.attr);
    final TextEditingController regex = TextEditingController(text: current.regex ?? '');
    final TextEditingController group = TextEditingController(text: '${current.group}');

    final FieldRule? result = await showDialog<FieldRule>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: selector,
                  decoration: InputDecoration(
                    labelText: l.ruleSelector,
                    hintText: '.item h4 a',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: attr,
                  decoration: InputDecoration(
                    labelText: l.ruleAttr,
                    hintText: 'text / html / href / src / style',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regex,
                  decoration: InputDecoration(
                    labelText: l.ruleRegex,
                    hintText: r'url\(([^)]+)\)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: group,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.ruleRegexGroup),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  FieldRule(
                    selector: selector.text.trim().isEmpty ? null : selector.text.trim(),
                    attr: attr.text.trim().isEmpty ? 'text' : attr.text.trim(),
                    regex: regex.text.trim().isEmpty ? null : regex.text.trim(),
                    group: int.tryParse(group.text.trim()) ?? 1,
                  ),
                );
              },
              child: Text(l.ok),
            ),
          ],
        );
      },
    );

    selector.dispose();
    attr.dispose();
    regex.dispose();
    group.dispose();
    return result;
  }

  Future<void> _importJson() async {
    final L10n l = L10n.of(context);
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.ruleImportFromJson),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.ruleImportHint,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(hintText: '{ "id": ... }'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.import),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final SiteRule rule = SiteRule.fromJson(
          jsonDecode(controller.text) as Map<String, dynamic>,
        );
        _applyRule(rule);
      } on Object catch (e) {
        _snack('${l.import} ${l.test}: $e');
      }
    }
    controller.dispose();
  }

  void _applyRule(SiteRule rule) {
    setState(() {
      _name.text = rule.name;
      _id.text = rule.id;
      _baseUrl.text = rule.baseUrl;
      _searchUrl.text = rule.search.url;
      _searchBody.text = rule.search.body ?? '';
      _searchList.text = rule.search.list.list;
      _episodeList.text = rule.detail.episodes.list;
      _patterns.text = rule.play.extract.join('\n');
      _referer.text = rule.play.referer ?? '';
      _headers.text = _formatHeaders(rule.headers);
      _searchTitle = rule.search.list.title;
      _searchUrlField = rule.search.list.url;
      _searchCover = rule.search.list.cover;
      _searchRemark = rule.search.list.remark;
      _detailTitle = rule.detail.title;
      _detailSynopsis = rule.detail.synopsis;
      _detailCover = rule.detail.cover;
      _detailYear = rule.detail.year;
      _detailRating = rule.detail.rating;
      _episodeTitle = rule.detail.episodes.title;
      _episodeUrl = rule.detail.episodes.url;
      _method = rule.search.method;
      _playMode = rule.play.mode;
    });
  }

  Future<void> _exportJson() async {
    final String json = const JsonEncoder.withIndent('  ').convert(_buildRule().toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _snack(L10n.of(context).copied);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
  }

  static Map<String, String> _parseHeaders(String text) {
    final Map<String, String> result = <String, String>{};
    for (final String line in text.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final int index = trimmed.indexOf(':');
      if (index <= 0) continue;
      result[trimmed.substring(0, index).trim()] = trimmed.substring(index + 1).trim();
    }
    return result;
  }

  static String _formatHeaders(Map<String, String> headers) {
    return headers.entries.map((MapEntry<String, String> e) => '${e.key}: ${e.value}').join('\n');
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sourceId == null ? l.newRule : l.editRule),
        actions: <Widget>[
          IconButton(
            tooltip: l.ruleImportFromJson,
            onPressed: _busy ? null : _importJson,
            icon: const Icon(Icons.data_object),
          ),
          IconButton(
            tooltip: l.exportJson,
            onPressed: _busy ? null : _exportJson,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: l.save,
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: <Widget>[
              _section(l.ruleBasic),
              _card(<Widget>[
                _tf(_name, l.ruleName),
                const SizedBox(height: 12),
                _tf(_id, l.ruleId),
                const SizedBox(height: 12),
                _tf(_baseUrl, l.ruleBaseUrl, hint: 'https://example.com'),
              ]),
              _section(l.ruleSearch),
              _card(<Widget>[
                _tf(_searchUrl, l.ruleSearchUrl, hint: '/search?wd={keyword}&page={page}'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'GET', label: Text('GET')),
                      ButtonSegment<String>(value: 'POST', label: Text('POST')),
                    ],
                    selected: <String>{_method},
                    onSelectionChanged: (Set<String> value) {
                      setState(() => _method = value.first);
                    },
                  ),
                ),
                if (_method == 'POST') ...<Widget>[
                  const SizedBox(height: 12),
                  _tf(_searchBody, l.rulePostBody, hint: 'wd={keyword}'),
                ],
                const SizedBox(height: 12),
                _tf(_searchList, l.ruleListSelector, hint: '.myui-vodlist__box'),
                const SizedBox(height: 4),
                _fieldTile(l.ruleTitleSelector, _searchTitle, (FieldRule v) {
                  setState(() => _searchTitle = v);
                }),
                _fieldTile(l.ruleUrlSelector, _searchUrlField, (FieldRule v) {
                  setState(() => _searchUrlField = v);
                }),
                _fieldTile(l.ruleCoverSelector, _searchCover, (FieldRule v) {
                  setState(() => _searchCover = v);
                }),
                _fieldTile(l.ruleRemarkSelector, _searchRemark, (FieldRule v) {
                  setState(() => _searchRemark = v);
                }),
              ]),
              _section(l.ruleDetail),
              _card(<Widget>[
                _fieldTile(l.ruleDetailTitle, _detailTitle, (FieldRule v) {
                  setState(() => _detailTitle = v);
                }),
                _fieldTile(l.synopsis, _detailSynopsis, (FieldRule v) {
                  setState(() => _detailSynopsis = v);
                }),
                _fieldTile(l.ruleCoverSelector, _detailCover, (FieldRule v) {
                  setState(() => _detailCover = v);
                }),
                _fieldTile(l.ruleDetailYear, _detailYear, (FieldRule v) {
                  setState(() => _detailYear = v);
                }),
                _fieldTile(l.rating, _detailRating, (FieldRule v) {
                  setState(() => _detailRating = v);
                }),
                const SizedBox(height: 12),
                _tf(_episodeList, l.ruleEpisodeList, hint: '.playlist a'),
                const SizedBox(height: 4),
                _fieldTile(l.ruleTitleSelector, _episodeTitle, (FieldRule v) {
                  setState(() => _episodeTitle = v);
                }),
                _fieldTile(l.ruleUrlSelector, _episodeUrl, (FieldRule v) {
                  setState(() => _episodeUrl = v);
                }),
              ]),
              _section(l.rulePlay),
              _card(<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'page', label: Text(l.rulePlayModePage)),
                      ButtonSegment<String>(value: 'direct', label: Text(l.rulePlayModeDirect)),
                    ],
                    selected: <String>{_playMode},
                    onSelectionChanged: (Set<String> value) {
                      setState(() => _playMode = value.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _tf(
                  _patterns,
                  l.rulePlayPatterns,
                  hint: r'"url"\s*:\s*"(https?://[^"]+\.m3u8[^"]*)"',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                _tf(_referer, l.ruleReferer, hint: 'https://example.com/'),
              ]),
              _section(l.ruleHeaders),
              _card(<Widget>[
                _tf(
                  _headers,
                  l.ruleHeaders,
                  hint: 'Referer: https://example.com/',
                  maxLines: 3,
                ),
              ]),
              _section(l.ruleTestPreview),
              _card(<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _tf(_keyword, l.ruleTestKeyword),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _testSearch,
                      child: Text(l.ruleTestSearch),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: _busy || _hits.isEmpty ? null : _testDetail,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(l.ruleTestDetail),
                    ),
                    const Spacer(),
                    if (_busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (_testError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectableText(
                      _testError!,
                      style: TextStyle(fontSize: 11, color: scheme.error),
                    ),
                  ),
                if (_hits.isNotEmpty) ...<Widget>[
                  const Divider(),
                  for (final SearchHit hit in _hits.take(6))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        hit.sourceKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: hit.remark == null
                          ? null
                          : Text(hit.remark!, style: const TextStyle(fontSize: 10)),
                    ),
                ],
                if (_detailPreview != null) ...<Widget>[
                  const Divider(),
                  Text(
                    '${_detailPreview!.title} · ${_detailPreview!.episodes.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  for (final EpisodeRef ep in _detailPreview!.episodes.take(3))
                    Text(
                      '${ep.index}. ${ep.title} — ${ep.ref}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
                if (_hits.isEmpty && _detailPreview == null && _testError == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.ruleNoTestYet,
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ),
              ]),
            ],
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _tf(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _fieldTile(String label, FieldRule? value, ValueChanged<FieldRule> onChanged) {
    final L10n l = L10n.of(context);
    final String summary = value == null
        ? l.ruleUnset
        : <String>[
            (value.selector?.isNotEmpty ?? false) ? value.selector! : '(${l.ruleCurrentNode})',
            value.attr,
            if (value.regex != null && value.regex!.isNotEmpty) 'regex',
          ].join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 16),
      onTap: () async {
        final FieldRule? next = await _editField(
          label,
          value ?? const FieldRule(),
        );
        if (next != null) onChanged(next);
      },
    );
  }
}




