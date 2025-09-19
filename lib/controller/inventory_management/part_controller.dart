import 'package:cloud_firestore/cloud_firestore.dart';
import '../../model/inventory_management/part.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class PartController {
  static const String _collectionName = 'Part';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get all parts
  Stream<List<Part>> getParts() {
    return _firestore
        .collection(_collectionName)
        .orderBy('partName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Part.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get part by ID
  Future<Part?> getPartById(String partId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(partId).get();
      if (doc.exists) {
        return Part.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching part: $e');
    }
  }

  // Add a new part
  Future<String> addPart(Part part, {File? imageFile}) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadPartImage(imageFile, docRef.id);
      }

      await docRef.set(
        part.copyWith(
          id: docRef.id,
          imageUrl: imageUrl,
        ).toMap()
          ..addAll({
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }),
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Error adding part: $e');
    }
  }

  // Update an existing part
  Future<void> updatePart(String partId, Part part, {File? newImageFile}) async {
    try {
      String? imageUrl = part.imageUrl;

      // If user uploaded a new image, replace old one
      if (newImageFile != null) {
        // Delete old image if it exists
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await _storage.refFromURL(imageUrl).delete();
        }

        // Upload new image
        imageUrl = await uploadPartImage(newImageFile, partId);
      }

      await _firestore.collection(_collectionName).doc(partId).update({
        ...part.copyWith(imageUrl: imageUrl).toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating part: $e');
    }
  }

  // Delete a part
  Future<void> deletePart(String partId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(partId).get();
      if (doc.exists) {
        final part = Part.fromMap(doc.data()!, doc.id);
        if (part.imageUrl != null) {
          await _storage.refFromURL(part.imageUrl!).delete();
        }
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error deleting part: $e');
    }
  }

  // Search parts by name or ID
  List<Part> searchParts(List<Part> parts, String query) {
    if (query.isEmpty) return parts;
    
    final lowercaseQuery = query.toLowerCase();
    return parts.where((part) {
      return part.partName.toLowerCase().contains(lowercaseQuery) ||
             (part.id?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Sort parts by name or quantity or stock status
  List<Part> sortParts(List<Part> parts, String sortBy, {bool ascending = true, String? statusFilter}) {
    var sorted = List<Part>.from(parts);
    
    if (sortBy == 'Status' && statusFilter != null) {
      sorted = sorted.where((p) {
        final qty = p.currentQty ?? 0;
        final threshold = p.partThreshold ?? 0;
        final isLow = qty <= threshold;
        return statusFilter == 'Low' ? isLow : !isLow;
      }).toList();

      sorted.sort((a, b) {
        final stockA = a.currentQty ?? 0;
        final stockB = b.currentQty ?? 0;
        return stockA.compareTo(stockB);
      });

      return sorted;
    }

    sorted.sort((a, b) {
      if (sortBy == 'Name') {
        return ascending
            ? a.partName.toLowerCase().compareTo(b.partName.toLowerCase())
            : b.partName.toLowerCase().compareTo(a.partName.toLowerCase());
      } else if (sortBy == 'Quantity') {
        final stockA = a.currentQty ?? 0;
        final stockB = b.currentQty ?? 0;
        return ascending ? stockA.compareTo(stockB) : stockB.compareTo(stockA);
      }
      return 0;
    });

    return sorted;
  }

  // Get parts with search and sort applied
  List<Part> applySearchAndSort(
    List<Part> parts,
    String searchQuery,
    String sortBy, {
    bool ascending = true,
    String? statusFilter, 
  }) {
    final searched = searchParts(parts, searchQuery);
    return sortParts(searched, sortBy, ascending: ascending, statusFilter: statusFilter);
  }

  // Check if part exists by name
  Future<bool> partExistsByName(String partName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('partName', isEqualTo: partName)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking part existence: $e');
    }
  }

  Future<int> getPartCount() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Error getting part count: $e');
    }
  }

  // Get parts below threshold
  Stream<List<Part>> getLowStockParts() {
    return _firestore
        .collection(_collectionName)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Part.fromMap(doc.data(), doc.id))
            .where((part) =>
                part.currentQty != null &&
                part.partThreshold != null &&
                part.currentQty! <= part.partThreshold!)
            .toList());
  }

  // Upload image and return download URL
  Future<String> uploadPartImage(File imageFile, String partId) async {
    try {
      final ref = _storage.ref().child('part_images/$partId.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL(); // return image URL
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}
