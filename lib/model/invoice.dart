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
  List<Map<String, dynamic>> services;
  List<Map<String, dynamic>> parts;
  List<Map<String, dynamic>> labor;
  double discount;
  String discountType;
  DateTime? paymentDate;

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
    required this.services,
    required this.parts,
    required this.labor,
    this.discount = 0.0,
    this.discountType = 'fixed',
    this.paymentDate,
  });
}
