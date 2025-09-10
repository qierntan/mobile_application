import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Vehicle/add_vehicle_screen.dart';

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
                      // Customer image
                      if (logoUrl.isNotEmpty)
                        Image.network(logoUrl, height: 60)
                      else
                        Container(
                          height: 60,
                          alignment: Alignment.center,
                          child: Text('No image found', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      SizedBox(height: 10),
                      Text(name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, color: Colors.black54),
                          SizedBox(width: 8),
                          Text(phone, style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email, color: Colors.black54),
                          SizedBox(width: 8),
                          Text(email, style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Text(
                  "$name's vehicles",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(imageUrl, width: 80, height: 60, fit: BoxFit.cover),
                              )
                            else
                              Container(
                                width: 80,
                                height: 60,
                                alignment: Alignment.center,
                                child: Text('No image found', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$make $model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text('Year : $year', style: TextStyle(fontSize: 13)),
                                  Text('VIN : $vin', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 60),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: Icon(Icons.add, color: Colors.black, size: 32),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddVehicleScreen(customerId: customerId),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
