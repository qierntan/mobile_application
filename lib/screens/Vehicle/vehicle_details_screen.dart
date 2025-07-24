import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_vehicle_screen.dart';
import 'add_service_record_screen.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicleData;

  const VehicleDetailsScreen({
    Key? key,
    required this.vehicleId,
    required this.vehicleData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? serviceHistory = vehicleData['service_history'] as Map<String, dynamic>?;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vehicleData['make']} ${vehicleData['model']}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            SizedBox(height: 8),
            Text('Year: ${vehicleData['year']}', style: TextStyle(fontSize: 16)),
            Text('VIN: ${vehicleData['vin']}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Text(
              'Service History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            Expanded(
              child: serviceHistory == null || serviceHistory.isEmpty
                  ? Center(child: Text('No service history'))
                  : ListView.builder(
                      itemCount: serviceHistory.length,
                      itemBuilder: (context, index) {
                        String serviceKey = serviceHistory.keys.elementAt(index);
                        final serviceData = serviceHistory[serviceKey];
                        if (serviceData is Map<String, dynamic>) {
                          final serviceType = serviceData['service_type'] ?? 'Unknown';
                          final date = serviceData['date'];
                          final notes = serviceData['notes'] ?? 'No Notes';
                          String displayDate = 'No Date';
                          if (date is Timestamp) {
                            displayDate = date.toDate().toIso8601String().split('T')[0];
                          } else if (date is String) {
                            displayDate = date;
                          }
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(serviceType),
                              subtitle: Text('$displayDate - $notes'),
                            ),
                          );
                        }
                        return SizedBox.shrink(); // Skip invalid entries
                      },
                    ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddVehicleScreen(
                          vehicleId: vehicleId,
                          vehicleData: vehicleData,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Text('Edit Vehicle'),
                ),
                ElevatedButton(
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('vehicles')
                        .doc(vehicleId)
                        .delete()
                        .then((_) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vehicle deleted')),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('Delete Vehicle'),
                ),
              ],
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddServiceRecordScreen(
                      vehicleId: vehicleId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: Size(double.infinity, 48)),
              child: Text('Add Service Record'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${vehicleData['make']} ${vehicleData['model']} Details'),
        backgroundColor: Colors.teal,
      ),
    );
  }
}