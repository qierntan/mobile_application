import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile_application/controller/invoice_management/invoice_pdf_controller.dart';
import 'package:mobile_application/screens/Customer/customer_list_screen.dart';
import 'package:mobile_application/screens/InvoiceManagement/invoice_list_screen.dart';
import 'package:mobile_application/screens/InvoiceManagement/report.dart';
import 'package:mobile_application/screens/WorkScheduler/assigned_jobs_screen.dart';
import 'package:mobile_application/screens/login_screen.dart';
import 'package:mobile_application/screens/dashboard_screen.dart';
import 'package:mobile_application/screens/notification_screen.dart';
import 'package:mobile_application/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:mobile_application/screens/Inventory/inventory_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service
  await NotificationService().initialize();

  // Start the payment success handler with retries
  bool serverStarted = false;
  int retryCount = 0;
  const maxRetries = 3;

  while (!serverStarted && retryCount < maxRetries) {
    try {
      await InvoicePdfController.setupPaymentSuccessHandler();
      print('Payment success handler started successfully');
      serverStarted = true;
    } catch (e) {
      retryCount++;
      print(
        'Failed to start payment success handler (attempt $retryCount): $e',
      );
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: 2)); // Wait before retrying
      } else {
        print('Failed to start server after $maxRetries attempts');
      }
    }
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // Create a global navigator key for notifications
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Set the navigator key for the notification service
    NotificationService.navigatorKey = navigatorKey;

    return MaterialApp(
      title: 'Greenstem WMS',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => HomeNavigator(),
        '/invoice': (context) => InvoiceListScreen(),
        '/notifications': (context) => NotificationScreen(),
        '/payment_notification':
            (context) => NotificationScreen(
              notificationType: 'payment',
              arguments:
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?,
            ),
        '/service_notification':
            (context) => NotificationScreen(
              notificationType: 'service',
              arguments:
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?,
            ),
        '/reply_notification':
            (context) => NotificationScreen(
              notificationType: 'reply',
              arguments:
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?,
            ),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeNavigator extends StatefulWidget {
  const HomeNavigator({super.key});

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
    'Invoice',
  ];

  @override
  Widget build(BuildContext context) {
    Widget selectedScreen;

    // Load screens based on navigation index
    switch (_currentIndex) {
      case 0:
        selectedScreen = DashboardScreen();
        break;
      case 1:
        selectedScreen = CustomerListScreen();
        break;
      case 2:
        selectedScreen = AssignedJobsScreen();
        break;
      case 3:
        selectedScreen = InventoryListScreen();
        break;
      case 4:
        selectedScreen = InvoiceListScreen();
        break;
      default:
        selectedScreen = Center(
          child: Text(
            '🚧 This screen is under development.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions:
            _currentIndex == 4
                ? [
                  IconButton(
                    icon: Icon(Icons.bar_chart),
                    tooltip: 'Reports',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ReportingScreen()),
                      );
                    },
                  ),
                ]
                : null,
      ),
      body: selectedScreen,
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Invoice'),
        ],
      ),
    );
  }
}
