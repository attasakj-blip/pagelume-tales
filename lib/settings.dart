import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the reader chose, remembered between visits.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// Menu language code, or null to follow the phone.
  String? get uiLang => _prefs.getString('uiLang');
  set uiLang(String? v) => _set(() => v == null ? _prefs.remove('uiLang') : _prefs.setString('uiLang', v));

  /// Turn the page by itself after the words have been read.
  bool get autoTurn => _prefs.getBool('autoTurn') ?? true;
  set autoTurn(bool v) => _set(() => _prefs.setBool('autoTurn', v));

  bool get flipSound => _prefs.getBool('flipSound') ?? true;
  set flipSound(bool v) => _set(() => _prefs.setBool('flipSound', v));

  int lastPage(String story) => _prefs.getInt('page_$story') ?? 0;
  void setLastPage(String story, int p) => _prefs.setInt('page_$story', p);

  /// The phone voice the reader picked for a character, or null for automatic.
  String? voiceFor(String story, String character) => _prefs.getString('voice_${story}_$character');
  void setVoice(String story, String character, String? voiceName) => _set(
    () => voiceName == null
        ? _prefs.remove('voice_${story}_$character')
        : _prefs.setString('voice_${story}_$character', voiceName),
  );

  void _set(void Function() f) {
    f();
    notifyListeners();
  }
}
