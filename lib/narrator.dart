import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'story.dart';

/// A voice installed on the phone, as the speech engine reports it.
class DeviceVoice {
  DeviceVoice(this.name, this.locale, {required this.male, required this.offline});
  final String name;
  final String locale;
  final bool male;
  final bool offline;

  Map<String, String> get asMap => {'name': name, 'locale': locale};
}

/// Google's speech engine names its voices with short codes; these are the
/// male ones (the rest are female). Other engines often put "male" in the name.
const _maleCodes = {
  // English (US, UK, Australia, India)
  'iol', 'iom', 'tpd', 'gbb', 'gbd', 'rjs', 'aub', 'aud', 'end',
  // Thai has no male Google voice yet, but list future ones here.
};

bool guessMale(String name, String features) {
  final n = name.toLowerCase();
  final f = features.toLowerCase();
  if (f.contains('gender=male') || f.contains('male') && !f.contains('female')) return true;
  if (RegExp(r'(^|[^e])male').hasMatch(n)) return true;
  final m = RegExp(r'-x-([a-z]{3})').firstMatch(n);
  return m != null && _maleCodes.contains(m.group(1));
}

/// Reads story lines aloud with the phone's own speech engine (free, works
/// offline once the language is installed). Each character gets its own
/// voice where the phone has one, and its own pitch and speed, so the
/// grandpa sounds deeper and slower than the mouse.
class Narrator extends ChangeNotifier {
  Narrator({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  final Map<Lang, List<DeviceVoice>> _voices = {};
  final Map<Lang, bool> _available = {};
  final Map<(Lang, String), DeviceVoice?> _assigned = {};
  int _session = 0;
  bool speaking = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      final raw = await _tts.getVoices;
      for (final v in (raw as List? ?? const [])) {
        final m = Map<String, dynamic>.from(v as Map);
        final name = '${m['name'] ?? ''}';
        final locale = '${m['locale'] ?? ''}';
        final features = '${m['features'] ?? ''}${m['gender'] == null ? '' : '\tgender=${m['gender']}'}';
        if (features.contains('notInstalled')) continue;
        final lang = locale.toLowerCase().startsWith('th') ? Lang.th : (locale.toLowerCase().startsWith('en') ? Lang.en : null);
        if (lang == null) continue;
        _voices.putIfAbsent(lang, () => []).add(
          DeviceVoice(name, locale, male: guessMale(name, features), offline: m['network_required'] != '1'),
        );
      }
      for (final l in Lang.values) {
        // Prefer the main accent (US English / Thailand Thai), then offline voices.
        _voices[l]?.sort((a, b) {
          int score(DeviceVoice v) =>
              (v.locale.toLowerCase().replaceAll('_', '-') == l.ttsLocale.toLowerCase() ? 0 : 2) + (v.offline ? 0 : 1);
          return score(a).compareTo(score(b));
        });
      }
    } catch (e) {
      debugPrint('Narrator: could not list voices: $e');
    }
  }

  /// Whether the phone can speak [lang] at all.
  Future<bool> canSpeak(Lang lang) async {
    await _init();
    final hit = _available[lang];
    if (hit != null) return hit;
    var ok = (_voices[lang]?.isNotEmpty ?? false);
    try {
      final r = await _tts.isLanguageAvailable(lang.ttsLocale);
      ok = ok || r == true || r == 1;
    } catch (_) {}
    return _available[lang] = ok;
  }

  /// Picks a phone voice for [c]: one of the right gender if there is one.
  /// Characters of the same gender take turns through the voices, so with
  /// several voices installed they don't all sound alike.
  DeviceVoice? voiceFor(Story story, Character c, Lang lang) {
    return _assigned.putIfAbsent((lang, '${story.id}/${c.id}'), () {
      final all = _voices[lang] ?? const <DeviceVoice>[];
      if (all.isEmpty) return null;
      final best = all.where((v) => v.locale == all.first.locale).toList();
      final same = best.where((v) => v.male == c.male).toList();
      final pool = same.isNotEmpty ? same : best;
      final peers = story.characters.values.where((o) => o.male == c.male).toList();
      final i = peers.indexWhere((o) => o.id == c.id);
      return pool[(i < 0 ? 0 : i) % pool.length];
    });
  }

  /// When a character has to borrow a voice of the other gender (Thai phones
  /// usually only have a female voice), push the pitch further so they still
  /// sound like who they are.
  double pitchFor(Character c, DeviceVoice? v) {
    var p = c.pitch;
    if (v != null && v.male != c.male) p *= c.male ? 0.85 : 1.15;
    return p.clamp(0.5, 2.0);
  }

  /// Says one line. Returns false if it was cut short by [stop].
  Future<bool> say(Story story, Line line, Lang lang) async {
    await _init();
    final session = _session;
    final c = story.speaker(line.who);
    final v = voiceFor(story, c, lang);
    try {
      await _tts.setLanguage(v?.locale ?? lang.ttsLocale);
      if (v != null) await _tts.setVoice(v.asMap);
      await _tts.setPitch(pitchFor(c, v));
      await _tts.setSpeechRate(c.rate);
      if (session != _session) return false;
      speaking = true;
      notifyListeners();
      await _tts.speak(line.text);
    } catch (e) {
      debugPrint('Narrator: $e');
    }
    return session == _session;
  }

  /// Stops speaking at once; any [say] in progress reports it was cut short.
  Future<void> stop() async {
    _session++;
    speaking = false;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Phone voices found for [lang] (for the voices sheet).
  Future<List<DeviceVoice>> voices(Lang lang) async {
    await _init();
    return _voices[lang] ?? const [];
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
