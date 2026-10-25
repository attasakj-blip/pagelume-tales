// Renders the shelf and some book spreads to build/shots/*.png, so the
// layout can be checked by eye (and shown in the README).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagelume_tales/home_screen.dart';
import 'package:pagelume_tales/narrator.dart';
import 'package:pagelume_tales/reader_screen.dart';
import 'package:pagelume_tales/settings.dart';
import 'package:pagelume_tales/story.dart';
import 'package:pagelume_tales/story_pages.dart';
import 'package:pagelume_tales/ui_strings.g.dart';
import 'package:pagelume_tales/ui_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  late Story story;

  setUpAll(() async {
    await _font('Mali', ['assets/fonts/Mali-Regular.ttf', 'assets/fonts/Mali-SemiBold.ttf']);
    final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _font('MaterialIcons', [icons.path]);
    story = Story.parse('assets/stories/turnip', File('assets/stories/turnip/story.json').readAsStringSync());
  });

  test('every page has a picture and words', () {
    expect(story.pages.length, 10);
    for (final p in story.pages) {
      expect(File('assets/stories/turnip/${p.image}').existsSync(), isTrue);
      expect(p.lines, isNotEmpty);
      for (final line in p.lines) {
        expect(story.characters.containsKey(line.who), isTrue, reason: line.who);
      }
    }
  });

  test('menu words exist in all 23 languages', () {
    expect(uiLanguageNames.length, 23);
    for (final code in uiLanguageNames.keys) {
      final t = T(code);
      expect(t.listen, isNotEmpty);
      expect(t.pages(9), contains('9'));
    }
    expect(T.codeFor(const Locale('th', 'TH')), 'th');
    expect(T.codeFor(const Locale('zh', 'TW')), 'zh_Hant');
    expect(T.codeFor(const Locale('sw')), 'en');
  });

  test('chosen voice is used and remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    settings.setVoice('turnip', 'grandpa', 'en-us-x-iom-local');
    final again = await Settings.load();
    expect(again.voiceFor('turnip', 'grandpa'), 'en-us-x-iom-local');
    expect(again.voiceFor('turnip', 'grandma'), isNull);
  });

  test('male voices are recognised', () {
    expect(guessMale('en-us-x-iom-local', ''), isTrue);
    expect(guessMale('en-us-x-sfg-local', ''), isFalse);
    expect(guessMale('th-th-x-mol-local', ''), isFalse);
    expect(guessMale('English Male', ''), isTrue);
    expect(guessMale('English Female', ''), isFalse);
  });

  testWidgets('screens', (tester) async {
    SharedPreferences.setMockInitialValues({'autoTurn': true});
    final settings = await tester.runAsync(Settings.load) as Settings;
    final narrator = Narrator();
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final pages = StoryPages(story, load: (p) async => File(p).readAsBytesSync());
    await tester.runAsync(pages.loadPictures);
    final key = GlobalKey();
    Widget app(Widget home) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: T.localeOf(settings.uiLang ?? 'en'),
        supportedLocales: T.codes.map(T.localeOf),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: const Color(0xFF7B3FA0), useMaterial3: true, fontFamily: 'Mali'),
        home: home,
      ),
    );

    // Shelf (needs the cover asset; precache it from disk).
    settings.uiLang = 'th';
    final cover = FileImage(File('assets/stories/turnip/p00.png'));
    await tester.pumpWidget(app(HomeScreen(settings: settings, narrator: narrator, stories: [story], cover: (_) => cover)));
    await tester.runAsync(() async {
      await precacheImage(cover, tester.element(find.byType(HomeScreen)));
    });
    await tester.pumpAndSettle();
    await _shot(tester, key, 'shelf');

    for (final (code, page, hl) in [('th', 0, null), ('ja', 7, 3), ('en', 9, null), ('ar', 4, 1)]) {
      settings.uiLang = code;
      settings.setLastPage(story.id, page);
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pumpWidget(app(ReaderScreen(story: story, settings: settings, narrator: narrator, pages: pages)));
      pages.highlight(hl == null ? null : page, hl ?? 0);
      await tester.pump();
      await _shot(tester, key, 'spread_${page}_$code${hl == null ? '' : '_reading'}');
    }

    // Mid-turn.
    pages.highlight(null);
    final g = await tester.startGesture(const Offset(760, 250));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-28, -4));
      await tester.pump();
    }
    await _shot(tester, key, 'turning');
    await g.up();
    await tester.pumpAndSettle();
  });
}
