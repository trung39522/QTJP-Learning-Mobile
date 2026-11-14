import 'package:flutter/material.dart';

import '../core/widgets/kyuto_scaffold.dart';

import '../core/widgets/qtjp_app_header.dart';
import '../screens/home/home_screen.dart';
import '../screens/exam/exam_screen.dart';
import '../screens/learning/learning_screen.dart';
import '../screens/dictionary/dictionary_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String _selectedLevel = 'N5';
  bool _examOpened = false;
  bool _lookupOpened = false;
  bool _examTaking = false;
  bool _accountMenuOpen = false;

  void _changeLevel(String level) => setState(() => _selectedLevel = level);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop &&
            _selectedIndex != 0 &&
            !_examTaking &&
            !_accountMenuOpen) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: KyutoScaffold(
        appBar: QTJPAppHeader(
          accountActionsEnabled: !_examTaking,
          onMenuVisibilityChanged: (open) {
            if (mounted) setState(() => _accountMenuOpen = open);
          },
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              selectedLevel: _selectedLevel,
              onLevelChanged: _changeLevel,
              onStartLearning: () => setState(() => _selectedIndex = 1),
            ),
            LearningScreen(
              selectedLevel: _selectedLevel,
              onLevelChanged: _changeLevel,
            ),
            if (_lookupOpened)
              const DictionaryScreen(embedded: true)
            else
              const SizedBox.shrink(),
            if (_examOpened)
              ExamScreen(
                embedded: true,
                initialLevel: _selectedLevel,
                onLevelChanged: _changeLevel,
                onTakingChanged: (value) {
                  if (mounted) setState(() => _examTaking = value);
                },
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (_examTaking && index != 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Dùng nút quay lại trong mục Luyện đề để về danh sách trước khi đổi mục.',
                  ),
                ),
              );
              return;
            }
            setState(() {
              _selectedIndex = index;
              if (index == 2) _lookupOpened = true;
              if (index == 3) _examOpened = true;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_rounded),
              label: 'Học tập',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: 'Tra cứu',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_rounded),
              label: 'Luyện đề',
            ),
          ],
        ),
      ),
    );
  }
}
