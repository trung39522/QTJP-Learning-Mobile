import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/app_shell.dart';
import 'core/navigation/app_routes.dart';
import 'core/storage/session_store.dart';
import 'core/theme/qtjp_theme.dart';
import 'screens/alphabet/alphabet_screen.dart';
import 'screens/assistant/assistant_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dictionary/dictionary_screen.dart';
import 'screens/exam/exam_screen.dart';
import 'screens/flashcard/flashcard_screen.dart';
import 'screens/grammar/grammar_repository.dart';
import 'screens/grammar/grammar_screen.dart';
import 'screens/home/models/home_feature_item.dart';
import 'screens/home/widgets/jlpt_level_selector.dart';
import 'screens/learning/feature_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/video/video_screen.dart';
import 'screens/vip/vip_screen.dart';
import 'screens/writing/writing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'KanjiVG',
    ], await rootBundle.loadString('assets/alphabet/KANJIVG_LICENSE.txt'));
  });
  runApp(const QTJPMobile());
}

class QTJPMobile extends StatefulWidget {
  const QTJPMobile({this.controller, super.key});
  final AppController? controller;

  @override
  State<QTJPMobile> createState() => _QTJPMobileState();
}

class _QTJPMobileState extends State<QTJPMobile> {
  late final _controller =
      widget.controller ?? AppController(sessionStore: SecureSessionStore());

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) unawaited(_controller.restoreSession());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'QTJP Learning',
        theme: QTJPTheme.light,
        home: const AppShell(),
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.assistant: (_) => const AssistantScreen(),
          AppRoutes.notifications: (_) => const NotificationsScreen(),
          AppRoutes.vip: (_) => const VipScreen(),
        },
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri == null ||
              uri.pathSegments.length != 2 ||
              uri.pathSegments.first != 'learn') {
            return null;
          }
          final matches = homeFeatureItems.where(
            (item) => item.id == uri.pathSegments.last,
          );
          if (matches.isEmpty) return null;
          final requestedLevel = uri.queryParameters['level'];
          final level = JlptLevelSelector.levels.contains(requestedLevel)
              ? requestedLevel!
              : 'N5';
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => switch (matches.first.id) {
              'alphabet' => const AlphabetScreen(),
              'flashcard' => FlashcardScreen(initialLevel: level),
              'dictionary' => const DictionaryScreen(),
              'grammar' =>
                RegExp(r'^[1-9][0-9]{0,10}$')
                        .hasMatch(uri.queryParameters['lesson'] ?? '')
                    ? GrammarLessonScreen(
                        id: uri.queryParameters['lesson']!,
                        repository: GrammarRepository(_controller.api),
                      )
                    : GrammarScreen(initialLevel: level),
              'writing' => WritingScreen(initialLevel: level),
              'exam' => ExamScreen(initialLevel: level),
              'video' => VideoScreen(
                initialLevel: JlptLevelSelector.levels.contains(requestedLevel)
                    ? level
                    : 'ALL',
              ),
              _ => FeatureScreen(feature: matches.first, selectedLevel: level),
            },
          );
        },
      ),
    );
  }
}
