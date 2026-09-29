import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'tables.dart';

/// One supported language.
class Lang {
  const Lang(this.code, this.name, {this.rtl = false, this.locale});
  final String code;
  final String name; // native name
  final bool rtl;
  final Locale? locale;

  Locale get flutterLocale => locale ?? Locale(code);
}

/// The 20 most widely spoken languages we support.
const List<Lang> languages = [
  Lang('en', 'English'),
  Lang('ja', '日本語'),
  Lang('zh', '简体中文', locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')),
  Lang('zh_TW', '繁體中文', locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
  Lang('ko', '한국어'),
  Lang('es', 'Español'),
  Lang('fr', 'Français'),
  Lang('de', 'Deutsch'),
  Lang('pt', 'Português'),
  Lang('ru', 'Русский'),
  Lang('it', 'Italiano'),
  Lang('hi', 'हिन्दी'),
  Lang('bn', 'বাংলা'),
  Lang('ar', 'العربية', rtl: true),
  Lang('ur', 'اردو', rtl: true),
  Lang('fa', 'فارسی', rtl: true),
  Lang('id', 'Bahasa Indonesia'),
  Lang('tr', 'Türkçe'),
  Lang('vi', 'Tiếng Việt'),
  Lang('th', 'ไทย'),
];

/// Title, imperative verb and ad hook of one game.
class GameText {
  const GameText(this.title, this.verb, this.hook);
  final String title;
  final String verb;
  final String hook;
}

/// Static localization access. Set [code] at startup / when the user changes
/// language; widgets rebuild via the app controller.
abstract final class L10n {
  static String code = 'en';

  static Lang get lang => languages.firstWhere((l) => l.code == code, orElse: () => languages.first);
  static bool get rtl => lang.rtl;
  static TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;

  /// Picks the best supported language for the device locale.
  static String detect() {
    final locales = PlatformDispatcher.instance.locales;
    for (final l in locales) {
      if (l.languageCode == 'zh') {
        final hant = l.scriptCode == 'Hant' || const {'TW', 'HK', 'MO'}.contains(l.countryCode);
        return hant ? 'zh_TW' : 'zh';
      }
      for (final lang in languages) {
        if (lang.code == l.languageCode) return lang.code;
      }
    }
    return 'en';
  }

  static String ui(String key, [Map<String, Object>? args]) {
    var s = uiTables[code]?[key] ?? uiTables['en']![key] ?? key;
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    }
    return s;
  }

  static GameText game(int no) {
    final t = gameTables[code]?[no] ?? gameTables['en']![no];
    if (t == null) return GameText('No.$no', 'GO!', '');
    return GameText(t[0], t[1], t[2]);
  }

  /// In-game short word. Missing translations fall back to [english].
  static String word(String key, String english) => wordTables[code]?[key] ?? english;
}
