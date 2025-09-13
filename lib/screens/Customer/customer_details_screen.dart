import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Vehicle/add_vehicle_screen.dart';
import '../Vehicle/vehicle_details_screen.dart';
import '../../main.dart';

class CustomerDetailsScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailsScreen({Key? key, required this.customerId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F3EF),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F3EF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Customer's Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Customer').doc(customerId).get(),
        builder: (context, customerSnapshot) {
          if (customerSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!customerSnapshot.hasData || !customerSnapshot.data!.exists) {
            return Center(child: Text('Customer not found'));
          }
          final customer = customerSnapshot.data!.data() as Map<String, dynamic>;
          final String name = customer['cusName'] ?? 'No Name';
          final String phone = customer['cusPhone'] ?? 'No Phone';
          final String email = customer['cusEmail'] ?? 'No Email';
          final String logoUrl = customer['logoUrl'] ?? '';

          return ListView(
            children: [
              SizedBox(height: 24),
              // Customer Card
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Honda Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    'H',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'HONDA',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, color: Colors.black54, size: 18),
                          SizedBox(width: 8),
                          Text(phone, style: TextStyle(fontSize: 14, color: Colors.black87)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email, color: Colors.black54, size: 18),
                          SizedBox(width: 8),
                          Text(email, style: TextStyle(fontSize: 14, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                child: Text(
                  "$name's vehicles",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              // Vehicles List
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('Vehicle').where('customerId', isEqualTo: customerId).snapshots(),
                builder: (context, vehicleSnapshot) {
                  if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!vehicleSnapshot.hasData || vehicleSnapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(child: Text('No vehicles found.')),
                    );
                  }
                  final vehicles = vehicleSnapshot.data!.docs;
                  return Column(
                    children: vehicles.map((doc) {
                      final v = doc.data() as Map<String, dynamic>;
                      final String make = v['make'] ?? '';
                      final String model = v['model'] ?? '';
                      final String year = v['year']?.toString() ?? '';
                      final String vin = v['vin'] ?? '';
                      final String? imageUrl = v['imageUrl'];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleDetailsScreen(vehicleId: doc.id),
                            ),
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          padding: EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(imageUrl, width: 70, height: 50, fit: BoxFit.cover),
                                )
                              else
                                Container(
                                  width: 70,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.directions_car, color: Colors.grey.shade500),
                                ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$make $model', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 100),
            ],
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
}
