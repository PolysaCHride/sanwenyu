/// 构建时注入的 TMDB Key。
///
/// 仓库里不保存真实 Key；发布构建使用：
/// `flutter build apk --dart-define=TMDB_API_KEY=...`
const String kTmdbApiKey = String.fromEnvironment('TMDB_API_KEY');
