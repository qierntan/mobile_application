class PaymentMethod {
  final String method;
  final String note;

  PaymentMethod({required this.method, required this.note});

  Map<String, dynamic> toMap() {
    return {'method': method, 'note': note};
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(method: map['method'] ?? '', note: map['note'] ?? '');
  }
}
