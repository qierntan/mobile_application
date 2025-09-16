import 'package:flutter/material.dart';
import 'package:mobile_application/screens/Customer/customer_details_screen.dart';
import 'package:mobile_application/screens/Customer/customer_chat_history.dart';
import 'package:mobile_application/model/customer.dart';
import 'package:mobile_application/controller/customer_controller.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({Key? key}) : super(key: key);

  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CustomerController _customerController = CustomerController();
  String _searchQuery = '';
  String _sortOrder = 'A-Z';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == 'A-Z' ? 'Z-A' : 'A-Z';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(0xFFF5F3EF);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(30),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),
          ),
          // Sort Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _toggleSortOrder,
                  icon: const Icon(Icons.sort),
                  label: Text('Sort: $_sortOrder'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Customer List
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _customerController.getCustomers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong 😢'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final customers = snapshot.data ?? [];
                final filteredCustomers = _customerController.getFilteredCustomers(
                  customers, 
                  _searchQuery, 
                  _sortOrder
                );

                if (filteredCustomers.isEmpty) {
                  return Center(child: Text('No customers found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    final customerId = customer.id!;
                    final customerName = customer.cusName;
                    final email = customer.cusEmail;
                    final phone = customer.cusPhone;
                    final logoUrl = customer.logoUrl ?? '';

                    return Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerDetailsScreen(customerId: customerId),
                            ),
                          );
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.95,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Card(
                            color: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Customer image
                                  if (logoUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        logoUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 60,
                                      height: 60,
                                      alignment: Alignment.center,
                                      child: Text('No image', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ),
                                  SizedBox(width: 18),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.phone, size: 18, color: Colors.black54),
                                            SizedBox(width: 6),
                                            Text(phone, style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.email, size: 18, color: Colors.black54),
                                            SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                email,
                                                style: TextStyle(fontSize: 10),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Flexible(
                                    flex: 0,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CustomerChatHistory(customerId: customerId, customerName: customerName),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFFFC107),
                                        foregroundColor: Colors.black87,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        elevation: 0,
                                      ),
                                      child: Text('View Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
    );
  }
}