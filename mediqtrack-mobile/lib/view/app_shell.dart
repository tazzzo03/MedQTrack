// lib/view/app_shell.dart
import 'package:flutter/material.dart';
import 'theme.dart';
import 'home_page.dart';
import 'my_queue_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'auth/auth_gate.dart';
import 'splash_screen.dart';

class MediQTrackApp extends StatelessWidget {
  const MediQTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediQTrack',
      theme: buildMediTheme(),
      home: const SplashScreen(), // <-- start with splash
    );
  }
}

// Shell utama untuk tab bawah (public supaya boleh navigate)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _index = 0;
    _pages = [
      HomePage(
        onTabSelect: (i) => setState(() => _index = i),
      ),
      const MyQueuePage(),
      const NotificationsPage(),
      ProfilePage(), // ❌ jangan const sebab dah StatefulWidget
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: 'My Queue'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
