class Invoice {
  final String id;
  String customerName;
  String vehicleNumber;
  String status;
  DateTime date;
  double subtotal;
  double tax;
  double total;
  List<Map<String, dynamic>> services;
  List<Map<String, dynamic>> parts;
  List<Map<String, dynamic>> labor;

  Invoice({
    required this.id,
    required this.customerName,
    required this.vehicleNumber,
    required this.status,
    required this.date,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.services,
    required this.parts,
    required this.labor,
  });
}
