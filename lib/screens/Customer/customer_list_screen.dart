import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CollectionReference customers = FirebaseFirestore.instance.collection('Customer');

    return Scaffold(
      appBar: AppBar(title: Text('Customer List')),
      body: StreamBuilder<QuerySnapshot>(
        stream: customers.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong 😢'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final customerDocs = snapshot.data!.docs;

          if (customerDocs.isEmpty) {
            return Center(child: Text('No customers found.'));
          }

          return ListView.builder(
            itemCount: customerDocs.length,
            itemBuilder: (context, index) {
              var data = customerDocs[index].data() as Map<String, dynamic>;
              String name = data['cusName'] ?? 'No Name';
              String email = data['cusEmail'] ?? 'No Email';
              String phone = data['cusPhone'] ?? 'No Phone';

              return Card(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name),
                  subtitle: Text('📞 $phone\n📧 $email'),
                  isThreeLine: true,
                  onTap: () {
                    // TODO: Navigate to customer detail screen
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}