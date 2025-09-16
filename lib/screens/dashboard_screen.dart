import 'package:flutter/material.dart';
import 'package:mobile_application/services/remember_me_service.dart';
import 'package:mobile_application/controller/dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
                        'Admin',
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
                        onTap:
                            () =>
                                Navigator.pushNamed(context, '/notifications'),
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
                          child: SizedBox(
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
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
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
    final nameController = TextEditingController(text: 'Admin');
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

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
                ),
                SizedBox(height: 20),
                Text(
                  'Admin',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                // Name field
                TextField(
                  controller: nameController,
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
                  controller: oldPasswordController,
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
                  controller: newPasswordController,
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
