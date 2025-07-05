
import 'package:flutter/material.dart';
import 'package:myapp/screens/submit_screen.dart';
import 'package:myapp/screens/recent_screen.dart';
import 'package:myapp/screens/pending_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    SubmitScreen(),
    RecentScreen(),
    PendingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Enviar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending),
            label: 'Pendientes',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: isDarkMode ? Colors.white70 : Colors.grey,
        backgroundColor: isDarkMode ? Colors.grey[850] : const Color(0xFFF0F4F8),
        onTap: _onItemTapped,
      ),
    );
  }
}
