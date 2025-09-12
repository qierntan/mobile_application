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
  final GlobalKey _menuKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _partsStream() {
    return FirebaseFirestore.instance.collection('Part').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EF),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
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
                  onPressed: () {},
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Filter By'),
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

                // simple client-side search
                final q = _searchController.text.trim().toLowerCase();
                final filtered = docs.where((d) {
                  if (q.isEmpty) return true;
                  final data = d.data();
                  final name = (data['Name'] ?? '').toString().toLowerCase();
                  final id = d.id.toLowerCase();
                  return name.contains(q) || id.contains(q);
                }).toList();

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
                    final price = (data['Price'] ?? 0).toString();
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


