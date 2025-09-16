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
  Future<String> addProcurement(Procurement procurement) async {
    final newId = await _generateUniqueProcurementId();
    await _firestore
        .collection(_collectionName)
        .doc(newId)
        .set(procurement.copyWith(id: newId).toMap());
    return newId;
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
}
