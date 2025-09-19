import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_application/model/inventory_management/procurement.dart';
import 'package:mobile_application/controller/inventory_management/procurement_controller.dart';

class ProcurementHistoryScreen extends StatefulWidget {
  const ProcurementHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ProcurementHistoryScreen> createState() => _ProcurementHistoryScreenState();
}

class _ProcurementHistoryScreenState extends State<ProcurementHistoryScreen> {
  final ProcurementController _procurementController = ProcurementController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'Requested Date'; 
  ProcurementStatus? _filterStatus;
  bool _descending = true;  

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(ProcurementStatus status) {
    switch (status) {
      case ProcurementStatus.pending: return Colors.amber;
      case ProcurementStatus.approved: return Colors.blue;
      case ProcurementStatus.rejected: return Colors.red;
      case ProcurementStatus.delivered: return Colors.green;
      case ProcurementStatus.cancelled: return Colors.red;
      case ProcurementStatus.delayed: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EF),
        elevation: 0,
        title: const Text(
          "Procurement History",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search bar 
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
                        hintText: 'Search Part or Warehouse',
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
              ],
            ),
          ),

          // Sort / Status row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _sortBy,
                  items: ['Requested Date', 'Status']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _sortBy = val!;
                    _filterStatus = null; // reset status when changing sort type
                  }),
                ),
                const SizedBox(width: 12),
                if (_sortBy == 'Requested Date')
                  IconButton(
                    icon: Icon(_descending ? Icons.arrow_downward: Icons.arrow_upward),
                    onPressed: () => setState(() => _descending = !_descending),
                  ),
                if (_sortBy == 'Status')
                  DropdownButton<ProcurementStatus>(
                    value: _filterStatus,
                    hint: const Text("Select Status"),
                    items: ProcurementStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (val) => setState(() => _filterStatus = val),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Procurement list
          Expanded(
            child: StreamBuilder<List<Procurement>>(
              stream: _procurementController.getProcurements(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                final filtered = _procurementController.applySearchAndSort(
                  list,
                  _searchQuery,
                  _sortBy,
                  descending: _descending,
                  statusFilter: _filterStatus,
                );

                if (filtered.isEmpty) return const Center(child: Text("No procurements found"));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(p.partName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text(
                                      DateFormat("yyyy-MM-dd").format(p.requestedDate),
                                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text("Qty: ", style: TextStyle(color: Colors.black54)),
                                    Text("${p.orderQty}"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Warehouse: ", style: TextStyle(color: Colors.black54)),
                                    Text(p.warehouse),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Status: ", style: TextStyle(color: Colors.black54)),
                                    Text(
                                      p.status.label,
                                      style: TextStyle(
                                        color: _getStatusColor(p.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (p.status == ProcurementStatus.delivered && p.deliveredDate != null)
                                  Row(
                                    children: [
                                      const Text("Delivered: ", style: TextStyle(color: Colors.black54)),
                                      Text(DateFormat("yyyy-MM-dd").format(p.deliveredDate!)),
                                    ],
                                  ),

                                if (p.status == ProcurementStatus.approved)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await _procurementController.markAsReceived(p);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Procurement marked as received")),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text("Received"),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
