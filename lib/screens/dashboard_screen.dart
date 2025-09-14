import 'package:flutter/material.dart';
import 'package:mobile_application/services/notification_service.dart';
import 'package:mobile_application/services/remember_me_service.dart';
import 'package:mobile_application/controller/dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Controller instance
  final DashboardController _dashboardController = DashboardController();

  // Store data for the dashboard
  int totalCustomers = 0;
  int totalMechanics = 0;
  Map<String, dynamic> invoiceStats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Load all dashboard data from Firebase
  Future<void> _loadDashboardData() async {
    try {
      // Fetch data concurrently
      final results = await Future.wait([
        _dashboardController.getTotalCustomers(),
        _dashboardController.getTotalMechanics(),
        _dashboardController.getInvoiceStatistics(),
      ]);

      setState(() {
        totalCustomers = results[0] as int;
        totalMechanics = results[1] as int;
        invoiceStats = results[2] as Map<String, dynamic>;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with welcome message and profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                      Text(
                        'Arnaud Dresco',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Notification icon
                      GestureDetector(
                        onTap: () => _showNotificationOverlay(context),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                size: 24,
                                color: Colors.grey[600],
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Profile picture
                      GestureDetector(
                        onTap: () => _showProfileOverlay(context),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: AssetImage('assets/profile.jpg'),
                          backgroundColor: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            color: Colors.grey[600],
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Dashboard title
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              SizedBox(height: 20),

              // Statistics cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total\nCustomers',
                      value: isLoading ? '...' : '$totalCustomers',
                      color: Color(0xFF5A9FD4),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total\nMechanics',
                      value: isLoading ? '...' : '$totalMechanics',
                      color: Color(0xFF5A9FD4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Sales section
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                      SizedBox(height: 10),

                      // Legend
                      Row(
                        children: [
                          _buildLegendItem('Paid', Color(0xFF4CAF50)),
                          SizedBox(width: 20),
                          _buildLegendItem('Unpaid', Color(0xFFFF7F7F)),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Chart
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            child:
                                isLoading
                                    ? CircularProgressIndicator(
                                      color: Color(0xFF5A9FD4),
                                    )
                                    : _buildPieChart(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build pie chart widget with real data
  Widget _buildPieChart() {
    final double paidPercentage = invoiceStats['paidPercentage'] ?? 0.0;
    final double unpaidPercentage = invoiceStats['unpaidPercentage'] ?? 0.0;
    final double totalEarnings = invoiceStats['totalEarnings'] ?? 0.0;
    final double paidValue = paidPercentage / 100;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Donut chart
        SizedBox(
          width: 200,
          height: 200,
          child: CircularProgressIndicator(
            value: paidValue,
            strokeWidth: 20,
            backgroundColor: Color(0xFFFF7F7F), // Unpaid color
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF4CAF50), // Paid color
            ),
          ),
        ),
        // Center text
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Total Earning:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              _dashboardController.formatCurrency(totalEarnings),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ],
        ),
        // Percentage labels (only show if there's data)
        if (paidPercentage > 0)
          Positioned(
            top: 30,
            right: 30,
            child: Text(
              _dashboardController.formatPercentage(paidPercentage),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
        if (unpaidPercentage > 0)
          Positioned(
            bottom: 30,
            left: 30,
            child: Text(
              _dashboardController.formatPercentage(unpaidPercentage),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7F7F),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2E2E2E),
              height: 1.2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  void _showNotificationOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: EdgeInsets.only(top: 80, right: 15, left: 15),
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF5A9FD4),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Notification items
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildNotificationItem(
                        'New Reply',
                        'Good Service',
                        'Reply',
                        Icons.chat_bubble_outline,
                      ),
                      _buildNotificationItem(
                        'New Reply',
                        'I highly prefer this.',
                        'Reply',
                        Icons.chat_bubble_outline,
                      ),
                      _buildNotificationItem(
                        'Service Reminder',
                        'Vehicle ABC123 is due for service',
                        'View',
                        Icons.build,
                      ),
                      _buildNotificationItem(
                        'Payment Received',
                        'RM 250.00 payment confirmed',
                        'View',
                        Icons.payment,
                      ),
                      Divider(thickness: 2, color: Colors.grey.shade300),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Notifications',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF5A9FD4),
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      NotificationService().showServiceReminder(
                                        vehicleId: 'ABC123',
                                        message:
                                            'Vehicle ABC123 is due for service in 3 days',
                                      );
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Service reminder notification sent!',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.build, size: 16),
                                    label: Text(
                                      'Service',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF5A9FD4),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      NotificationService()
                                          .showPaymentNotification(
                                            amount: '350.00',
                                            customerId: 'CUST001',
                                          );
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Payment notification sent!',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.payment, size: 16),
                                    label: Text(
                                      'Payment',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  NotificationService().showNewReplyNotification(
                                    message:
                                        'Thank you for the excellent service!',
                                    customerId: 'CUST002',
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reply notification sent!'),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.chat_bubble_outline, size: 16),
                                label: Text(
                                  'New Reply',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(
    String title,
    String message,
    String action,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF5A9FD4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Color(0xFF5A9FD4), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              action,
              style: TextStyle(
                color: Color(0xFF5A9FD4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: EdgeInsets.only(top: 100, right: 20, left: 20),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage('assets/profile.jpg'),
                        backgroundColor: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 40,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Arnaud Dresco',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                      Text(
                        'arnaud04@gmail.com',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Profile options
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildProfileOption(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        onTap: () {
                          Navigator.pop(context);
                          _showEditProfileDialog(context);
                        },
                      ),
                      _buildProfileOption(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🚧 Settings screen is under development.',
                              ),
                            ),
                          );
                        },
                      ),
                      _buildProfileOption(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🚧 Help & Support is under development.',
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(),
                      _buildProfileOption(
                        icon: Icons.logout,
                        title: 'Logout',
                        onTap: () async {
                          Navigator.pop(context);
                          // Clear saved credentials when logging out
                          await RememberMeService.clearCredentials();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Color(0xFF5A9FD4),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Color(0xFF2E2E2E),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final _nameController = TextEditingController(text: 'Arnaud Dresco');
    final _oldPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/profile.jpg'),
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey[600], size: 50),
                ),
                SizedBox(height: 20),
                Text(
                  'Arnaud Dresco',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'arnaud04@gmail.com',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 20),
                // Name field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 16),
                // Old password field
                TextField(
                  controller: _oldPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Old password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 16),
                // New password field
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 24),
                // Update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profile updated successfully!'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5A9FD4),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Update',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
