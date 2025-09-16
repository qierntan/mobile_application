import 'package:flutter/material.dart';
import 'warehouse_details_screen.dart';
import 'warehouse_add_screen.dart';
import 'package:mobile_application/model/inventory_management/warehouse.dart';
import 'package:mobile_application/controller/inventory_management/warehouse_controller.dart';

class WarehouseListScreen extends StatefulWidget {
  const WarehouseListScreen({Key? key}) : super(key: key);

  @override
  State<WarehouseListScreen> createState() => _WarehouseListScreenState();
}

class _WarehouseListScreenState extends State<WarehouseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final WarehouseController _warehouseController = WarehouseController();
  String _searchQuery = '';
  String _sortOrder = 'A-Z'; // A-Z or Z-A

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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EF),
        elevation: 0,
        title: const Text('Warehouse', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
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
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WarehouseAddScreen(),
                      ),
                    );
                    if (result == true && mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Warehouse>>(
              stream: _warehouseController.getWarehouses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final warehouses = snapshot.data ?? [];

                // Apply search and sort using controller
                final filtered = _warehouseController.getFilteredWarehouses(
                  warehouses, 
                  _searchQuery, 
                  _sortOrder
                );

                if (filtered.isEmpty) {
                  return const Center(child: Text('No warehouses found'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final warehouse = filtered[index];
                    final name = warehouse.warehouseName;
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WarehouseDetailsScreen(warehouseId: warehouse.id!),
                          ),
                        );
                      },
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


