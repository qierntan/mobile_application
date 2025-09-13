import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile_application/screens/Customer/customer_list_screen.dart';
import 'package:mobile_application/screens/login_screen.dart';
import 'package:mobile_application/screens/dashboard_screen.dart';
import 'package:mobile_application/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workshop CRM',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      initialRoute: '/login',
      routes: {
        '/': (context) => HomeNavigator(),
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => HomeNavigator(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeNavigator extends StatefulWidget {
  @override
  _HomeNavigatorState createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends State<HomeNavigator> {
  int _currentIndex = 0; // Start on Home tab (Dashboard)
  final List<String> _titles = [
    'Home',
    'Customers',
    'Jobs',
    'Inventory',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    Widget _selectedScreen;

    // Load screens based on navigation index
    switch (_currentIndex) {
      case 0:
        _selectedScreen = DashboardScreen();
        break;
      case 1:
        _selectedScreen = CustomerListScreen();
        break;
      default:
        _selectedScreen = Center(
          child: Text(
            '🚧 This screen is under development.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex]), centerTitle: true),
      body: _selectedScreen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color.fromARGB(255, 178, 72, 249),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Jobs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
