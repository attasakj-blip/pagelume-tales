import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'story.dart';

/// An English voice installed on the phone, as the speech engine reports it.
class DeviceVoice {
  DeviceVoice(this.name, this.locale, {required this.male, required this.offline});
  final String name;
  final String locale;
  final bool male;
  final bool offline;

  Map<String, String> get asMap => {'name': name, 'locale': locale};

  /// Accent shown to the reader: US, UK, AU, IN, ...
  String get region {
    final p = locale.replaceAll('_', '-').split('-');
    final r = p.length > 1 ? p[1].toUpperCase() : 'EN';
    return r == 'GB' ? 'UK' : r;
  }
}

/// Google's speech engine names its voices with short codes; these are the
/// male ones (the rest are female). Other engines often put "male" in the name.
const _maleCodes = {'iol', 'iom', 'tpd', 'gbb', 'gbd', 'rjs', 'aub', 'aud', 'end'};

bool guessMale(String name, String features) {
  final n = name.toLowerCase();
  final f = features.toLowerCase();
  if (f.contains('gender=male')) return true;
  if (f.contains('gender=female')) return false;
  if (RegExp(r'(^|[^e])male').hasMatch(n)) return true;
  final m = RegExp(r'-x-([a-z]{3})').firstMatch(n);
  return m != null && _maleCodes.contains(m.group(1));
}

/// Reads story lines aloud with the phone's own English speech engine (free,
/// works offline). Each character speaks with the voice the reader picked for
/// them, or an automatic one of the right gender, and with its own pitch and
/// speed, so the grandpa sounds deeper and slower than the mouse.
class Narrator extends ChangeNotifier {
  Narrator({FlutterTts? tts, this.chosen}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// The voice name the reader picked for a character, if any.
  String? Function(Story story, Character c)? chosen;

  bool _ready = false;
  List<DeviceVoice> _voices = [];
  bool? _available;
  int _session = 0;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      final raw = await _tts.getVoices;
      final list = <DeviceVoice>[];
      for (final v in (raw as List? ?? const [])) {
        final m = Map<String, dynamic>.from(v as Map);
        final name = '${m['name'] ?? ''}';
        final locale = '${m['locale'] ?? ''}';
        final features = '${m['features'] ?? ''}${m['gender'] == null ? '' : '\tgender=${m['gender']}'}';
        if (features.contains('notInstalled') || !locale.toLowerCase().startsWith('en')) continue;
        list.add(DeviceVoice(name, locale, male: guessMale(name, features), offline: m['network_required'] != '1'));
      }
      // Voices that work without internet are enough; keep online ones only
      // if the phone has nothing else.
      final offline = list.where((v) => v.offline).toList();
      _voices = offline.isNotEmpty ? offline : list;
      int rank(DeviceVoice v) => const ['US', 'UK', 'AU', 'IN'].indexOf(v.region) & 0xFF;
      _voices.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        if (a.male != b.male) return a.male ? 1 : -1;
        return a.name.compareTo(b.name);
      });
    } catch (e) {
      debugPrint('Narrator: could not list voices: $e');
    }
  }

  /// Whether the phone can speak English at all.
  Future<bool> canSpeak() async {
    await _init();
    if (_available != null) return _available!;
    var ok = _voices.isNotEmpty;
    try {
      final r = await _tts.isLanguageAvailable(storyLocale);
      ok = ok || r == true || r == 1;
    } catch (_) {}
    return _available = ok;
  }

  /// English voices on the phone, US first, female before male.
  Future<List<DeviceVoice>> voices() async {
    await _init();
    return _voices;
  }

  /// A short, friendly name like "US · Male 2".
  String label(DeviceVoice v, {required String male, required String female}) {
    final same = _voices.where((o) => o.region == v.region && o.male == v.male).toList();
    final n = same.indexOf(v) + 1;
    return '${v.region} · ${v.male ? male : female}${same.length > 1 ? ' $n' : ''}';
  }

  /// The voice [c] will speak with: the reader's pick if it is still on the
  /// phone, otherwise one of the right gender. Characters of the same gender
  /// take turns through the main accent's voices so they don't all sound alike.
  DeviceVoice? voiceFor(Story story, Character c, {bool automatic = false}) {
    if (_voices.isEmpty) return null;
    final pick = automatic ? null : chosen?.call(story, c);
    if (pick != null) {
      for (final v in _voices) {
        if (v.name == pick) return v;
      }
    }
    final main = _voices.where((v) => v.region == _voices.first.region).toList();
    final same = main.where((v) => v.male == c.male).toList();
    final pool = same.isNotEmpty ? same : main;
    final peers = story.characters.values.where((o) => o.male == c.male && o.id != 'everyone').toList();
    final i = peers.indexWhere((o) => o.id == c.id);
    return pool[(i < 0 ? 0 : i) % pool.length];
  }

  /// When a character has to borrow a voice of the other gender, push the
  /// pitch further so they still sound like who they are.
  double pitchFor(Character c, DeviceVoice? v) {
    var p = c.pitch;
    if (v != null && v.male != c.male) p *= c.male ? 0.85 : 1.15;
    return p.clamp(0.5, 2.0);
  }

  /// Says one line. Returns false if it was cut short by [stop].
  Future<bool> say(Story story, Line line, {DeviceVoice? voice}) async {
    await _init();
    final session = _session;
    final who = line.who == 'everyone' ? 'narrator' : line.who;
    final c = story.speaker(line.who);
    final v = voice ?? voiceFor(story, story.speaker(who));
    try {
      await _tts.setLanguage(v?.locale ?? storyLocale);
      if (v != null) await _tts.setVoice(v.asMap);
      await _tts.setPitch(pitchFor(c, v));
      await _tts.setSpeechRate(c.rate);
      if (session != _session) return false;
      await _tts.speak(line.text);
    } catch (e) {
      debugPrint('Narrator: $e');
    }
    return session == _session;
  }

  /// Stops speaking at once; any [say] in progress reports it was cut short.
  Future<void> stop() async {
    _session++;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
