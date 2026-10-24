import 'package:flutter/material.dart';

import 'narrator.dart';
import 'reader_screen.dart';
import 'settings.dart';
import 'story.dart';
import 'ui_text.dart';

/// The story shelf: one card per bundled story.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.narrator, this.stories});

  final Settings settings;
  final Narrator narrator;

  /// For tests: stories already loaded.
  final List<Story>? stories;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Story>> _stories = widget.stories != null
      ? Future.value(widget.stories)
      : Future.wait(storyFolders.map(Story.load));

  @override
  Widget build(BuildContext context) {
    final lang = widget.settings.lang;
    final t = T(lang);
    return Scaffold(
      backgroundColor: deskColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories, color: Color(0xFFFFD34D), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.appName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                        Text(t.shelf, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  SegmentedButton<Lang>(
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.white,
                      selectedForegroundColor: deskColor,
                      selectedBackgroundColor: const Color(0xFFFFD34D),
                    ),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: Lang.th, label: Text('ไทย')),
                      ButtonSegment(value: Lang.en, label: Text('English')),
                    ],
                    selected: {lang},
                    onSelectionChanged: (s) => setState(() => widget.settings.lang = s.first),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Story>>(
                future: _stories,
                builder: (context, snap) {
                  final list = snap.data;
                  if (list == null) return const Center(child: CircularProgressIndicator());
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    children: [for (final s in list) _card(s, lang)],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Story s, Lang lang) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Material(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            elevation: 6,
            child: InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReaderScreen(story: s, settings: widget.settings, narrator: widget.narrator),
                  ),
                );
                if (mounted) setState(() {});
              },
              child: SizedBox(
                width: h * 0.82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Image.asset(s.imagePath(0), fit: BoxFit.cover)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title.of(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF3B2B25)),
                          ),
                          Text(
                            '${s.origin.of(lang)} · ${T(lang).pages(s.pages.length - 1)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF7A6A60)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
