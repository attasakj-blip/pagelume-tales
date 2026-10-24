import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story.dart';

/// What the reader chose, remembered between visits.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  Lang get lang => _prefs.getString('lang') == 'en' ? Lang.en : Lang.th;
  set lang(Lang v) => _set(() => _prefs.setString('lang', v.name));

  /// Turn the page by itself after the words have been read.
  bool get autoTurn => _prefs.getBool('autoTurn') ?? true;
  set autoTurn(bool v) => _set(() => _prefs.setBool('autoTurn', v));

  bool get flipSound => _prefs.getBool('flipSound') ?? true;
  set flipSound(bool v) => _set(() => _prefs.setBool('flipSound', v));

  int lastPage(String story) => _prefs.getInt('page_$story') ?? 0;
  void setLastPage(String story, int p) => _prefs.setInt('page_$story', p);

  void _set(void Function() f) {
    f();
    notifyListeners();
  }
}
