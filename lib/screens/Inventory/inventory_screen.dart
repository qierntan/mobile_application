import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'Warehouse/warehouse_list_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOrder = 'A-Z'; // A-Z or Z-A
  final GlobalKey _menuKey = GlobalKey();

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

  Stream<QuerySnapshot<Map<String, dynamic>>> _partsStream() {
    return FirebaseFirestore.instance.collection('Part').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      body: Column(
        children: [
          // Search Bar with Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                PopupMenuButton<int>(
                  key: _menuKey,
                  icon: const Icon(Icons.menu, color: Colors.black),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 1, child: Text('> View Procurement History')),
                    PopupMenuItem(value: 2, child: Text('> View Warehouse List')),
                  ],
                  onSelected: (value) async {
                    if (value == 2) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WarehouseListScreen()),
                      );
                      if (mounted) setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
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
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    // TODO: navigate to Add Part screen if available
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _partsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];

                // Client-side search and sort
                final filtered = docs.where((d) {
                  if (_searchQuery.isEmpty) return true;
                  final data = d.data();
                  final name = (data['Name'] ?? '').toString().toLowerCase();
                  final id = d.id.toLowerCase();
                  return name.contains(_searchQuery) || id.contains(_searchQuery);
                }).toList();

                // Sort by name
                filtered.sort((a, b) {
                  final nameA = (a.data()['Name'] ?? '').toString().toLowerCase();
                  final nameB = (b.data()['Name'] ?? '').toString().toLowerCase();
                  return _sortOrder == 'A-Z' 
                      ? nameA.compareTo(nameB)
                      : nameB.compareTo(nameA);
                });

                if (filtered.isEmpty) {
                  return const Center(child: Text('No parts found'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final name = (data['Name'] ?? 'Unknown').toString();
                    // final price = (data['Price'] ?? 0).toString(); // Removed unused variable
                    final qty = (data['Quantity'] ?? 0) as int;
                    final threshold = (data['Threshold'] ?? 0) as int;
                    final statusLow = qty <= threshold;
                    final statusText = statusLow ? 'Low' : 'Sufficient';
                    final statusColor = statusLow ? Colors.red : Colors.green;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('ID: ${doc.id}', style: const TextStyle(color: Colors.black54)),
                                Text('Stock Qty: $qty', style: const TextStyle(color: Colors.black54)),
                                Row(
                                  children: [
                                    const Text('Status: ', style: TextStyle(color: Colors.black54)),
                                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              const Icon(Icons.chevron_right, color: Colors.black26),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  // TODO: implement request action
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFE7F3FF),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Request'),
                              ),
                            ],
                          )
                        ],
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


