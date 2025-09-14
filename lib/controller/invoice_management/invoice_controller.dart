import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';
import 'package:mobile_application/model/invoice_management/payment_method.dart';

class InvoiceController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all invoices stream
  Stream<QuerySnapshot> getAllInvoicesStream() {
    return _firestore.collection('Invoice').snapshots();
  }

  // Get filtered and searched invoices
  Stream<QuerySnapshot> getFilteredInvoicesStream(
    String status,
    String searchQuery,
  ) {
    Query query = _firestore.collection('Invoice');

    if (status != 'All') {
      query = query.where('status', isEqualTo: status);
    }

    if (searchQuery.isNotEmpty) {
      // Search by customer name or vehicle number
      query = query
          .where('customerName', isGreaterThanOrEqualTo: searchQuery)
          .where('customerName', isLessThan: searchQuery + 'z');
    }

    return query.snapshots();
  }

  // Get invoice statistics
  Future<Map<String, int>> getInvoiceStatistics() async {
    final QuerySnapshot snapshot = await _firestore.collection('Invoice').get();

    final paidCount =
        snapshot.docs.where((doc) => doc['status'] == 'Paid').length;
    final unpaidCount =
        snapshot.docs.where((doc) => doc['status'] == 'Unpaid').length;
    final overdueCount =
        snapshot.docs.where((doc) => doc['status'] == 'Overdue').length;

    return {'paid': paidCount, 'unpaid': unpaidCount, 'overdue': overdueCount};
  }

  // Load customers for form
  Future<List<Map<String, dynamic>>> loadCustomers() async {
    final QuerySnapshot snapshot =
        await _firestore.collection('Customer').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'cusName': data['cusName'] ?? '',
        'cusEmail': data['cusEmail'] ?? '',
        'vehicles': List<String>.from(data['vehicles'] ?? []),
      };
    }).toList();
  }

  // Get invoice stream
  Stream<DocumentSnapshot> getInvoiceStream(String invoiceId) {
    return _firestore.collection('Invoice').doc(invoiceId).snapshots();
  }

  // Delete invoice
  Future<void> deleteInvoice(String invoiceId) async {
    await _firestore.collection('Invoice').doc(invoiceId).delete();
  }

  // Mark invoice as paid
  Future<void> markAsPaid(String invoiceId, PaymentMethod paymentMethod) async {
    try {
      await _firestore.collection('Invoice').doc(invoiceId).update({
        'status': 'Paid',
        'paymentDate': Timestamp.now(),
        'paymentMethod': paymentMethod.method,
        'paymentNote': paymentMethod.note,
      });
    } catch (e) {
      throw Exception('Failed to mark invoice as paid: $e');
    }
  }

  // Check and update overdue status for a single invoice
  Future<void> checkAndUpdateOverdueStatus(String invoiceId) async {
    final now = DateTime.now();
    final doc = await _firestore.collection('Invoice').doc(invoiceId).get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final dueDate = (data['dueDate'] as Timestamp).toDate();
      final status = data['status'] as String;

      if (status != 'Paid' && now.isAfter(dueDate)) {
        await _firestore.collection('Invoice').doc(invoiceId).update({
          'status': 'Overdue',
        });
      }
    }
  }

  // Batch update all overdue invoices
  Future<void> updateAllOverdueInvoices() async {
    try {
      final now = DateTime.now();

      // Get all unpaid invoices
      final QuerySnapshot snapshot =
          await _firestore
              .collection('Invoice')
              .where('status', isEqualTo: 'Unpaid')
              .get();

      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dueDate = (data['dueDate'] as Timestamp).toDate();

        // Check if invoice is overdue
        if (now.isAfter(dueDate)) {
          batch.update(doc.reference, {'status': 'Overdue'});
          updateCount++;
        }
      }

      // Commit batch update if there are any changes
      if (updateCount > 0) {
        await batch.commit();
        print('Updated $updateCount invoices to Overdue status');
      }
    } catch (e) {
      print('Error updating overdue invoices: $e');
      throw Exception('Failed to update overdue invoices: $e');
    }
  }

  // Submit new invoice
  Future<void> submitInvoice(Invoice invoice, {bool isEditing = false}) async {
    try {
      final invoiceData = invoice.toMap();

      if (isEditing) {
        await _firestore
            .collection('Invoice')
            .doc(invoice.id)
            .update(invoiceData);
      } else {
        // Generate a random 4-digit number for new invoices
        final random = DateTime.now().millisecondsSinceEpoch % 10000;
        final formattedRandom = random.toString().padLeft(4, '0');
        final invoiceId = 'Inv$formattedRandom';

        // Include the generated ID in the invoice data
        invoiceData['id'] = invoiceId;
        await _firestore.collection('Invoice').doc(invoiceId).set(invoiceData);
      }
    } catch (e) {
      throw Exception('Failed to submit invoice: $e');
    }
  }
}
