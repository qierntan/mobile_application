import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_application/controller/invoice_management/invoice_pdf_controller.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Invoice invoice;
  final String stripePaymentUrl; // Pass this from details screen

  const InvoicePreviewScreen({
    required this.invoice,
    required this.stripePaymentUrl,
    super.key,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Overdue':
        return Colors.red;
      case 'Pending':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd-MM-yyyy');

    return Scaffold(
      appBar: AppBar(title: Text('Invoice Preview')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVOICE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Invoice ID: ${invoice.id}'),
                    Text('Customer: ${invoice.customerName}'),
                    Text('Vehicle: ${invoice.vehicleNumber}'),
                  ],
                ),
                Column(
                  children: [
                    if (stripePaymentUrl.isNotEmpty &&
                        invoice.status != 'Paid') ...[
                      Text('Scan to Pay', style: TextStyle(fontSize: 10)),
                      SizedBox(height: 4),
                      QrImageView(
                        data: stripePaymentUrl,
                        size: 120,
                        backgroundColor: Colors.white,
                      ),
                    ],
                    SizedBox(height: 8),
                    Column(
                      children: [
                        Text(
                          'Paid Date: ${dateFormatter.format(invoice.paymentDate ?? DateTime.now())}',
                        ),
                        Text(
                          'Status: ${invoice.status}',
                          style: TextStyle(
                            color: _getStatusColor(invoice.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 32),
            _PreviewTable(items: invoice.parts),
            SizedBox(height: 12),
            Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal: RM ${invoice.subtotal.toStringAsFixed(2)}'),
                  Text('SST: RM   ${invoice.tax.toStringAsFixed(2)}'),
                  if (invoice.discount > 0)
                    Text(
                      invoice.discountType == 'percentage'
                          ? 'Discount (${invoice.discount}%): -RM ${(invoice.subtotal * invoice.discount / 100).toStringAsFixed(2)}'
                          : 'Discount: -RM   ${invoice.discount.toStringAsFixed(2)}',
                    ),
                  Divider(color: Colors.grey.shade300, height: 16),
                  Text(
                    'Total Amount: RM ${invoice.total.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // Get fresh data from Firestore to ensure latest values
                final docSnapshot =
                    await FirebaseFirestore.instance
                        .collection('Invoice')
                        .doc(invoice.id)
                        .get();
                final data = docSnapshot.data() as Map<String, dynamic>;

                // Keep the original invoice's status and payment date
                final updatedInvoice = Invoice(
                  id: invoice.id,
                  customerName: data['customerName'] ?? '',
                  vehicleNumber: data['vehicleNumber'] ?? '',
                  date: (data['date'] as Timestamp).toDate(),
                  dueDate: (data['dueDate'] as Timestamp).toDate(),
                  subtotal: (data['subtotal'] ?? 0.0).toDouble(),
                  tax: (data['tax'] ?? 0.0).toDouble(),
                  total: (data['totalAmount'] ?? 0.0).toDouble(),
                  status: invoice.status, // Keep the original status
                  parts: List<Map<String, dynamic>>.from(data['parts'] ?? []),
                  discount: (data['discount'] ?? 0.0).toDouble(),
                  discountType: data['discountType'] ?? 'fixed',
                  paymentDate: invoice.paymentDate,
                );

                await InvoicePdfController.generateAndShare(updatedInvoice);
              },
              icon: Icon(Icons.picture_as_pdf),
              label: Text('Export as PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                minimumSize: Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _PreviewTable({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(4), // Description column
            1: FlexColumnWidth(1), // Quantity column
            2: FlexColumnWidth(2), // Unit Price column
            3: FlexColumnWidth(2), // Total column
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'Unit Price (RM)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'Total (RM)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            ...items.map(
              (item) => TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(item['description'] ?? '-'),
                  ),
                  Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      (item['quantity'] ?? 1).toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      (item['unitPrice'] as double?)?.toStringAsFixed(2) ??
                          '0.00',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      (item['total'] as double?)?.toStringAsFixed(2) ?? '0.00',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
      ],
    );
  }
}
