import 'package:flutter/material.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;

  const ServiceHistoryScreen({Key? key, required this.vehicleId}) : super(key: key);

  @override
  _ServiceHistoryScreenState createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Service History",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _buildServiceHistoryList(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Customers tab is selected
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color.fromARGB(255, 178, 72, 249),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // Handle navigation based on index
          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              break;
            case 1:
              // Already on customers section, do nothing
              break;
            case 2:
            case 3:
            case 4:
              // Show under development message for other tabs
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🚧 This screen is under development.')),
              );
              break;
          }
        },
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

  Widget _buildServiceHistoryList() {
    // Dummy service history data
    final List<Map<String, dynamic>> serviceRecords = [
      {
        'date': DateTime(2024, 1, 15),
        'serviceInterval': '15,000 km Service',
        'kilometers': '15,000',
        'cost': '85.50',
      },
      {
        'date': DateTime(2024, 2, 20),
        'serviceInterval': '20,000 km Service',
        'kilometers': '20,000',
        'cost': '120.00',
      },
      {
        'date': DateTime(2024, 3, 10),
        'serviceInterval': '25,000 km Service',
        'kilometers': '25,000',
        'cost': '95.75',
      },
      {
        'date': DateTime(2024, 4, 5),
        'serviceInterval': '30,000 km Service',
        'kilometers': '30,000',
        'cost': '250.00',
      },
    ];

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: serviceRecords.length,
      itemBuilder: (context, index) {
        final record = serviceRecords[index];
        final DateTime date = record['date'];
        final String serviceInterval = record['serviceInterval'];
        final String kilometers = record['kilometers'];
        final String cost = record['cost'];
        final String formattedDate = '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year}';

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Invoice',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildInfoRow('Service Interval', serviceInterval),
              _buildInfoRow('Kilometers', '${kilometers} km'),
              _buildInfoRow('Cost', 'RM ${cost}'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}