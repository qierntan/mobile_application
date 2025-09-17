import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for procurement status
enum ProcurementStatus { pending, approved, rejected, delivered, cancelled, delayed}

/// Convert enum to string
extension ProcurementStatusX on ProcurementStatus {
  String get value => toString().split('.').last;

  static ProcurementStatus fromString(String status) {
    return ProcurementStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == status.toLowerCase(),
      orElse: () => ProcurementStatus.pending,
    );
  }
}

extension ProcurementStatusLabel on ProcurementStatus {
  String get label {
    switch (this) {
      case ProcurementStatus.pending: return "Pending";
      case ProcurementStatus.approved: return "Approved";
      case ProcurementStatus.rejected: return "Rejected";
      case ProcurementStatus.delivered: return "Delivered";
      case ProcurementStatus.cancelled: return "Cancelled";
      case ProcurementStatus.delayed: return "Delayed";
    }
  }
}

class Procurement {
  final String? id;           
  final String partName;        
  final int orderQty;
  final String warehouse;
  final DateTime requestedDate;
  final DateTime? expectedDate;
  final DateTime? deliveredDate;
  final String? remarks;
  final ProcurementStatus  status;        

  Procurement({
    this.id,
    required this.partName,
    required this.orderQty,
    required this.warehouse,
    required this.requestedDate,
    this.expectedDate,
    this.deliveredDate,
    this.remarks,
    this.status = ProcurementStatus.pending,
  });

  factory Procurement.fromMap(Map<String, dynamic> map, String documentId) {
    return Procurement(
      id: documentId,
      partName: map['partName'] ?? '',
      orderQty: map['orderQty'] ?? 0,
      warehouse: map['warehouse'] ?? '',
      requestedDate: (map['requestedDate'] as Timestamp).toDate(),
      expectedDate: map['expectedDate'] != null
          ? (map['expectedDate'] as Timestamp).toDate()
          : null,
      deliveredDate: map['deliveredDate'] != null
          ? (map['deliveredDate'] as Timestamp).toDate()
          : null,
      remarks: map['remarks'],
      status: map['status'] != null
          ? ProcurementStatusX.fromString(map['status'])
          : ProcurementStatus.pending,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partName': partName,
      'orderQty': orderQty,
      'warehouse': warehouse,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'expectedDate': expectedDate != null ? Timestamp.fromDate(expectedDate!) : null,
      'deliveredDate': deliveredDate != null ? Timestamp.fromDate(deliveredDate!) : null,
      'remarks': remarks,
      'status': status.value,
    };
  }

  Procurement copyWith({
    String? id,
    String? partName,
    int? orderQty,
    String? warehouse,
    DateTime? requestedDate,
    DateTime? expectedDate,
    DateTime? deliveredDate,
    String? remarks,
    ProcurementStatus? status,
  }) {
    return Procurement(
      id: id ?? this.id,
      partName: partName ?? this.partName,
      orderQty: orderQty ?? this.orderQty,
      warehouse: warehouse ?? this.warehouse,
      requestedDate: requestedDate ?? this.requestedDate,
      expectedDate: expectedDate ?? this.expectedDate,
      deliveredDate: deliveredDate ?? this.deliveredDate,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'Procurement(id: $id, partName: $partName, qty: $orderQty, status: ${status.value})';
  }
}
