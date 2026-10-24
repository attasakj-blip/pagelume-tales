import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'narrator.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Picture on the left, words on the right: the book needs a wide screen.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final settings = await Settings.load();
  runApp(TalesApp(settings: settings, narrator: Narrator()));
}

class TalesApp extends StatelessWidget {
  const TalesApp({super.key, required this.settings, required this.narrator});

  final Settings settings;
  final Narrator narrator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pagelume Tales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7B3FA0),
        useMaterial3: true,
        fontFamily: 'Mali',
      ),
      home: HomeScreen(settings: settings, narrator: narrator),
    );
  }
}
