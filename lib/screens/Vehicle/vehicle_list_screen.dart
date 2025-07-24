import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vehicle_details_screen.dart'; // Assuming this file exists
import 'add_vehicle_screen.dart';     // Assuming this file exists

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CollectionReference vehicles = FirebaseFirestore.instance.collection('Vehicle');

    return Scaffold(
      appBar: AppBar(
        title: Text('All Vehicles'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: vehicles.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong 😢'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final vehicleDocs = snapshot.data!.docs;

          if (vehicleDocs.isEmpty) {
            return Center(child: Text('No vehicles found.'));
          }

          return ListView.builder(
            itemCount: vehicleDocs.length,
            itemBuilder: (context, index) {
              var data = vehicleDocs[index].data() as Map<String, dynamic>;
              String vehicleId = vehicleDocs[index].id;
              String make = data['make'] ?? 'Unknown';
              String model = data['model'] ?? 'Unknown';
              int year = data['year'] ?? 0;
              String vin = data['vin'] ?? 'No VIN';

              return Card(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.directions_car, color: Colors.white),
                    backgroundColor: Colors.teal,
                  ),
                  title: Text('$make $model'),
                  subtitle: Text('Year: $year\nVIN: $vin'),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleDetailsScreen(
                          vehicleId: vehicleId,
                          vehicleData: data,
                        ),
                      ),
                    );
                  },
                ),
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
              builder: (context) => AddVehicleScreen(),
            ),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
    );
  }
}