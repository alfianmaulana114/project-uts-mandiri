import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'home_content_screen.dart';
import '../../weather/screens/weather_screen.dart';
import '../../todo/screens/todo_screen.dart';
import '../../note/screens/note_screen.dart';
import '../../archive/screens/archive_screen.dart';

/// Halaman utama aplikasi dengan bottom navigation bar
/// Menggunakan bottom navigation untuk navigasi antara Home, Cuaca, Tugas, Catatan, dan Arsip
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // List halaman yang akan ditampilkan di bottom navigation
  // Home (index 0), Cuaca (index 1), Tugas (index 2), Catatan (index 3), Arsip (index 4)
  final List<Widget> _pages = [
    const HomeContentScreen(),
    const WeatherScreen(),
    const TodoScreen(),
    const NoteScreen(),
    const ArchiveScreen(),
  ];

  /// Mengubah halaman yang sedang ditampilkan
  /// [index] adalah index dari halaman yang dipilih
  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        backgroundColor: AppTheme.sidebarBg,
        selectedItemColor: AppTheme.accentBlue,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            activeIcon: Icon(Icons.wb_sunny),
            label: 'Cuaca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_outlined),
            activeIcon: Icon(Icons.note),
            label: 'Catatan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.archive_outlined),
            activeIcon: Icon(Icons.archive),
            label: 'Arsip',
          ),
        ],
      ),
    );
  }
}

