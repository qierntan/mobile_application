class PartItem {
  String description;
  int quantity;
  double unitPrice;

  PartItem({this.description = '', this.quantity = 1, this.unitPrice = 0.0});

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory PartItem.fromMap(Map<String, dynamic> map) {
    return PartItem(
      description: map['description'] ?? '',
      quantity: map['quantity'] ?? 1,
      unitPrice: map['unitPrice']?.toDouble() ?? 0.0,
    );
  }
}
