import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'book_painter.dart';
import 'narrator.dart';
import 'settings.dart';
import 'story.dart';
import 'story_pages.dart';
import 'ui_text.dart';

const deskColor = Color(0xFF2E2347);

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.story, required this.settings, required this.narrator, this.pages});

  final Story story;
  final Settings settings;
  final Narrator narrator;

  /// For tests: pages whose pictures are already loaded.
  final StoryPages? pages;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with TickerProviderStateMixin {
  late final StoryPages _pages = widget.pages ?? StoryPages(widget.story);
  late final List<Spread> _spreads = [
    for (var p = 0; p < widget.story.pages.length; p++) Spread(pictureOf(p), textOf(p)),
  ];
  late int _index = widget.settings.lastPage(widget.story.id).clamp(0, _spreads.length - 1);

  Settings get _settings => widget.settings;
  Story get _story => widget.story;
  T get _t => textFor(_settings.uiLang);

  // Page-turn state (same feel as Pagelume).
  BookLayout? _layout;
  FlipState? _flip;
  int _dragDir = 0;
  bool _bottom = true;
  Offset _dragStart = Offset.zero;
  Offset _cornerStart = Offset.zero;
  late final AnimationController _anim;
  Offset _animFrom = Offset.zero;
  Offset _animTo = Offset.zero;
  VoidCallback? _onAnimDone;
  Completer<void>? _turnDone;

  // Reading aloud.
  bool _playing = false;
  bool _autoTurning = false;
  int _readToken = 0;
  AudioPlayer? _flipPlayer;

  @override
  void initState() {
    super.initState();
    if (widget.pages == null) _pages.loadPictures();
    _anim = AnimationController(vsync: this)
      ..addListener(_tickAnim)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finishAnim();
      });
  }

  @override
  void dispose() {
    _readToken++;
    widget.narrator.stop();
    WakelockPlus.disable().catchError((_) {});
    _anim.dispose();
    _flipPlayer?.dispose();
    if (widget.pages == null) _pages.dispose();
    super.dispose();
  }

  bool get _hasNext => _index < _spreads.length - 1;
  bool get _hasPrev => _index > 0;

  void _playFlipSound() {
    if (!_settings.flipSound) return;
    try {
      final p = _flipPlayer ??= AudioPlayer()
        ..setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none, usageType: AndroidUsageType.game),
          ),
        );
      p.stop().then((_) => p.play(AssetSource('sounds/flip.wav'), volume: 0.7)).catchError((_) {});
    } catch (_) {}
  }

  // ----------------------------------------------------------- reading ---

  Future<void> _startReading() async {
    final token = ++_readToken;
    if (!await widget.narrator.canSpeak()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t.noVoice), duration: const Duration(seconds: 8)));
      return;
    }
    setState(() => _playing = true);
    WakelockPlus.enable().catchError((_) {});
    while (mounted && token == _readToken) {
      final page = _index;
      final lines = _story.pages[page].lines;
      for (var i = 0; i < lines.length; i++) {
        _pages.highlight(page, i);
        final finished = await widget.narrator.say(_story, lines[i]);
        if (!finished || token != _readToken || !mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (token != _readToken || !mounted) return;
      }
      _pages.highlight(null);
      if (!_settings.autoTurn || !_hasNext) break;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (token != _readToken || !mounted) return;
      _autoTurning = true;
      await _turnAndWait(true);
      _autoTurning = false;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (mounted && token == _readToken) _stopReading();
  }

  void _stopReading() {
    _readToken++;
    widget.narrator.stop();
    _pages.highlight(null);
    WakelockPlus.disable().catchError((_) {});
    if (mounted) setState(() => _playing = false);
  }

  // -------------------------------------------------------- page turns ---

  double _dragScale(BookLayout l, double screenWidth) => math.max(1.0, (2 * l.pageWidth) / math.max(1.0, screenWidth * 0.9));

  void _onDragStart(Offset pos) {
    if (_anim.isAnimating || _layout == null) return;
    _dragDir = 0;
    _dragStart = pos;
    _bottom = pos.dy > _layout!.right.center.dy;
  }

  void _onDragUpdate(Offset pos, double screenWidth) {
    final l = _layout;
    if (l == null || _anim.isAnimating) return;
    if (_dragDir == 0) {
      final dx = pos.dx - _dragStart.dx;
      if (dx < -2 && _hasNext) {
        _dragDir = -1;
        _cornerStart = l.corner(_bottom);
      } else if (dx > 2 && _hasPrev) {
        _dragDir = 1;
        _cornerStart = l.turnedCorner(_bottom);
      } else {
        return;
      }
    }
    final k = _dragScale(l, screenWidth);
    final p = l.clampCorner(_cornerStart + (pos - _dragStart) * k, _bottom);
    setState(() => _flip = _flipWith(p));
  }

  FlipState _flipWith(Offset corner) {
    final forward = _dragDir < 0;
    final from = forward ? _spreads[_index] : _spreads[_index - 1];
    final to = forward ? _spreads[_index + 1] : _spreads[_index];
    return FlipState(from: from, to: to, corner: corner, bottom: _bottom);
  }

  void _onDragEnd(Velocity velocity) {
    final l = _layout;
    final f = _flip;
    if (l == null || f == null || _dragDir == 0) {
      _dragDir = 0;
      return;
    }
    final vx = velocity.pixelsPerSecond.dx;
    final pastSpine = f.corner.dx < l.spineX;
    if (_dragDir < 0) {
      final complete = vx < -250 || (pastSpine && vx < 400);
      if (complete) _playFlipSound();
      _animateCorner(complete ? l.turnedCorner(_bottom) : l.corner(_bottom), () {
        if (complete) _index++;
      });
    } else {
      final complete = vx > 250 || (!pastSpine && vx > -400);
      if (complete) _playFlipSound();
      _animateCorner(complete ? l.corner(_bottom) : l.turnedCorner(_bottom), () {
        if (complete) _index--;
      });
    }
  }

  void _animateCorner(Offset target, VoidCallback onDone) {
    final l = _layout!;
    _animFrom = _flip!.corner;
    _animTo = target;
    _onAnimDone = onDone;
    final dist = (_animTo - _animFrom).distance / (2 * l.pageWidth);
    _anim.duration = Duration(milliseconds: (160 + 640 * dist).round());
    _anim.forward(from: 0);
  }

  void _tickAnim() {
    final l = _layout;
    if (l == null || _flip == null) return;
    final t = Curves.easeInOutCubic.transform(_anim.value);
    var p = Offset.lerp(_animFrom, _animTo, t)!;
    final lift = math.sin(math.pi * t) * l.right.height * 0.08 * (_bottom ? -1 : 1);
    p = l.clampCorner(p + Offset(0, lift), _bottom);
    setState(() => _flip = FlipState(from: _flip!.from, to: _flip!.to, corner: p, bottom: _bottom));
  }

  void _finishAnim() {
    final before = _index;
    setState(() {
      _onAnimDone?.call();
      _onAnimDone = null;
      _flip = null;
      _dragDir = 0;
    });
    _settings.setLastPage(_story.id, _index);
    _turnDone?.complete();
    _turnDone = null;
    // The reader turned the page by hand while listening: read the new page.
    if (_playing && !_autoTurning && before != _index) _startReading();
  }

  void _turn(bool forward) {
    final l = _layout;
    if (l == null || _anim.isAnimating || _flip != null) return;
    if (forward ? !_hasNext : !_hasPrev) return;
    _bottom = true;
    _dragDir = forward ? -1 : 1;
    final start = forward ? l.corner(true) : l.turnedCorner(true);
    setState(() => _flip = _flipWith(start));
    _playFlipSound();
    _animateCorner(forward ? l.turnedCorner(true) : l.corner(true), () {
      _index += forward ? 1 : -1;
    });
  }

  Future<void> _turnAndWait(bool forward) {
    final c = _turnDone = Completer<void>();
    _turn(forward);
    if (_flip == null) {
      _turnDone = null;
      return Future.value();
    }
    return c.future;
  }

  void _restart() {
    _stopReading();
    setState(() => _index = 0);
    _settings.setLastPage(_story.id, 0);
  }

  // ------------------------------------------------------------------ UI ---

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: deskColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(t),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  final layout = _layout = BookLayout.compute(size, _story.pageAspect, true);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) => _onDragStart(d.localPosition),
                    onHorizontalDragUpdate: (d) => _onDragUpdate(d.localPosition, size.width),
                    onHorizontalDragEnd: (d) => _onDragEnd(d.velocity),
                    onTapUp: (d) => _turn(d.localPosition.dx > layout.spineX),
                    child: CustomPaint(
                      size: size,
                      painter: BookPainter(cache: _pages, layout: layout, spread: _spreads[_index], flip: _flip),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(T t) {
    const fg = Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: fg),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.home_rounded),
            label: Text(t.shelf),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _story.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: t.autoTurn,
            color: _settings.autoTurn ? const Color(0xFFFFD34D) : fg.withValues(alpha: 0.6),
            icon: Icon(_settings.autoTurn ? Icons.auto_stories : Icons.auto_stories_outlined),
            onPressed: () => setState(() => _settings.autoTurn = !_settings.autoTurn),
          ),
          IconButton(
            tooltip: t.flipSound,
            color: fg,
            icon: Icon(_settings.flipSound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            onPressed: () => setState(() => _settings.flipSound = !_settings.flipSound),
          ),
          IconButton(tooltip: t.voices, color: fg, icon: const Icon(Icons.record_voice_over_rounded), onPressed: _showVoices),
          IconButton(tooltip: t.fromStart, color: fg, icon: const Icon(Icons.first_page_rounded), onPressed: _restart),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD34D), foregroundColor: deskColor),
            onPressed: _playing ? _stopReading : _startReading,
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(_playing ? t.pause : t.listen),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoices() async {
    _stopReading();
    final voices = await widget.narrator.voices();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => VoicesSheet(story: _story, settings: _settings, narrator: widget.narrator, voices: voices),
    );
    widget.narrator.stop();
  }
}

/// Lets the reader pick a phone voice for each character and hear it.
/// Choices are saved in [Settings] and used every time the story is read.
class VoicesSheet extends StatefulWidget {
  const VoicesSheet({super.key, required this.story, required this.settings, required this.narrator, required this.voices});

  final Story story;
  final Settings settings;
  final Narrator narrator;
  final List<DeviceVoice> voices;

  @override
  State<VoicesSheet> createState() => _VoicesSheetState();
}

class _VoicesSheetState extends State<VoicesSheet> {
  Future<void> _preview(Character c) async {
    await widget.narrator.stop();
    final sample = widget.story.pages
        .expand((p) => p.lines)
        .firstWhere((l) => l.who == c.id && !l.moral, orElse: () => Line(c.id, 'Hello, I am ${c.name}.'));
    await widget.narrator.say(widget.story, sample);
  }

  @override
  Widget build(BuildContext context) {
    final t = textFor(widget.settings.uiLang);
    final n = widget.narrator;
    String name(DeviceVoice v) => n.label(v, male: t.male, female: t.female);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(t.voices, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(t.voicesNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final c in widget.story.cast)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: c.color,
                      child: Text(c.name.characters.first, style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(t.voiceType(c.voice), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    DropdownButton<String?>(
                      value: widget.voices.any((v) => v.name == widget.settings.voiceFor(widget.story.id, c.id))
                          ? widget.settings.voiceFor(widget.story.id, c.id)
                          : null,
                      onChanged: (v) {
                        setState(() => widget.settings.setVoice(widget.story.id, c.id, v));
                        _preview(c);
                      },
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            '${t.automatic}${n.voiceFor(widget.story, c, automatic: true) == null ? '' : ' (${name(n.voiceFor(widget.story, c, automatic: true)!)})'}',
                          ),
                        ),
                        for (final v in widget.voices) DropdownMenuItem<String?>(value: v.name, child: Text(name(v))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 36),
                      color: c.color,
                      onPressed: () => _preview(c),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
