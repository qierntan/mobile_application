import 'package:flutter/material.dart';
import 'package:mobile_application/model/inventory_management/part.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/screens/Inventory/Part/part_edit_screen.dart';
import 'package:mobile_application/screens/Inventory/Procurement/procurement_request_screen.dart';

class PartDetailsScreen extends StatelessWidget {
  final Part part;
  const PartDetailsScreen({Key? key, required this.part}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EF),
        elevation: 0,
        centerTitle: false,
        title: const Text('Part Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Part?'),
                  content: const Text('This will remove the selected part from database.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true && part.id != null) {
                try {
                  await FirebaseFirestore.instance.collection('Part').doc(part.id).delete();
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete part: $e')),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PartEditScreen(partId: part.id!),
                ),
              );
              if (updated == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Image + Title card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: part.imageUrl != null && part.imageUrl!.isNotEmpty
                      ? Image.network(
                          part.imageUrl!,
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 160,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  part.partName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  part.id ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
            child: Column(
              children: [
                _buildDetailRow("Current Quantity", "${part.currentQty ?? 0}"),
                _buildDetailRow("Minimum Threshold", "${part.partThreshold ?? 0}"),
                _buildDetailRow("Price Per Unit (RM)", "${part.partPrice ?? 0}"),
                _buildDetailRow("Warehouse", part.partWarehouse ?? "-"),
              ],
            ),
          ),

          const Spacer(),

          // Procurement Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Request Procurement",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label :", style: const TextStyle(color: Colors.black87, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  } 
}
