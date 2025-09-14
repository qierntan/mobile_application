import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id;
  String customerName;
  String vehicleNumber;
  DateTime date;
  DateTime dueDate;
  double subtotal;
  double tax;
  double total;
  String status;
  List<Map<String, dynamic>> parts;
  double discount;
  String discountType;
  DateTime? paymentDate;
  String? customerEmail;
  String? paymentMethod;
  String? paymentNote;

  Invoice({
    required this.id,
    required this.customerName,
    required this.vehicleNumber,
    required this.date,
    required this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.parts,
    this.discount = 0.0,
    this.discountType = 'fixed',
    this.paymentDate,
    this.customerEmail,
    this.paymentMethod,
    this.paymentNote,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      subtotal: (map['subtotal'] as num).toDouble(),
      tax: (map['tax'] as num).toDouble(),
      total: (map['totalAmount'] as num).toDouble(),
      status: map['status'] ?? 'Pending',
      parts: List<Map<String, dynamic>>.from(map['parts'] ?? []),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      discountType: map['discountType'] ?? 'fixed',
      paymentDate:
          map['paymentDate'] != null
              ? (map['paymentDate'] as Timestamp).toDate()
              : null,
      customerEmail: map['customerEmail'],
      paymentMethod: map['paymentMethod'],
      paymentNote: map['paymentNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'vehicleNumber': vehicleNumber,
      'date': Timestamp.fromDate(date),
      'dueDate': Timestamp.fromDate(dueDate),
      'subtotal': subtotal,
      'tax': tax,
      'totalAmount': total,
      'status': status,
      'parts': parts,
      'discount': discount,
      'discountType': discountType,
      if (paymentDate != null) 'paymentDate': Timestamp.fromDate(paymentDate!),
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (paymentNote != null) 'paymentNote': paymentNote,
    };
  }
}
