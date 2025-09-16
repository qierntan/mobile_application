import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_history_screen.dart';
import '../../main.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final String vehicleId;

  const VehicleDetailsScreen({super.key, required this.vehicleId});

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
          "Vehicle Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Vehicle').doc(vehicleId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Vehicle not found'));
          }

          final vehicle = snapshot.data!.data() as Map<String, dynamic>;
          final String make = vehicle['make'] ?? 'Unknown';
          final String model = vehicle['model'] ?? 'Unknown';
          final String year = vehicle['year']?.toString() ?? 'Unknown';
          final String vin = vehicle['vin'] ?? 'Unknown';
          final String plateNumber = vehicle['carPlateNumber'] ?? 'Unknown';
          final String? imageUrl = vehicle['imageUrl'];

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Image
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.directions_car,
                                    size: 80,
                                    color: Colors.grey.shade500,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.directions_car,
                                size: 80,
                                color: Colors.grey.shade500,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Vehicle Info Section
                  Container(
                    width: double.infinity,
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
                        Text(
                          'Vehicle Info',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildInfoRow('Make :', make),
                        _buildInfoRow('Model :', model),
                        _buildInfoRow('Year :', year),
                        _buildInfoRow('VIN :', vin),
                        _buildInfoRow('Car Plate\nNumber :', plateNumber),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Service History Button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceHistoryScreen(vehicleId: vehicleId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF9800),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Service History',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Customers tab is selected
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color.fromARGB(255, 178, 72, 249),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // Handle navigation based on index
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeNavigator()),
                (route) => false,
              );
              break;
            case 1:
              // Navigate to customers section
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeNavigator()),
                (route) => false,
              );
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}