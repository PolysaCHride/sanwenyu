import 'package:shared_preferences/shared_preferences.dart';

/// TMDB 配置（用户自备 Key）。
class TmdbSettings {
  const TmdbSettings({
    this.apiKey = '',
    this.language = 'zh-CN',
  });

  static const String keyApi = 'tmdb.apiKey';
  static const String keyLanguage = 'tmdb.language';

  final String apiKey;
  final String language;

  bool get enabled => apiKey.trim().isNotEmpty;

  TmdbSettings copyWith({String? apiKey, String? language}) {
    return TmdbSettings(
      apiKey: apiKey ?? this.apiKey,
      language: language ?? this.language,
    );
  }

  static Future<TmdbSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return TmdbSettings(
      apiKey: prefs.getString(keyApi) ?? '',
      language: prefs.getString(keyLanguage) ?? 'zh-CN',
    );
  }

  static Future<void> save(TmdbSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyApi, settings.apiKey.trim());
    await prefs.setString(keyLanguage, settings.language);
  }
}
