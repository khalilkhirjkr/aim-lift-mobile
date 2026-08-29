// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import all your screens
import 'screens/incident_list_screen.dart';
import 'screens/contractor_task_screen.dart';
import 'screens/lift_health_screen.dart';
import 'screens/lift_analytics_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AimLiftApp());
}

class AimLiftApp extends StatelessWidget {
  const AimLiftApp({super.key});

  // This function checks if a token is already saved
  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('authToken') ?? '';

    print("--- CheckLoginStatus ---");
    print("Token read from SharedPreferences: '$token'");

    bool isLoggedIn = token.isNotEmpty;
    print("isLoggedIn determined as: $isLoggedIn");
    print("------------------------");
    return isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIM Lift App',

      // --- ADD THIS LINE TO HIDE THE DEBUG BANNER ---
      debugShowCheckedModeBanner: false,

      // --- END ADDED LINE ---
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.black54,
          elevation: 2,
        ),
      ),

      // This FutureBuilder decides which screen to show first
      home: FutureBuilder<bool>(
        future: _checkLoginStatus(), // Runs the check
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading circle while checking
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            // If check is done:
            if (snapshot.hasData && snapshot.data == true) {
              // Token was found, go to main app
              print("==> Token found, navigating to MainScreen");
              return const MainNavigationScreen();
            } else {
              // No token found, go to login
              print("==> No token, navigating to LoginScreen");
              return const LoginScreen();
            }
          }
        },
      ),
    );
  }
}

// This widget manages the state for the bottom navigation bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    IncidentListScreen(),
    ContractorTaskScreen(),
    LiftHealthScreen(),
    LiftAnalyticsScreen(),
  ];

  static const List<String> _titles = <String>[
    'Lift Incident Log',
    'Contractor Task Monitoring',
    'Lift Health Monitoring',
    'Lift Analytics',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // This function clears the token and returns to login
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken'); // Remove the stored token
    print("Auth token removed.");
    if (mounted) {
      // Go back to login and remove all other screens
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, // This predicate removes all routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout, // Call the logout function
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Incidents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.construction),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
