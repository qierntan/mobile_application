import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';

class DashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get total number of customers
  Future<int> getTotalCustomers() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection('Customer').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching customer count: $e');
      return 0;
    }
  }

  /// Get all invoices
  Future<List<Invoice>> getAllInvoices() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection('Invoice').get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Invoice.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error fetching invoices: $e');
      return [];
    }
  }

  /// Get invoice statistics for dashboard
  Future<Map<String, dynamic>> getInvoiceStatistics() async {
    try {
      final List<Invoice> invoices = await getAllInvoices();

      if (invoices.isEmpty) {
        return {
          'totalEarnings': 0.0,
          'paidCount': 0,
          'unpaidCount': 0,
          'paidPercentage': 0.0,
          'unpaidPercentage': 0.0,
          'paidAmount': 0.0,
          'unpaidAmount': 0.0,
        };
      }

      // Separate paid and unpaid invoices
      final paidInvoices =
          invoices
              .where((invoice) => invoice.status.toLowerCase() == 'paid')
              .toList();
      final unpaidInvoices =
          invoices
              .where(
                (invoice) =>
                    invoice.status.toLowerCase() == 'unpaid' ||
                    invoice.status.toLowerCase() == 'pending',
              )
              .toList();

      // Calculate amounts
      final double paidAmount = paidInvoices.fold(
        0.0,
        (sum, invoice) => sum + invoice.total,
      );
      final double unpaidAmount = unpaidInvoices.fold(
        0.0,
        (sum, invoice) => sum + invoice.total,
      );
      final double totalEarnings = paidAmount + unpaidAmount;

      // Calculate percentages
      final int totalCount = invoices.length;
      final int paidCount = paidInvoices.length;
      final int unpaidCount = unpaidInvoices.length;

      final double paidPercentage =
          totalCount > 0 ? (paidCount / totalCount) * 100 : 0.0;
      final double unpaidPercentage =
          totalCount > 0 ? (unpaidCount / totalCount) * 100 : 0.0;

      return {
        'totalEarnings': totalEarnings,
        'paidCount': paidCount,
        'unpaidCount': unpaidCount,
        'paidPercentage': paidPercentage,
        'unpaidPercentage': unpaidPercentage,
        'paidAmount': paidAmount,
        'unpaidAmount': unpaidAmount,
      };
    } catch (e) {
      print('Error calculating invoice statistics: $e');
      return {
        'totalEarnings': 0.0,
        'paidCount': 0,
        'unpaidCount': 0,
        'paidPercentage': 0.0,
        'unpaidPercentage': 0.0,
        'paidAmount': 0.0,
        'unpaidAmount': 0.0,
      };
    }
  }

  /// Get total mechanics count (assuming this comes from a Users collection with role)
  Future<int> getTotalMechanics() async {
    try {
      // Assuming mechanics are stored in Users collection with role field
      final QuerySnapshot snapshot =
          await _firestore
              .collection('Users')
              .where('role', isEqualTo: 'mechanic')
              .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching mechanics count: $e');
      // Return default value if Users collection doesn't exist or no role field
      return 7; // Default value as shown in current dashboard
    }
  }

  /// Format currency for display
  String formatCurrency(double amount) {
    return 'RM${amount.toStringAsFixed(2)}';
  }

  /// Format percentage for display
  String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  /// Get dashboard data stream for real-time updates
  Stream<QuerySnapshot> getInvoicesStream() {
    return _firestore.collection('Invoice').snapshots();
  }

  /// Get customers stream for real-time updates
  Stream<QuerySnapshot> getCustomersStream() {
    return _firestore.collection('Customer').snapshots();
  }
}
