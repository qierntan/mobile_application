import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/model/inventory_management/procurement.dart';

class ProcurementController {
  static const String _collectionName = 'Procurement';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all procurements
  Stream<List<Procurement>> getProcurements() {
    return _firestore
        .collection(_collectionName)
        .orderBy('requestedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Procurement.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get procurement by id
  Future<Procurement?> getProcurementById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return Procurement.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching procurement: $e');
    }
  }

  // Add a new procurement 
  Future<Procurement> addProcurement(Procurement procurement) async {
    final newId = await _generateUniqueProcurementId();
    final withId = procurement.copyWith(id: newId);

    await _firestore
        .collection(_collectionName)
        .doc(newId)
        .set(withId.toMap());

    return withId; 
  }

  // Search procurements by part
  List<Procurement> searchProcurements(List<Procurement> procurements, String query) {
    if (query.isEmpty) return procurements;
    
    final lowercaseQuery = query.toLowerCase();
    return procurements.where((p) {
      return p.partName.toLowerCase().contains(lowercaseQuery) || p.warehouse.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Sort procurements by requested date or status
  List<Procurement> sortProcurements(
    List<Procurement> procurements, 
    String sortBy, {
    bool descending = true, 
    ProcurementStatus? statusFilter
  }) {
    List<Procurement> sorted = List.from(procurements);

    if (sortBy == 'Requested Date') {
      sorted.sort((a, b) => descending
          ? b.requestedDate.compareTo(a.requestedDate)
          : a.requestedDate.compareTo(b.requestedDate));
    } else if (sortBy == 'Status') {
      if (statusFilter != null) {
        sorted = sorted.where((p) => p.status == statusFilter).toList();
      }
      // Show latest 
      sorted.sort((a, b) => descending
        ? b.requestedDate.compareTo(a.requestedDate)
        : a.requestedDate.compareTo(b.requestedDate));
    }

    return sorted;
  }

  // Get procurements with search and sort applied
  List<Procurement> applySearchAndSort(
    List<Procurement> procurements, 
    String searchQuery, 
    String sortBy, {
    bool descending = true,
    ProcurementStatus? statusFilter,
  }) {
    final searched = searchProcurements(procurements, searchQuery);
    return sortProcurements(searched, sortBy, descending: descending, statusFilter: statusFilter);
  }

  Stream<List<Procurement>> getProcurementsByStatus(ProcurementStatus status) {
    return _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: status.value)
        .orderBy('requestedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Procurement.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Generate random numeric id with prefix
  String _generateRandomProcurementId({int length = 5}) {
    final rand = Random();
    final digits = List.generate(length, (_) => rand.nextInt(10)).join();
    return 'PR$digits';
  }

  // Ensure id is unique 
  Future<String> _generateUniqueProcurementId() async {
    String newId;
    bool exists = true;

    while (exists) {
      newId = _generateRandomProcurementId();
      final doc = await _firestore.collection(_collectionName).doc(newId).get();
      exists = doc.exists;
      if (!exists) return newId;
    }
    throw Exception("Unable to generate unique ID");
  }

  Future<void> markAsReceived(Procurement procurement) async {
    if (procurement.id == null || procurement.id!.isEmpty) {
      throw Exception("Procurement ID is missing");
    }
    try {
      final partQuery = await _firestore
          .collection('Part')
          .where('partName', isEqualTo: procurement.partName)
          .limit(1)
          .get();

      if (partQuery.docs.isEmpty) {
        throw Exception("Part with name ${procurement.partName} not found");
      }

      final partDoc = partQuery.docs.first.reference;

      await _firestore.runTransaction((transaction) async {
        final partSnapshot = await transaction.get(partDoc);
        final currentQty = (partSnapshot.data()?['currentQty'] ?? 0) as int;
        final newQty = currentQty + procurement.orderQty;

        // Update part stock
        transaction.update(partDoc, {'currentQty': newQty});

        // Update procurement status to delivered
        transaction.update(
          _firestore.collection(_collectionName).doc(procurement.id),
          {
            'status': ProcurementStatus.delivered.value,
            'deliveredDate': Timestamp.fromDate(DateTime.now()),
          },
        );
      });
    } catch (e) {
      throw Exception("Error marking procurement as received: $e");
    }
  }

}
