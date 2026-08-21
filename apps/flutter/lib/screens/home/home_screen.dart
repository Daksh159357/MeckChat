import 'package:flutter/material.dart';
import '../devices/devices_screen.dart';
import '../pairing/pairing_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DevicesScreen(),
    PairingScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.grey.shade900,
        items: const [
          BottomNavigationBarViewItem(icon: Icon(Icons.devices), label: 'Devices'),
          BottomNavigationBarViewItem(icon: Icon(Icons.qr_code_scanner), label: 'Pairing'),
          BottomNavigationBarViewItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class BottomNavigationBarViewItem extends BottomNavigationBarItem {
  const BottomNavigationBarViewItem({required super.icon, required super.label});
}
