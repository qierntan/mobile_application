class Customer {
  final String? id;
  final String cusName;
  final String cusEmail;
  final String cusPhone;
  final String? logoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    this.id,
    required this.cusName,
    required this.cusEmail,
    required this.cusPhone,
    this.logoUrl,
    this.createdAt,
    this.updatedAt,
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
  }) {
    return Customer(
      id: id ?? this.id,
      cusName: cusName ?? this.cusName,
      cusEmail: cusEmail ?? this.cusEmail,
      cusPhone: cusPhone ?? this.cusPhone,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        other.logoUrl == logoUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        cusName.hashCode ^
        cusEmail.hashCode ^
        cusPhone.hashCode ^
        logoUrl.hashCode;
  }
}
