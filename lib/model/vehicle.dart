import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String carPlateNumber;
  final String customerId;
  final String imageUrl;
  final String make;
  final String model;
  final String vin;
  final int year;

  Vehicle({
    required this.id,
    required this.carPlateNumber,
    required this.customerId,
    required this.imageUrl,
    required this.make,
    required this.model,
    required this.vin,
    required this.year,
  });

  // Create Vehicle from Firestore document
  factory Vehicle.fromMap(Map<String, dynamic> map, String documentId) {
    return Vehicle(
      id: documentId,
      carPlateNumber: map['carPlateNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      make: map['make'] ?? '',
      model: map['model'] ?? '',
      vin: map['vin'] ?? '',
      year: map['year'] ?? 2020,
    );
  }

  // Convert Vehicle to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'carPlateNumber': carPlateNumber,
      'customerId': customerId,
      'imageUrl': imageUrl,
      'make': make,
      'model': model,
      'vin': vin,
      'year': year,
    };
  }

  // Get full car model name (make + model)
  String get fullCarModel => '$make $model';
}
