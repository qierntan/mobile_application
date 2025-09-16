class Customer {
  final String? id;
  final String cusName;
  final String cusEmail;
  final String cusPhone;
  final String? logoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> vehicleIds;

  Customer({
    this.id,
    required this.cusName,
    required this.cusEmail,
    required this.cusPhone,
    this.logoUrl,
    this.createdAt,
    this.updatedAt,
    this.vehicleIds = const [],
  });

  // Create Customer from Firestore document
  factory Customer.fromMap(Map<String, dynamic> map, String documentId) {
    return Customer(
      id: documentId,
      cusName: map['cusName'] ?? '',
      cusEmail: map['cusEmail'] ?? '',
      cusPhone: map['cusPhone'] ?? '',
      logoUrl: map['logoUrl'],
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
      vehicleIds: (map['vehicleIds'] is List)
          ? (map['vehicleIds'] as List)
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList()
          : const [],
    );
  }

  // Convert Customer to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'cusName': cusName,
      'cusEmail': cusEmail,
      'cusPhone': cusPhone,
      'logoUrl': logoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'vehicleIds': vehicleIds,
    };
  }

  // Create a copy of Customer with updated fields
  Customer copyWith({
    String? id,
    String? cusName,
    String? cusEmail,
    String? cusPhone,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? vehicleIds,
  }) {
    return Customer(
      id: id ?? this.id,
      cusName: cusName ?? this.cusName,
      cusEmail: cusEmail ?? this.cusEmail,
      cusPhone: cusPhone ?? this.cusPhone,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleIds: vehicleIds ?? this.vehicleIds,
    );
  }

  @override
  String toString() {
    return 'Customer(id: $id, cusName: $cusName, cusEmail: $cusEmail, cusPhone: $cusPhone, logoUrl: $logoUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer &&
        other.id == id &&
        other.cusName == cusName &&
        other.cusEmail == cusEmail &&
        other.cusPhone == cusPhone &&
        other.logoUrl == logoUrl &&
        _listEquals(other.vehicleIds, vehicleIds);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        cusName.hashCode ^
        cusEmail.hashCode ^
        cusPhone.hashCode ^
        logoUrl.hashCode ^
        vehicleIds.hashCode;
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class CustomerImage {
  final String customerId;
  final String customerName;
  final String? logoUrl;
  final String? assignedImageFileName;

  CustomerImage({
    required this.customerId,
    required this.customerName,
    this.logoUrl,
    this.assignedImageFileName,
  });

  // Create CustomerImage from Firestore document
  factory CustomerImage.fromMap(Map<String, dynamic> map, String documentId) {
    return CustomerImage(
      customerId: documentId,
      customerName: map['cusName'] ?? '',
      logoUrl: map['logoUrl'],
      assignedImageFileName: null, // This will be set separately
    );
  }

  // Convert CustomerImage to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'cusName': customerName,
      'logoUrl': logoUrl,
    };
  }

  // Create a copy of CustomerImage with updated fields
  CustomerImage copyWith({
    String? customerId,
    String? customerName,
    String? logoUrl,
    String? assignedImageFileName,
  }) {
    return CustomerImage(
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      logoUrl: logoUrl ?? this.logoUrl,
      assignedImageFileName: assignedImageFileName ?? this.assignedImageFileName,
    );
  }

  @override
  String toString() {
    return 'CustomerImage(customerId: $customerId, customerName: $customerName, logoUrl: $logoUrl, assignedImageFileName: $assignedImageFileName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerImage &&
        other.customerId == customerId &&
        other.customerName == customerName &&
        other.logoUrl == logoUrl &&
        other.assignedImageFileName == assignedImageFileName;
  }

  @override
  int get hashCode {
    return customerId.hashCode ^
        customerName.hashCode ^
        logoUrl.hashCode ^
        assignedImageFileName.hashCode;
  }
}