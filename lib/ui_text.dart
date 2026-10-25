import 'package:flutter/widgets.dart';

import 'ui_strings.g.dart';

/// The app's own words (menus, buttons) in one of 23 languages.
/// Stories are in English; only these words follow the chosen language.
class T {
  T(String code) : code = uiStrings.containsKey(code) ? code : 'en';

  final String code;

  String _s(String key) => uiStrings[code]![uiKeys.indexOf(key)];

  static const appName = 'Pagelume Tales';
  String get shelf => _s('shelf');
  String get listen => _s('listen');
  String get pause => _s('pause');
  String get autoTurn => _s('autoTurn');
  String get flipSound => _s('flipSound');
  String get voices => _s('voices');
  String get backToShelf => _s('backToShelf');
  String get fromStart => _s('fromStart');
  String get noVoice => _s('noVoice');
  String get voicesNote => _s('voicesNote');
  String get automatic => _s('automatic');
  String get language => _s('language');
  String get phoneLanguage => _s('phoneLanguage');
  String get male => _s('male');
  String get female => _s('female');
  String get storiesInEnglish => _s('storiesInEnglish');
  String get moreSoon => _s('moreSoon');
  String pages(int n) => _s('pages').replaceAll('{n}', '$n');
  String voiceType(String v) => uiKeys.contains(v) ? _s(v) : v;

  static List<String> get codes => uiLanguageNames.keys.toList();

  static Locale localeOf(String code) {
    final p = code.split('_');
    return p.length == 2 ? Locale.fromSubtags(languageCode: p[0], scriptCode: p[1]) : Locale(code);
  }

  /// Best UI language for the phone's locale.
  static String codeFor(Locale l) {
    if (l.languageCode == 'zh') {
      final hant = l.scriptCode == 'Hant' || const ['TW', 'HK', 'MO'].contains(l.countryCode);
      return hant ? 'zh_Hant' : 'zh';
    }
    if (l.languageCode == 'tl') return 'fil';
    return uiStrings.containsKey(l.languageCode) ? l.languageCode : 'en';
  }
}

/// The menu language now in use: the reader's choice, or the phone's.
T textFor(String? chosen) => T(chosen ?? T.codeFor(WidgetsBinding.instance.platformDispatcher.locale));
