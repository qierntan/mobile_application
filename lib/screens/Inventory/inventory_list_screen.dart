import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_application/model/inventory_management/part.dart';
import 'package:mobile_application/controller/inventory_management/part_controller.dart';
import 'package:mobile_application/screens/Inventory/Part/part_add_screen.dart';
import 'Warehouse/warehouse_list_screen.dart';
import 'Part/part_details_screen.dart';
import 'package:mobile_application/screens/Inventory/Procurement/procurement_request_screen.dart';
import 'package:mobile_application/screens/Inventory/Procurement/procurement_history_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({Key? key}) : super(key: key);

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PartController _partController = PartController();
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
                    if (value == 1) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProcurementHistoryScreen()),
                      );
                      if (mounted) setState(() {});
                    }

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
                  onPressed: () async {
                    final added = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PartAddScreen(),
                      ),
                    );
                    if (added == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Parts List
          Expanded(
            child: StreamBuilder<List<Part>>(
              stream: _partController.getParts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final parts = snapshot.data ?? [];
                final filtered = _partController.applyFiltersAndSort(
                  parts,
                  _searchQuery,
                  'name',
                  ascending: _sortOrder == 'A-Z',
                );

                if (filtered.isEmpty) {
                  return const Center(child: Text('No parts found'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (context, index) {
                    final part = filtered[index];
                    final qty = part.currentQty ?? 0;
                    final threshold = part.partThreshold ?? 0;
                    final statusLow = qty <= threshold;
                    final statusText = statusLow ? 'Low' : 'Sufficient';
                    final statusColor = statusLow ? Colors.red : Colors.green;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (_) => PartDetailsScreen(part: part),
                         ),
                        );
                      },
                      child: Container(
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
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: part.imageUrl != null && part.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      part.imageUrl!,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.inventory_2, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 12),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(part.partName,
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w600)),
                                  Text('ID: ${part.id}',
                                      style: const TextStyle(color: Colors.black54)),
                                  Text('Stock Qty: $qty',
                                      style: const TextStyle(color: Colors.black54)),
                                  Row(
                                    children: [
                                      const Text('Status: ',
                                          style: TextStyle(color: Colors.black54)),
                                      Text(statusText,
                                          style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Request button
                            Column(
                              children: [
                                const Icon(Icons.chevron_right, color: Colors.black26),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () async {
                                    final request = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProcurementRequestScreen(partId: part.id!),
                                      ),
                                    );
                                    if (request == true && context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD54F),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: const Text('Request'),
                                ),
                              ],
                            )
                          ],
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

