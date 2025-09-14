import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/warehouse.dart';

class WarehouseController {
  static const String _collectionName = 'Warehouse';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all warehouses
  Stream<List<Warehouse>> getWarehouses() {
    return _firestore
        .collection(_collectionName)
        .orderBy('warehouseName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Warehouse.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get a single warehouse by ID
  Future<Warehouse?> getWarehouseById(String warehouseId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(warehouseId).get();
      if (doc.exists) {
        return Warehouse.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching warehouse: $e');
    }
  }

  // Add a new warehouse
  Future<String> addWarehouse(Warehouse warehouse) async {
    try {
      final docRef = await _firestore.collection(_collectionName).add(
        warehouse.toMap()..addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Error adding warehouse: $e');
    }
  }

  // Update an existing warehouse
  Future<void> updateWarehouse(String warehouseId, Warehouse warehouse) async {
    try {
      await _firestore.collection(_collectionName).doc(warehouseId).update(
        warehouse.toMap()..addAll({
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    } catch (e) {
      throw Exception('Error updating warehouse: $e');
    }
  }

  // Delete a warehouse
  Future<void> deleteWarehouse(String warehouseId) async {
    try {
      await _firestore.collection(_collectionName).doc(warehouseId).delete();
    } catch (e) {
      throw Exception('Error deleting warehouse: $e');
    }
  }

  // Search warehouses by name, region, or ID
  List<Warehouse> searchWarehouses(List<Warehouse> warehouses, String query) {
    if (query.isEmpty) return warehouses;
    
    final lowercaseQuery = query.toLowerCase();
    return warehouses.where((warehouse) {
      return warehouse.warehouseName.toLowerCase().contains(lowercaseQuery) ||
             warehouse.region.toLowerCase().contains(lowercaseQuery) ||
             (warehouse.id?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Sort warehouses by name
  List<Warehouse> sortWarehouses(List<Warehouse> warehouses, String sortOrder) {
    final sortedWarehouses = List<Warehouse>.from(warehouses);
    sortedWarehouses.sort((a, b) {
      final nameA = a.warehouseName.toLowerCase();
      final nameB = b.warehouseName.toLowerCase();
      return sortOrder == 'A-Z' 
          ? nameA.compareTo(nameB)
          : nameB.compareTo(nameA);
    });
    return sortedWarehouses;
  }

  // Get warehouses with search and sort applied
  List<Warehouse> getFilteredWarehouses(List<Warehouse> warehouses, String searchQuery, String sortOrder) {
    final searched = searchWarehouses(warehouses, searchQuery);
    return sortWarehouses(searched, sortOrder);
  }

  // Check if warehouse exists by name
  Future<bool> warehouseExistsByName(String warehouseName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('warehouseName', isEqualTo: warehouseName)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking warehouse existence: $e');
    }
  }

  // Get warehouses by region
  Stream<List<Warehouse>> getWarehousesByRegion(String region) {
    return _firestore
        .collection(_collectionName)
        .where('region', isEqualTo: region)
        .orderBy('warehouseName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Warehouse.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get warehouse count
  Future<int> getWarehouseCount() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Error getting warehouse count: $e');
    }
  }

  // Get all unique regions
  Future<List<String>> getUniqueRegions() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final regions = querySnapshot.docs
          .map((doc) => doc.data()['region'] as String?)
          .where((region) => region != null && region.isNotEmpty)
          .cast<String>() // Cast to non-nullable String
          .toSet()
          .toList();
      regions.sort();
      return regions;
    } catch (e) {
      throw Exception('Error getting unique regions: $e');
    }
  }
}
