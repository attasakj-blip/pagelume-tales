import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_screen.dart';
import 'narrator.dart';
import 'settings.dart';
import 'ui_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Picture on the left, words on the right: the book needs a wide screen.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final settings = await Settings.load();
  final narrator = Narrator()..chosen = (story, c) => settings.voiceFor(story.id, c.id);
  runApp(TalesApp(settings: settings, narrator: narrator));
}

class TalesApp extends StatelessWidget {
  const TalesApp({super.key, required this.settings, required this.narrator});

  final Settings settings;
  final Narrator narrator;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: T.appName,
        debugShowCheckedModeBanner: false,
        locale: T.localeOf(textFor(settings.uiLang).code),
        supportedLocales: T.codes.map(T.localeOf),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2A6FD6), useMaterial3: true, fontFamily: 'Mali'),
        home: HomeScreen(settings: settings, narrator: narrator),
      ),
    );
  }
}
