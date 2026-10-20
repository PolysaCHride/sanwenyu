import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语言模式。
enum AppLocaleMode {
  system,
  zh,
  en;

  static AppLocaleMode fromStorage(String? value) {
    return switch (value) {
      'zh' => AppLocaleMode.zh,
      'en' => AppLocaleMode.en,
      _ => AppLocaleMode.system,
    };
  }

  String get storageValue => name;
}

/// 语言偏好的读写与解析。
class LocalePreferences {
  const LocalePreferences._();

  static const String storageKey = 'app.locale';

  static const Locale zh = Locale('zh', 'CN');
  static const Locale en = Locale('en', 'US');

  /// 默认中文：应用面向中文用户，跟随系统只作为可选行为。
  static AppLocaleMode mode = AppLocaleMode.zh;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = AppLocaleMode.fromStorage(prefs.getString(storageKey));
  }

  static Future<void> save(AppLocaleMode value) async {
    mode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value.storageValue);
  }

  /// 把「模式 + 系统语言」解析成实际 Locale。
  static Locale resolve(AppLocaleMode mode, Locale systemLocale) {
    switch (mode) {
      case AppLocaleMode.zh:
        return zh;
      case AppLocaleMode.en:
        return en;
      case AppLocaleMode.system:
        if (systemLocale.languageCode == 'en') return en;
        if (systemLocale.languageCode == 'zh') {
          return systemLocale.countryCode == null
              ? zh
              : Locale(systemLocale.languageCode, systemLocale.countryCode!);
        }
        return zh;
    }
  }
}
