import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
import '../screens/exam/exam_screen.dart';
import '../screens/learning/learning_screen.dart';
import '../screens/profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String _selectedLevel = 'N5';
  bool _examOpened = false;
  bool _examTaking = false;

  void _changeLevel(String level) => setState(() => _selectedLevel = level);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0 && !_examTaking) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
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
            if (_examOpened)
              ExamScreen(
                initialLevel: _selectedLevel,
                onLevelChanged: _changeLevel,
                onTakingChanged: (value) {
                  if (mounted) setState(() => _examTaking = value);
                },
              )
            else
              const SizedBox.shrink(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (_examTaking && index != 2) {
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
              if (index == 2) _examOpened = true;
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
              icon: Icon(Icons.fact_check_rounded),
              label: 'Luyện đề',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
