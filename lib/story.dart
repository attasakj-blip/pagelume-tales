import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

/// The two reading languages.
enum Lang { th, en }

extension LangInfo on Lang {
  String get ttsLocale => this == Lang.th ? 'th-TH' : 'en-US';
}

/// Something written in each language.
class Words {
  Words(this._byLang);
  factory Words.fromJson(Object? json) {
    final m = (json as Map?) ?? const {};
    return Words({for (final l in Lang.values) l: (m[l.name] ?? m['en'] ?? '') as String});
  }

  final Map<Lang, String> _byLang;
  String of(Lang l) => _byLang[l] ?? '';
}

/// A character and how its voice should sound on the phone's speech engine.
class Character {
  Character({
    required this.id,
    required this.name,
    required this.voice,
    required this.male,
    required this.pitch,
    required this.rate,
    required this.color,
  });

  factory Character.fromJson(String id, Map json) => Character(
    id: id,
    name: Words.fromJson(json['name']),
    voice: json['voice'] as String? ?? '',
    male: json['gender'] == 'male',
    pitch: (json['pitch'] as num?)?.toDouble() ?? 1,
    rate: (json['rate'] as num?)?.toDouble() ?? 0.45,
    color: Color(int.parse((json['color'] as String? ?? '#5d4037').substring(1), radix: 16) | 0xFF000000),
  );

  final String id;
  final Words name;

  /// One of the 8 voice types (youngWoman, oldMan, girl, ...), for the label.
  final String voice;
  final bool male;
  final double pitch;
  final double rate;
  final Color color;

  bool get isNarrator => id == 'narrator';
}

/// One line on a text page, read by one character.
class Line {
  Line(this.who, this.text, {this.moral = false});
  final String who;
  final String text;
  final bool moral;
}

class StoryPage {
  StoryPage({required this.image, required this.lines, this.cover = false});
  final String image;
  final Map<Lang, List<Line>> lines;
  final bool cover;
}

class Story {
  Story({
    required this.id,
    required this.folder,
    required this.title,
    required this.origin,
    required this.characters,
    required this.pages,
  });

  final String id;
  final String folder;
  final Words title;
  final Words origin;
  final Map<String, Character> characters;
  final List<StoryPage> pages;

  Character speaker(String id) => characters[id] ?? characters['narrator']!;

  String imagePath(int page) => '$folder/${pages[page].image}';

  static Story parse(String folder, String text) {
    final j = jsonDecode(text) as Map;
    final chars = <String, Character>{
      for (final e in (j['characters'] as Map).entries) e.key as String: Character.fromJson(e.key as String, e.value as Map),
    };
    final pages = [
      for (final p in j['pages'] as List)
        StoryPage(
          image: p['image'] as String,
          cover: p['cover'] == true,
          lines: {
            for (final l in Lang.values)
              l: [
                for (final s in (p[l.name] as List? ?? const []))
                  Line(s['who'] as String, s['text'] as String, moral: s['moral'] == true),
              ],
          },
        ),
    ];
    return Story(
      id: j['id'] as String,
      folder: folder,
      title: Words.fromJson(j['title']),
      origin: Words.fromJson(j['origin']),
      characters: chars,
      pages: pages,
    );
  }

  static Future<Story> load(String folder) async => parse(folder, await rootBundle.loadString('$folder/story.json'));
}

/// The stories bundled with the app.
const storyFolders = ['assets/stories/turnip'];
