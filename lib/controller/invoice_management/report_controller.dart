import 'package:cloud_firestore/cloud_firestore.dart';

class ReportController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<QuerySnapshot> fetchPaidInvoices() {
    return _firestore
        .collection('Invoice')
        .where('status', isEqualTo: 'Paid')
        .get();
  }

  Future<QuerySnapshot> fetchMonthlyInvoices(int month, int year) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    return _firestore
        .collection('Invoice')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('status', isEqualTo: 'Paid')
        .get();
  }

  Map<String, dynamic> processMonthlyData(List<QueryDocumentSnapshot> docs) {
    Map<int, double> monthTotals = {};
    Map<String, double> customerTotals = {};
    Map<String, int> paymentMethodCounts = {};
    Map<String, double> paymentMethodAmounts = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final amount = (data['totalAmount'] as num).toDouble();
      final customer = data['customerName'] as String;
      final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';

      // Update month totals
      final month = date.month;
      monthTotals[month] = (monthTotals[month] ?? 0) + amount;

      // Update customer totals
      customerTotals[customer] = (customerTotals[customer] ?? 0) + amount;

      // Update payment method statistics
      paymentMethodCounts[paymentMethod] =
          (paymentMethodCounts[paymentMethod] ?? 0) + 1;
      paymentMethodAmounts[paymentMethod] =
          (paymentMethodAmounts[paymentMethod] ?? 0) + amount;
    }

    return {
      'monthTotals': monthTotals,
      'customerTotals': customerTotals,
      'paymentMethodCounts': paymentMethodCounts,
      'paymentMethodAmounts': paymentMethodAmounts,
    };
  }

  Map<String, dynamic> processDailyData(
    List<QueryDocumentSnapshot> docs,
    int daysInMonth,
  ) {
    Map<int, double> dayTotals = {};
    Map<String, double> customerTotals = {};
    Map<String, int> paymentMethodCounts = {};
    Map<String, double> paymentMethodAmounts = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final amount = (data['totalAmount'] as num).toDouble();
      final customer = data['customerName'] as String;
      final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';

      // Update day totals
      final day = date.day;
      dayTotals[day] = (dayTotals[day] ?? 0) + amount;

      // Update customer totals
      customerTotals[customer] = (customerTotals[customer] ?? 0) + amount;

      // Update payment method statistics
      paymentMethodCounts[paymentMethod] =
          (paymentMethodCounts[paymentMethod] ?? 0) + 1;
      paymentMethodAmounts[paymentMethod] =
          (paymentMethodAmounts[paymentMethod] ?? 0) + amount;
    }

    return {
      'dayTotals': dayTotals,
      'customerTotals': customerTotals,
      'paymentMethodCounts': paymentMethodCounts,
      'paymentMethodAmounts': paymentMethodAmounts,
    };
  }

  String getCustomerAttitude(double amount) {
    if (amount > 2000) return 'Excellent';
    if (amount > 1000) return 'Very Good';
    if (amount > 500) return 'Good';
    return 'Regular';
  }
}
