import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 轻量本地化。
///
/// 只有中英两种语言，用「成对文案」而不是 arb 代码生成：文案就在调用点，
/// 不会出现 key 对不上、生成文件没跟上这类问题。新增字符串只需加一个 getter。
class L10n {
  const L10n(this.locale);

  final Locale locale;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n) ??
        const L10n(Locale('zh', 'CN'));
  }

  bool get isZh => locale.languageCode != 'en';

  String _v(String zh, String en) => isZh ? zh : en;

  String plural(int count, String zhUnit, String enUnit) =>
      isZh ? '$count$zhUnit' : '$count $enUnit${count == 1 ? '' : 's'}';

  // ---------- 通用 ----------
  String get appName => 'sanwenyu';
  String get ok => _v('确定', 'OK');
  String get cancel => _v('取消', 'Cancel');
  String get save => _v('保存', 'Save');
  String get delete => _v('删除', 'Delete');
  String get edit => _v('编辑', 'Edit');
  String get add => _v('添加', 'Add');
  String get retry => _v('重试', 'Retry');
  String get back => _v('返回', 'Back');
  String get close => _v('关闭', 'Close');
  String get copy => _v('复制', 'Copy');
  String get copied => _v('已复制', 'Copied');
  String get loading => _v('加载中…', 'Loading…');
  String get empty => _v('暂无内容', 'Nothing here');
  String get unknown => _v('未知', 'Unknown');
  String get test => _v('测试', 'Test');
  String get enabled => _v('已启用', 'Enabled');
  String get disabled => _v('已停用', 'Disabled');
  String get settings => _v('设置', 'Settings');
  String get comingSoon => _v('功能开发中', 'Coming soon');

  // ---------- 导航 ----------
  String get tabDiscover => _v('发现', 'Discover');
  String get tabTimeline => _v('时间表', 'Schedule');
  String get tabCollect => _v('追剧', 'Library');
  String get tabMy => _v('我的', 'Me');
  String get exitConfirm => _v('再按一次退出应用', 'Press back again to exit');

  // ---------- 播放器 ----------
  String get play => _v('播放', 'Play');
  String get pause => _v('暂停', 'Pause');
  String get replay => _v('重播', 'Replay');
  String get resume => _v('继续', 'Resume');
  String get nextEpisode => _v('下一集', 'Next');
  String get episodes => _v('选集', 'Episodes');
  String get speedLabel => _v('倍速', 'Speed');
  String get qualityLabel => _v('清晰度', 'Quality');
  String get qualityAuto => _v('自动', 'Auto');
  String get fullscreen => _v('全屏', 'Fullscreen');
  String get exitFullscreen => _v('退出全屏', 'Exit fullscreen');
  String get copyStreamUrl => _v('复制播放地址', 'Copy stream URL');
  String get switchToSoftware => _v('改用软件渲染', 'Use software rendering');
  String get switchToHardware => _v('改用硬件加速', 'Use hardware acceleration');
  String get rendererFallback => _v(
    '硬件渲染不可用，已自动切换到软件渲染',
    'Hardware rendering unavailable, switched to software',
  );
  String get brightnessUnavailable =>
      _v('当前平台不支持系统亮度调节', 'System brightness is not available here');
  String get gestureSeek => _v('快进 / 快退', 'Seek');
  String get gestureVolume => _v('音量', 'Volume');
  String get gestureBrightness => _v('亮度', 'Brightness');
  String get playingAt => _v('播放中', 'Now playing');
  String get playbackFailed => _v('播放失败', 'Playback failed');
  String get renderModeHardware => _v('硬件渲染', 'Hardware');
  String get renderModeSoftware => _v('软件渲染', 'Software');
  String get bufferLabel => _v('缓存', 'Buffer');
  String get lowMemoryOn => _v('低内存', 'Low memory');
  String get resolveAgain => _v('重新解析地址', 'Resolve again');
  String get noPlayableEpisode => _v('这部剧没有可用剧集', 'No episodes available');
  String get resolveFailed => _v('无法解析播放地址', 'Could not resolve the stream');
  String get currentEpisode => _v('当前', 'Current');
  String get errorNetwork => _v(
    '网络不可用或源站超时。请检查网络或系统代理后重试。',
    'Network unreachable or the site timed out. Check your connection or proxy.',
  );
  String get errorDecode => _v(
    '视频编码或容器不受支持，可以换一个源或改用外部播放器。',
    'This codec or container is not supported. Try another source or an external player.',
  );
  String get errorRender => _v(
    '渲染面创建失败（常见于虚拟机、远程桌面或老显卡）。改用软件渲染通常可以出画面。',
    'The render surface could not be created (common on VMs, remote desktops or old GPUs). Software rendering usually fixes it.',
  );
  String get errorExpired => _v(
    '播放地址已过期或需要鉴权，正在尝试重新解析。',
    'The stream URL expired or needs authorization. Re-resolving now.',
  );
  String get errorUnsupported =>
      _v('该地址的协议或格式暂不支持。', 'This protocol or format is not supported yet.');
  String get errorUnknown => _v(
    '播放器启动失败，可重试或换一个源。',
    'The player failed to start. Retry or try another source.',
  );
  String get errorDetail => _v('技术细节', 'Technical details');

  // ---------- 设置 · 播放 ----------
  String get playerSettings => _v('播放设置', 'Playback');
  String get renderPolicy => _v('渲染方式', 'Renderer');
  String get renderPolicyAuto => _v('自动（失败降级）', 'Auto (fallback on failure)');
  String get renderPolicyAutoHint => _v(
    '优先硬件加速，渲染失败时自动切换到软件渲染',
    'Prefer GPU, fall back to software if rendering fails',
  );
  String get renderPolicyHardware => _v('硬件加速', 'Hardware only');
  String get renderPolicyHardwareHint => _v(
    '始终使用 GPU 渲染，出问题时直接报错',
    'Always use the GPU; report errors instead of falling back',
  );
  String get renderPolicySoftware => _v('软件渲染', 'Software only');
  String get renderPolicySoftwareHint => _v(
    '兼容性最好，虚拟机或无独显设备选这个',
    'Best compatibility for VMs or machines without a dedicated GPU',
  );
  String get lowMemory => _v('低内存模式', 'Low memory mode');
  String get lowMemoryHint => _v(
    '播放缓存降到 8 MB，并限制输出到 720p',
    'Cuts the playback cache to 8 MB and caps output at 720p',
  );
  String get autoPlayNext => _v('自动播放下一集', 'Autoplay next episode');
  String get autoPlayNextHint =>
      _v('一集播完后自动续播', 'Continue with the next episode when one ends');
  String get gestures => _v('手势控制', 'Touch gestures');
  String get gesturesHint => _v(
    '左右拖动进度、左右两侧调节亮度与音量、长按 2 倍速',
    'Drag to seek, sides for brightness/volume, long-press for 2x',
  );
  String get keyboardShortcuts => _v('键盘快捷键', 'Keyboard shortcuts');
  String get keyboardShortcutsHint => _v(
    '空格播放/暂停，方向键快进与音量，F 全屏，[ ] 倍速',
    'Space toggles play, arrows seek and change volume, F fullscreen, [ ] speed',
  );
  String get debugOverlay => _v('调试信息', 'Debug overlay');
  String get debugOverlayHint =>
      _v('在播放页左上角显示渲染方式与缓存占用', 'Show renderer and buffer usage in the player');
  String get preferredQuality => _v('首选清晰度', 'Preferred quality');
  String get playerSettingsFootnote => _v(
    '修改立即生效；正在播放的进度会保留。',
    'Changes apply immediately; playback position is preserved.',
  );
  String get resetDefaults => _v('恢复默认', 'Reset to defaults');

  // ---------- 日志 ----------
  String get logs => _v('运行日志', 'Logs');
  String get logsHint =>
      _v('最近的运行记录，便于排查问题', 'Recent runtime records for troubleshooting');
  String get logsEmpty => _v('还没有日志', 'No logs yet');
  String get clearLogs => _v('清空', 'Clear');
  String get copyLogs => _v('复制全部', 'Copy all');
  String get logLevelAll => _v('全部', 'All');
  String get logLevelWarning => _v('警告', 'Warnings');
  String get logLevelError => _v('错误', 'Errors');

  // ---------- 关于 ----------
  String get about => _v('关于', 'About');
  String get version => _v('版本', 'Version');
  String get licenses => _v('开源许可', 'Licenses');

  // ---------- 详情 ----------
  String get synopsis => _v('简介', 'Synopsis');
  String get castSection => _v('主演', 'Cast');
  String get crew => _v('制作', 'Crew');
  String get director => _v('导演', 'Director');
  String get writer => _v('编剧', 'Writer');
  String get noCredits => _v('未匹配到演职员信息', 'No cast information matched');
  String get tmdbKeyMissing => _v('未配置 TMDB Key', 'TMDB key not configured');
  String get rating => _v('评分', 'Rating');

  // ---------- 源与规则 ----------
  String get sources => _v('视频源', 'Sources');
  String get addSource => _v('添加源', 'Add source');
  String get addMaccms => _v('添加苹果 CMS 站点', 'Add a MacCMS site');
  String get addMaccmsHint => _v(
    '填入站点根地址，自动走 /api.php/provide/vod/ 采集接口',
    'Enter the site root; the /api.php/provide/vod/ API is used',
  );
  String get importRuleJson => _v('导入规则 JSON', 'Import rule JSON');
  String get importRuleJsonHint =>
      _v('粘贴规则内容，或从剪贴板导入', 'Paste a rule, or import from the clipboard');
  String get newRule => _v('新建规则源', 'New rule source');
  String get editRule => _v('编辑规则', 'Edit rule');
  String get ruleEditor => _v('规则编辑器', 'Rule editor');
  String get exportJson => _v('导出 JSON', 'Export JSON');
  String get ruleBasic => _v('基本信息', 'Basics');
  String get ruleSearch => _v('搜索规则', 'Search rule');
  String get ruleDetail => _v('详情规则', 'Detail rule');
  String get rulePlay => _v('播放规则', 'Playback rule');
  String get ruleHeaders => _v('请求头', 'Headers');
  String get ruleName => _v('名称', 'Name');
  String get ruleId => _v('标识', 'ID');
  String get ruleBaseUrl => _v('站点根地址', 'Base URL');
  String get ruleSearchUrl => _v('搜索地址', 'Search URL');
  String get ruleSearchUrlHint =>
      _v('支持 {keyword} 与 {page} 占位符', 'Supports {keyword} and {page}');
  String get ruleListSelector => _v('列表选择器', 'List selector');
  String get ruleTitleSelector => _v('标题选择器', 'Title selector');
  String get ruleUrlSelector => _v('链接选择器', 'Link selector');
  String get ruleCoverSelector => _v('封面选择器（可选）', 'Cover selector (optional)');
  String get ruleRemarkSelector =>
      _v('备注选择器（可选）', 'Remark selector (optional)');
  String get ruleAttr => _v('取值属性', 'Attribute');
  String get ruleRegex => _v('正则（可选）', 'Regex (optional)');
  String get ruleSelector => _v('CSS 选择器', 'CSS selector');
  String get ruleRegexGroup => _v('正则分组', 'Regex group');
  String get ruleDetailTitle => _v('详情标题选择器', 'Detail title selector');
  String get ruleDetailYear => _v('年份选择器（可选）', 'Year selector (optional)');
  String get ruleEpisodeList => _v('选集列表选择器', 'Episode list selector');
  String get rulePlayMode => _v('解析方式', 'Mode');
  String get rulePlayModePage =>
      _v('请求播放页并提取', 'Fetch the play page and extract');
  String get rulePlayModeDirect => _v('选集地址即视频地址', 'Episode URL is the stream');
  String get rulePlayPatterns =>
      _v('提取正则（每行一条）', 'Extraction regexes (one per line)');
  String get ruleReferer => _v('Referer（可选）', 'Referer (optional)');
  String get ruleTestKeyword => _v('测试关键词', 'Test keyword');
  String get ruleTestSearch => _v('测试搜索', 'Test search');
  String get ruleTestDetail => _v('测试详情', 'Test detail');
  String get ruleValidate => _v('校验规则', 'Validate rule');
  String get ruleSaved => _v('规则已保存', 'Rule saved');
  String get ruleInvalid => _v('规则不完整', 'Rule is incomplete');
  String get ruleNeedBaseUrl =>
      _v('请填写站点根地址（含 http/https）', 'Base URL is required (http/https)');
  String get ruleNeedName => _v('请填写名称', 'Name is required');
  String get ruleNeedId =>
      _v('请填写标识（英文、数字、短横线）', 'ID is required (letters, digits, dashes)');
  String get ruleNeedSearchUrl => _v('请填写搜索地址', 'Search URL is required');
  String get ruleNeedEpisodeList =>
      _v('请填写选集列表选择器', 'Episode list selector is required');
  String get ruleNeedPlayMode =>
      _v('解析方式只能是 page 或 direct', 'Mode must be page or direct');
  String get ruleMethod => _v('请求方式', 'Method');
  String get rulePostBody =>
      _v('POST 表单（支持 {keyword}）', 'POST form (supports {keyword})');
  String get ruleCurrentNode => _v('当前节点', 'current node');
  String get ruleUnset => _v('未设置', 'Not set');
  String get ruleTestPreview => _v('测试结果', 'Test result');
  String get ruleNoTestYet => _v('还没有测试结果', 'No test yet');
  String get ruleDetailPreview => _v('详情预览', 'Detail preview');
  String get ruleImportFromJson => _v('从 JSON 导入', 'Import from JSON');
  String get ruleImportHint =>
      _v('粘贴完整规则 JSON，会覆盖当前表单', 'Paste a full rule JSON; it replaces the form');
  String get ruleNeedList => _v('请填写列表选择器', 'List selector is required');
  String get ruleNeedFields =>
      _v('标题与链接选择器都要填写', 'Title and link selectors are required');
  String get ruleTestEmpty => _v(
    '没有匹配到结果，检查选择器或站点是否需要 JS',
    'No results. Check the selectors or whether the site needs JS',
  );
  String get import => _v('导入', 'Import');
  String get export => _v('导出', 'Export');
  String get sourceTypeMaccms => _v('苹果 CMS', 'MacCMS');
  String get sourceTypeRule => _v('规则', 'Rule');
  String get sourceTypeAdapter => _v('适配器', 'Adapter');
  String get deleteSourceTitle => _v('删除这个源？', 'Delete this source?');

  // ---------- 同步 ----------
  String get sync => _v('同步', 'Sync');
  String get syncHint => _v(
    '用 WebDAV 在设备之间同步收藏、进度与视频源',
    'Sync favorites, progress and sources over WebDAV',
  );
  String get syncServer => _v('服务器地址', 'Server URL');
  String get syncServerHint =>
      _v('例如 https://dav.example.com/dav', 'e.g. https://dav.example.com/dav');
  String get syncUsername => _v('用户名', 'Username');
  String get syncPassword => _v('密码', 'Password');
  String get syncPath => _v('文件路径', 'File path');
  String get syncNow => _v('立即同步', 'Sync now');
  String get syncTest => _v('测试连接', 'Test connection');
  String get syncEnabled => _v('启用自动同步', 'Enable auto sync');
  String get syncLastAt => _v('上次同步', 'Last synced');
  String get syncNever => _v('从未同步', 'Never');
  String get syncRunning => _v('同步中…', 'Syncing…');
  String get syncSuccess => _v('同步完成', 'Sync complete');
  String get syncFailed => _v('同步失败', 'Sync failed');
  String get syncAutoOff => _v('自动同步已关闭', 'Auto sync is off');
  String get syncNeedServer => _v('请先填写服务器地址', 'Server URL is required');
  String get syncConflict => _v('冲突处理', 'Conflict policy');
  String get syncConflictNewest => _v('以更新时间较新的为准', 'Keep the newest');
  String get syncConflictLocal => _v('以本机为准', 'Prefer local');
  String get syncConflictRemote => _v('以云端为准', 'Prefer remote');
  String get syncPasswordWarning => _v(
    '账号密码以明文保存在本机偏好设置中，请使用专用账号或应用密码。',
    'Credentials are stored in plain text in local preferences. Use a dedicated account or app password.',
  );
  String get syncSourcesToo =>
      _v('同时同步视频源配置', 'Sync source configurations too');

  // ---------- 投屏 ----------
  String get cast => _v('投屏', 'Cast');
  String get castSearching => _v('正在搜索局域网设备…', 'Searching for devices…');
  String get castNoDevice => _v('没有发现可投屏设备', 'No cast devices found');
  String get castConnect => _v('连接', 'Connect');
  String get castDisconnect => _v('断开', 'Disconnect');
  String get castCastingTo => _v('正在投屏到', 'Casting to');
  String get castUnsupported =>
      _v('该设备不支持此格式', 'This device does not support the format');
  String get castNeedUrl => _v('当前没有可投屏的地址', 'No stream URL to cast');

  // ---------- 杂项 ----------
  String get search => _v('搜索', 'Search');
  String get searchHint => _v('搜索剧名', 'Search titles');
  String get history => _v('观看历史', 'History');
  String get theme => _v('主题', 'Theme');
  String get themeSystem => _v('跟随系统', 'System');
  String get themeLight => _v('浅色', 'Light');
  String get themeDark => _v('深色', 'Dark');
  String get language => _v('语言', 'Language');
  String get languageSystem => _v('跟随系统', 'System');
  String get languageZh => _v('简体中文', '简体中文');
  String get languageEn => _v('English', 'English');
  String get storage => _v('存储', 'Storage');

  // ---------- 我的 ----------
  String get myTitle => _v('我的', 'Me');
  String get statFollowing => _v('追剧', 'Following');
  String get statWatched => _v('观看', 'Watched');
  String get statSources => _v('源', 'Sources');
  String get sourcesHint => _v('启用、添加与规则编辑', 'Enable, add and edit rules');
  String get playerSettingsHint =>
      _v('渲染方式、清晰度、低内存', 'Renderer, quality and memory');
  String get themeHint => _v('浅色 / 深色 / 跟随系统', 'Light / dark / system');
  String get languageHint => _v('中文 / English', '中文 / English');
  String get historyHint => _v('续播与清理', 'Resume and clean up');
  String get aboutHint => _v('版本与开源许可', 'Version and licenses');
  String get metadataTitle => _v('演职员数据', 'Cast data');
  String get metadataHint => _v('TMDB Key、数据语言', 'TMDB key and language');
  String get tmdbApiKey => _v('TMDB API Key', 'TMDB API key');
  String get tmdbKeyHint => _v(
    '在 themoviedb.org 免费申请（v3 Key）',
    'Get a free v3 key at themoviedb.org',
  );
  String get tmdbLanguage => _v('数据语言', 'Data language');
  String get tmdbNote => _v(
    '自定义 Key 只保存在本机；未配置时详情页不显示演职员，也不启用 TMDB 韩剧识别，不影响其他功能。',
    'A custom key stays on this device. Without one, cast data and TMDB Korean-drama detection are disabled; nothing else changes.',
  );
  String get tmdbTestOk => _v('连接成功', 'Connected');
  String get tmdbTestFailed => _v('连接失败', 'Connection failed');
  String get tmdbBuiltInKey => _v(
    '已使用内置 TMDB Key；填入自己的 Key 可覆盖。',
    'A built-in TMDB key is active; enter your own to override it.',
  );

  // ---------- 韩剧分类 ----------
  String get koreanDramas => _v('韩剧', 'Korean dramas');
  String get koreanOnly => _v('只看韩剧', 'Korean dramas only');
  String get tmdbClassifying =>
      _v('正在用 TMDB 识别韩剧…', 'Identifying Korean dramas with TMDB…');
  String get tmdbNoKey => _v(
    '未配置 TMDB Key，已关闭韩剧过滤。',
    'TMDB key is not configured; Korean filter is off.',
  );
  String get tmdbClassifyFailed => _v(
    'TMDB 识别失败，已显示未过滤结果。',
    'TMDB lookup failed; showing unfiltered results.',
  );
  String get tmdbNoKorean => _v('没有识别到韩剧', 'No Korean dramas found');
  String get tmdbNoKoreanDesc => _v(
    '当前分类没有被 TMDB 识别为韩剧的条目；可以切换分类或关闭「只看韩剧」。',
    'TMDB recognized no Korean dramas in this category. Switch category or turn off the Korean filter.',
  );

  // ---------- 列表与状态 ----------
  String get loadingDots => _v('正在加载…', 'Loading…');
  String get errorTitle => _v('出错了', 'Something went wrong');
  String get latestUpdates => _v('最新更新', 'Latest');
  String get chooseCategory => _v('选择分类', 'Category');
  String get genreMovie => _v('电影', 'Movies');
  String get genreSeries => _v('连续剧', 'Series');
  String get genreVariety => _v('综艺', 'Variety');
  String get genreAnime => _v('动漫', 'Anime');
  String get sampleKeyword => _v('韩剧', 'K-drama');
  String get copySuffix => _v('副本', 'copy');

  /// CMS 的分类 id 是固定的，按 id 本地化；其它源自带的名字原样返回。
  String categoryName(String id, String fallback) {
    return switch (id) {
      '' => latestUpdates,
      '1' => genreMovie,
      '2' => genreSeries,
      '3' => genreVariety,
      '4' => genreAnime,
      _ => fallback,
    };
  }

  String get noContentTitle => _v('还没有内容', 'Nothing yet');
  String get noContentDesc => _v(
    '在「我的 → 视频源」里添加一个资源站，这里会显示它的最新影视',
    'Add a source under Me → Sources to see its latest titles here',
  );
  String get goAddSource => _v('去添加源', 'Add a source');
  String get goSearch => _v('去搜索', 'Search');
  String get noBrowseTitle => _v('当前没有可浏览的源', 'No browsable source');
  String get noBrowseDesc => _v(
    '内置规则源只支持搜索，直接搜剧名即可；添加苹果 CMS 站点后，这里会显示它的最新内容。',
    'Rule sources are search-only — just search a title. Add a MacCMS site to see its latest titles here.',
  );
  String get searchingSources => _v('正在并发搜索各源…', 'Searching all sources…');
  String get searchEmptyTitle => _v('输入剧名开始搜索', 'Type a title to search');
  String get searchEmptyDesc => _v(
    '同时查询所有已启用的源，同一部剧会合并展示',
    'Every enabled source is queried; the same show is merged',
  );
  String get noResultsTitle => _v('没有找到结果', 'No results');
  String get noResultsDesc => _v(
    '换个关键词，或到「我的 → 视频源」启用更多源',
    'Try another keyword, or enable more sources under Me → Sources',
  );
  String get noSourcesHint => _v(
    '还没有可用的视频源，请先到「我的 → 视频源」添加',
    'No sources yet — add one under Me → Sources',
  );
  String sourceCount(int count) =>
      isZh ? '$count 个源' : '$count source${count == 1 ? '' : 's'}';
  String sourceBadge(int count) => isZh ? '$count 源' : '$count src';
  String get sourceFailed => _v('失败', 'failed');

  // ---------- 追剧 / 时间表 / 历史 ----------
  String get collectEmptyTitle => _v('还没有追剧', 'Nothing followed yet');
  String get collectEmptyDesc => _v(
    '在剧集详情页点右上角的收藏，就会出现在这里',
    'Tap the bookmark on a show and it will appear here',
  );
  String weekdayLabel(int weekday) {
    if (isZh) {
      const List<String> names = <String>['一', '二', '三', '四', '五', '六', '日'];
      return '周${names[(weekday - 1).clamp(0, 6)]}';
    }
    const List<String> names = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String slotLabel(String id) {
    return switch (id) {
      'mon_tue' => _v('月火剧', 'Mon–Tue drama'),
      'wed_thu' => _v('水木剧', 'Wed–Thu drama'),
      'fri_sat' => _v('金土剧', 'Fri–Sat drama'),
      'weekend' => _v('周末剧', 'Weekend drama'),
      _ => id,
    };
  }

  String get timelineNote => _v(
    '这里展示韩国电视台的常规档期。具体某部剧的更新进度以各视频源为准，搜索剧名即可看到最新集数。',
    'Regular Korean TV slots. Actual episode progress depends on each source — search the title to see the latest episodes.',
  );
  String get historyEmptyTitle => _v('还没有观看记录', 'No watch history');
  String get historyEmptyDesc =>
      _v('播放过的剧集会出现在这里', 'Shows you played will appear here');

  // ---------- 详情 ----------
  String get detailTitle => _v('详情', 'Details');
  String get startFromFirst => _v('从第 1 集开始', 'Start from episode 1');
  String get addFavorite => _v('收藏', 'Follow');
  String get removeFavorite => _v('取消收藏', 'Unfollow');
  String episodeCountLabel(int count) => plural(count, ' 集', 'episodes');

  // ---------- 关于 ----------
  String get noticeTitle => _v('说明', 'Notice');
  String get noticeText => _v(
    '本应用不存储、不上传任何视频内容，也不内置播放地址。'
        '所有数据来自用户自行配置的第三方站点，仅供个人学习与技术研究使用。'
        '请遵守当地法律法规，支持正版内容。',
    'This app stores and uploads no video content and ships no playback URLs. '
        'All data comes from third-party sites configured by the user, for personal study and technical research only. '
        'Please follow local laws and support official releases.',
  );
}

/// 本地化代理。
class L10nDelegate extends LocalizationsDelegate<L10n> {
  const L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      const <String>['zh', 'en'].contains(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) => SynchronousFuture<L10n>(L10n(locale));

  @override
  bool shouldReload(L10nDelegate old) => false;
}
