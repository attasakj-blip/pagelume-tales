import 'package:flutter/material.dart';

import 'narrator.dart';
import 'reader_screen.dart';
import 'settings.dart';
import 'story.dart';
import 'ui_strings.g.dart';
import 'ui_text.dart';

/// The story shelf: one card per bundled story. The reader always comes
/// back here from a book and can pick another one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.narrator, this.stories, this.cover});

  final Settings settings;
  final Narrator narrator;

  /// For tests: stories already loaded, and how to show a cover.
  final List<Story>? stories;
  final ImageProvider Function(Story s)? cover;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Story>> _stories = widget.stories != null
      ? Future.value(widget.stories)
      : Future.wait(storyFolders.map(Story.load));

  @override
  Widget build(BuildContext context) {
    final t = textFor(widget.settings.uiLang);
    return Scaffold(
      backgroundColor: deskColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/icon_512.png', width: 44, height: 44, errorBuilder: (_, _, _) => const SizedBox(width: 44)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(T.appName, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                        Text(
                          '${t.shelf} · ${t.storiesInEnglish}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  _languageMenu(t),
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
                    children: [for (final s in list) _card(s, t), _comingSoon(t)],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageMenu(T t) {
    return PopupMenuButton<String>(
      tooltip: t.language,
      onSelected: (code) => setState(() => widget.settings.uiLang = code == '' ? null : code),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: '', checked: widget.settings.uiLang == null, child: Text(t.phoneLanguage)),
        const PopupMenuDivider(),
        for (final e in uiLanguageNames.entries)
          CheckedPopupMenuItem(value: e.key, checked: widget.settings.uiLang == e.key, child: Text(e.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: Colors.white),
            const SizedBox(width: 6),
            Text(uiLanguageNames[t.code]!, style: const TextStyle(color: Colors.white)),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _card(Story s, T t) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 20),
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
                width: h * 0.9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Image(image: widget.cover?.call(s) ?? AssetImage(s.imagePath(0)), fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF3B2B25)),
                          ),
                          Text(
                            '${s.origin} · ${t.pages(s.pages.length - 1)}',
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

  Widget _comingSoon(T t) {
    return LayoutBuilder(
      builder: (context, c) => Container(
        width: c.maxHeight * 0.6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(t.moreSoon, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
