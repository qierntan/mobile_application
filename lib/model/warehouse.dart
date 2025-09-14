class Warehouse {
  final String? id;
  final String warehouseName;
  final String region;
  final String? address;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Warehouse({
    this.id,
    required this.warehouseName,
    required this.region,
    this.address,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    this.createdAt,
    this.updatedAt,
  });

  // Create Warehouse from Firestore document
  factory Warehouse.fromMap(Map<String, dynamic> map, String documentId) {
    return Warehouse(
      id: documentId,
      warehouseName: map['warehouseName'] ?? '',
      region: map['region'] ?? '',
      address: map['address'],
      contactPerson: map['contactPerson'],
      contactPhone: map['contactPhone'],
      contactEmail: map['contactEmail'],
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  // Convert Warehouse to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'warehouseName': warehouseName,
      'region': region,
      'address': address,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create a copy of Warehouse with updated fields
  Warehouse copyWith({
    String? id,
    String? warehouseName,
    String? region,
    String? address,
    String? contactPerson,
    String? contactPhone,
    String? contactEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      warehouseName: warehouseName ?? this.warehouseName,
      region: region ?? this.region,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Warehouse(id: $id, warehouseName: $warehouseName, region: $region, address: $address, contactPerson: $contactPerson)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Warehouse &&
        other.id == id &&
        other.warehouseName == warehouseName &&
        other.region == region &&
        other.address == address &&
        other.contactPerson == contactPerson &&
        other.contactPhone == contactPhone &&
        other.contactEmail == contactEmail;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        warehouseName.hashCode ^
        region.hashCode ^
        address.hashCode ^
        contactPerson.hashCode ^
        contactPhone.hashCode ^
        contactEmail.hashCode;
  }
}
