import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vehicle_details_screen.dart';
import 'add_vehicle_screen.dart';

class VehicleListScreen extends StatelessWidget {
  final String customerId;
  final String customerName;

  const VehicleListScreen({Key? key, required this.customerId, required this.customerName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicles for $customerName'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Customer').doc(customerId).get(),
        builder: (context, customerSnapshot) {
          if (customerSnapshot.hasError) {
            return Center(child: Text('Something went wrong 😢'));
          }

          if (customerSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final customerData = customerSnapshot.data!.data() as Map<String, dynamic>;
          final String? vehicleId = customerData['vehicleId'] as String?; // Single vehicle ID

          if (vehicleId == null) {
            return Center(child: Text('No vehicle assigned to $customerName.'));
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Vehicle').doc(vehicleId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Something went wrong 😢'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.data!.exists) {
                return Center(child: Text('Vehicle not found for $customerName.'));
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;
              String make = data['make'] ?? 'Unknown';
              String model = data['model'] ?? 'Unknown';
              int year = data['year'] ?? 0;
              String vin = data['vin'] ?? 'No VIN';

              return ListView(
                children: [
                  Card(
                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.directions_car, color: Colors.white),
                        backgroundColor: Colors.teal,
                      ),
                      title: Text('$make $model'),
                      subtitle: Text(
                        'Year: $year\nVIN: $vin',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VehicleDetailsScreen(
                              customerId: customerId,
                              vehicleId: vehicleId,
                              vehicleData: data,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddVehicleScreen(customerId: customerId),
            ),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
    );
  }
}