import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'book_painter.dart';
import 'story.dart';

/// Book page numbering: story page p has its picture on book page 2p (left)
/// and its words on book page 2p + 1 (right).
int pictureOf(int storyPage) => storyPage * 2;
int textOf(int storyPage) => storyPage * 2 + 1;

const pagePixels = 1024;
const paperColor = Color(0xFFFFFBF0);

/// Hands the page-turn painter the picture and text pages of one story.
/// Text pages are drawn here, in the current language, with the line being
/// read aloud highlighted.
class StoryPages extends ChangeNotifier implements PageImageSource {
  StoryPages(this.story, {Future<Uint8List> Function(String path)? load}) : _load = load ?? _bundle;

  final Story story;
  final Future<Uint8List> Function(String path) _load;
  final Map<int, ui.Image> _pictures = {};
  final Map<int, ui.Image> _texts = {};
  Lang _lang = Lang.th;
  (int, int)? _highlight;
  bool _disposed = false;

  static Future<Uint8List> _bundle(String path) async => (await rootBundle.load(path)).buffer.asUint8List();

  int get pageCount => story.pages.length * 2;
  Lang get lang => _lang;

  @override
  ui.Image? image(int? index) {
    if (index == null || index < 0 || index >= pageCount) return null;
    final p = index ~/ 2;
    if (index.isEven) return _pictures[p];
    return _texts[p] ??= _renderText(p);
  }

  /// Loads every picture (a story is only a few pages).
  Future<void> loadPictures() async {
    for (var p = 0; p < story.pages.length; p++) {
      if (_pictures.containsKey(p)) continue;
      final codec = await ui.instantiateImageCodec(await _load(story.imagePath(p)));
      final frame = await codec.getNextFrame();
      if (_disposed) return;
      _pictures[p] = frame.image;
      notifyListeners();
    }
  }

  void setLang(Lang l) {
    if (l == _lang) return;
    _lang = l;
    _clearTexts();
    notifyListeners();
  }

  /// Highlights line [line] on story page [page], or nothing with null.
  void highlight(int? page, [int line = 0]) {
    final next = page == null ? null : (page, line);
    if (next == _highlight) return;
    final old = _highlight;
    _highlight = next;
    for (final p in {old?.$1, next?.$1}.whereType<int>()) {
      _texts.remove(p)?.dispose();
    }
    notifyListeners();
  }

  void _clearTexts() {
    for (final i in _texts.values) {
      i.dispose();
    }
    _texts.clear();
  }

  ui.Image _renderText(int p) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintTextPage(canvas, const Size.square(pagePixels * 1.0), story, p, _lang, _highlight?.$1 == p ? _highlight!.$2 : null);
    final pic = recorder.endRecording();
    final img = pic.toImageSync(pagePixels, pagePixels);
    pic.dispose();
    return img;
  }

  @override
  void dispose() {
    _disposed = true;
    _clearTexts();
    for (final i in _pictures.values) {
      i.dispose();
    }
    super.dispose();
  }
}

const _ink = Color(0xFF3B2B25);
const _font = 'Mali';

/// Draws the words of story page [p]: narration as plain paragraphs, speech
/// with the speaker's name in their colour, the moral in a box.
void paintTextPage(Canvas canvas, Size size, Story story, int p, Lang lang, int? highlight) {
  final w = size.width;
  canvas.drawRect(Offset.zero & size, Paint()..color = paperColor);
  // A soft frame, like a printed picture book.
  final frame = RRect.fromRectAndRadius((Offset.zero & size).deflate(w * 0.035), Radius.circular(w * 0.03));
  canvas.drawRRect(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.004
      ..color = const Color(0xFFD9B98C),
  );
  for (final c in [frame.outerRect.topLeft, frame.outerRect.topRight, frame.outerRect.bottomLeft, frame.outerRect.bottomRight]) {
    canvas.drawCircle(c, w * 0.012, Paint()..color = const Color(0xFFE8A54B));
  }

  final page = story.pages[p];
  if (page.cover) {
    _paintCover(canvas, size, story, lang);
    return;
  }

  final lines = page.lines[lang] ?? const <Line>[];
  final margin = w * 0.1;
  final textWidth = w - margin * 2;
  final maxHeight = size.height - margin * 2 - w * 0.05;
  var fontSize = w * 0.05;
  late List<TextPainter> blocks;
  late double gap;
  while (true) {
    gap = fontSize * 0.7;
    blocks = [for (final l in lines) _block(story, l, lang, fontSize, textWidth)];
    final total = blocks.fold<double>(0, (s, b) => s + b.height) + gap * math.max(0, blocks.length - 1);
    if (total <= maxHeight || fontSize < w * 0.025) {
      var y = margin + math.max(0, (maxHeight - total) / 2);
      for (var i = 0; i < blocks.length; i++) {
        final b = blocks[i];
        final l = lines[i];
        final box = Rect.fromLTWH(margin - fontSize * 0.4, y - fontSize * 0.25, textWidth + fontSize * 0.8, b.height + fontSize * 0.5);
        if (l.moral) {
          canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(fontSize * 0.6)), Paint()..color = const Color(0xFFEAF5E1));
        }
        if (i == highlight) {
          canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(fontSize * 0.6)), Paint()..color = const Color(0xFFFFE89A));
        }
        b.paint(canvas, Offset(margin + (l.moral ? (textWidth - b.width) / 2 : 0), y));
        y += b.height + gap;
      }
      break;
    }
    fontSize *= 0.92;
  }

  final num = TextPainter(
    text: TextSpan(text: '$p', style: TextStyle(fontFamily: _font, fontSize: w * 0.03, color: _ink.withValues(alpha: 0.45))),
    textDirection: TextDirection.ltr,
  )..layout();
  num.paint(canvas, Offset((w - num.width) / 2, size.height - w * 0.085));
}

TextPainter _block(Story story, Line l, Lang lang, double fontSize, double width) {
  final c = story.speaker(l.who);
  final base = TextStyle(fontFamily: _font, fontSize: fontSize, height: 1.45, color: _ink);
  final InlineSpan span;
  if (l.moral) {
    span = TextSpan(text: l.text, style: base.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)));
  } else if (c.isNarrator) {
    span = TextSpan(text: l.text, style: base);
  } else {
    const q = ('“', '”');
    span = TextSpan(
      children: [
        TextSpan(text: '${c.name.of(lang)}: ', style: base.copyWith(fontWeight: FontWeight.w600, color: c.color)),
        TextSpan(text: '${q.$1}${l.text}${q.$2}', style: base.copyWith(color: Color.lerp(c.color, _ink, 0.55))),
      ],
    );
  }
  return TextPainter(text: span, textDirection: TextDirection.ltr, textAlign: l.moral ? TextAlign.center : TextAlign.left)
    ..layout(maxWidth: width);
}

void _paintCover(Canvas canvas, Size size, Story story, Lang lang) {
  final w = size.width;
  TextPainter tp(String s, double fs, Color color, {FontWeight weight = FontWeight.w400}) => TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: _font, fontSize: fs, color: color, fontWeight: weight, height: 1.3)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: w * 0.8);

  final title = tp(story.title.of(lang), w * 0.1, const Color(0xFF7B3FA0), weight: FontWeight.w600);
  final origin = tp(story.origin.of(lang), w * 0.045, _ink.withValues(alpha: 0.7));
  final hint = tp(lang == Lang.th ? 'แตะ ▶ เพื่อฟังนิทาน\nหรือปัดเพื่อเปิดหน้าถัดไป' : 'Tap ▶ to hear the story,\nor swipe to turn the page', w * 0.035, _ink.withValues(alpha: 0.55));
  var y = size.height * 0.3 - title.height / 2;
  title.paint(canvas, Offset((w - title.width) / 2, y));
  y += title.height + w * 0.04;
  canvas.drawLine(Offset(w * 0.38, y), Offset(w * 0.62, y), Paint()
    ..color = const Color(0xFFE8A54B)
    ..strokeWidth = w * 0.006
    ..strokeCap = StrokeCap.round);
  y += w * 0.05;
  origin.paint(canvas, Offset((w - origin.width) / 2, y));
  hint.paint(canvas, Offset((w - hint.width) / 2, size.height * 0.78));
}
