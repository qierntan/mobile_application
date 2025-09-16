import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/customer.dart';

class CustomerController {
  static const String _collectionName = 'Customer';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all customers
  Stream<List<Customer>> getCustomers() {
    return _firestore
        .collection(_collectionName)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Customer.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get a single customer by ID
  Future<Customer?> getCustomerById(String customerId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(customerId).get();
      if (doc.exists) {
        return Customer.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching customer: $e');
    }
  }


  // Update an existing customer
  Future<void> updateCustomer(String customerId, Customer customer) async {
    try {
      await _firestore.collection(_collectionName).doc(customerId).update(
        customer.toMap()..addAll({
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    } catch (e) {
      throw Exception('Error updating customer: $e');
    }
  }


  // Search customers by name, email, or phone
  List<Customer> searchCustomers(List<Customer> customers, String query) {
    if (query.isEmpty) return customers;
    
    final lowercaseQuery = query.toLowerCase();
    return customers.where((customer) {
      return customer.cusName.toLowerCase().contains(lowercaseQuery) ||
             customer.cusEmail.toLowerCase().contains(lowercaseQuery) ||
             customer.cusPhone.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Sort customers by name
  List<Customer> sortCustomers(List<Customer> customers, String sortOrder) {
    final sortedCustomers = List<Customer>.from(customers);
    sortedCustomers.sort((a, b) {
      final nameA = a.cusName.toLowerCase();
      final nameB = b.cusName.toLowerCase();
      return sortOrder == 'A-Z' 
          ? nameA.compareTo(nameB)
          : nameB.compareTo(nameA);
    });
    return sortedCustomers;
  }

  // Get customers with search and sort applied
  List<Customer> getFilteredCustomers(List<Customer> customers, String searchQuery, String sortOrder) {
    final searched = searchCustomers(customers, searchQuery);
    return sortCustomers(searched, sortOrder);
  }

  // Check if customer exists by email
  Future<bool> customerExistsByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('cusEmail', isEqualTo: email)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking customer existence: $e');
    }
  }


  // Get customer count
  Future<int> getCustomerCount() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Error getting customer count: $e');
    }
  }
}
