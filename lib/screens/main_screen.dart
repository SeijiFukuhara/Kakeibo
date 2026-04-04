import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'analysis_screen.dart';
import 'category_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _calendarKey = GlobalKey<CalendarScreenState>();
  final _analysisKey = GlobalKey<AnalysisScreenState>();

  late final List<Widget> _screens;

  void _navigateToAnalysis(DateTime month) {
    setState(() => _currentIndex = 1);
    _analysisKey.currentState?.reloadAndSetMonth(month);
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      CalendarScreen(key: _calendarKey, onNavigateToAnalysis: _navigateToAnalysis),
      AnalysisScreen(key: _analysisKey),
      const CategorySettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // 設定タブから離れるときカレンダーの設定を再読み込み
          if (_currentIndex == 2) {
            _calendarKey.currentState?.reloadSettings();
          }
          setState(() => _currentIndex = index);
          if (index == 1) {
            _analysisKey.currentState?.reload();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '分析',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
