import 'package:cloud_firestore/cloud_firestore.dart';

class Part {
  final String? id;
  final String partName;
  final String? description;
  final String? partWarehouse;
  final double? partPrice;
  final int? partThreshold;
  final int? currentQty;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;

  Part({
    required this.id,
    required this.partName,
    this.description,
    this.partWarehouse,
    this.partPrice,
    this.partThreshold,
    this.currentQty,
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
  });

  factory Part.fromMap(Map<String, dynamic> map, String documentId) {
    return Part(
      id: documentId,
      partName: map['partName'] ?? '',
      description: map['description'] ?? '',
      partWarehouse: map['partWarehouse'] ?? '',
      partPrice: (map['partPrice'] != null) ? (map['partPrice'] as num).toDouble() : 0.0,
      partThreshold: map['partThreshold'],
      currentQty: map['currentQty'] ?? 0,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'],
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : map['updatedAt'],
      imageUrl: map['imageUrl'],
    );
  }

  // Convert Part to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'partName': partName,
      'description': description,
      'partWarehouse': partWarehouse,
      'partPrice': partPrice,
      'partThreshold': partThreshold,
      'currentQty': currentQty,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'imageUrl': imageUrl,
    };
  }

  Part copyWith({
    String? id,
    String? partName,
    String? description,
    String? partWarehouse,
    double? partPrice,
    int? partThreshold,
    int? currentQty,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
  }) {
    return Part(
      id: id ?? this.id,
      partName: partName ?? this.partName,
      description: description ?? this.description,
      partWarehouse: partWarehouse ?? this.partWarehouse,
      partPrice: partPrice ?? this.partPrice,
      partThreshold: partThreshold ?? this.partThreshold,
      currentQty: currentQty ?? this.currentQty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'Part(id: $id, name: $partName, qty: $currentQty, threshold: $partThreshold, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Part &&
        other.id == id &&
        other.partName == partName &&
        other.description == description &&
        other.partWarehouse == partWarehouse &&
        other.partPrice == partPrice &&
        other.partThreshold == partThreshold &&
        other.currentQty == currentQty &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        partName.hashCode ^
        description.hashCode ^
        partWarehouse.hashCode ^
        partPrice.hashCode ^
        partThreshold.hashCode ^
        currentQty.hashCode ^
        imageUrl.hashCode;
  }
}
