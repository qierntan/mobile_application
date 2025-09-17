import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ServiceInvoiceController {
  static Future<void> generateServiceInvoice(Map<String, dynamic> serviceData, String vehicleId) async {
    final pdf = pw.Document();
    final dateFormatter = DateFormat('dd MMM yyyy');
    
    // Parse service date
    DateTime serviceDate;
    if (serviceData['date'] is Timestamp) {
      serviceDate = (serviceData['date'] as Timestamp).toDate();
    } else if (serviceData['date'] is String) {
      serviceDate = DateTime.parse(serviceData['date'] as String);
    } else {
      serviceDate = DateTime.now();
    }

    // Get vehicle and customer information
    final vehicleInfo = await _getVehicleInfo(vehicleId);
    final customerInfo = await _getCustomerInfo(vehicleInfo['customerId'] ?? '');

    // Generate invoice ID
    final invoiceId = 'SRV${DateTime.now().millisecondsSinceEpoch % 10000}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SERVICE INVOICE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Invoice #$invoiceId',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Company and Customer Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Auto Service Center',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text('123 Service Street'),
                        pw.Text('Kuala Lumpur, Malaysia'),
                        pw.Text('Phone: +60 12-345-6789'),
                        pw.Text('Email: service@autocare.com'),
                      ],
                    ),
                  ),
                  // Customer Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bill To:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(customerInfo['cusName'] ?? 'Unknown Customer'),
                        pw.Text(customerInfo['cusPhone'] ?? 'No Phone'),
                        pw.Text(customerInfo['cusEmail'] ?? 'No Email'),
                        pw.SizedBox(height: 16),
                        pw.Text(
                          'Service Date: ${dateFormatter.format(serviceDate)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Vehicle Information
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Vehicle Information',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Vehicle ID: ${vehicleInfo['vehicleId'] ?? vehicleId}'),
                        ),
                        pw.Expanded(
                          child: pw.Text('Plate Number: ${vehicleInfo['plateNumber'] ?? 'N/A'}'),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Make: ${vehicleInfo['make'] ?? 'N/A'}'),
                        ),
                        pw.Expanded(
                          child: pw.Text('Model: ${vehicleInfo['model'] ?? 'N/A'}'),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Year: ${vehicleInfo['year'] ?? 'N/A'}'),
                        ),
                        pw.Expanded(
                          child: pw.Text('Kilometers: ${(serviceData['kilometers'] ?? 0).toString()} km'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Service Details
              pw.Text(
                'Service Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          'Service Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          'Amount (RM)',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Service Type Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              serviceData['serviceType'] ?? 'General Service',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            if (serviceData['description'] != null && serviceData['description'].toString().isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 4),
                                child: pw.Text(
                                  serviceData['description'].toString(),
                                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          ((serviceData['cost'] ?? 0.0) as double).toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Total Section
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:'),
                          pw.Text('RM ${((serviceData['cost'] ?? 0.0) as double).toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('SST (6%):'),
                          pw.Text('RM ${(((serviceData['cost'] ?? 0.0) as double) * 0.06).toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey300, height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Amount:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'RM ${(((serviceData['cost'] ?? 0.0) as double) * 1.06).toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 32),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for choosing our service!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'For any inquiries, please contact us at service@autocare.com',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Show PDF preview and print options
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<Map<String, dynamic>> _getVehicleInfo(String vehicleId) async {
    try {
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('Vehicle')
          .doc(vehicleId)
          .get();
      
      if (vehicleDoc.exists) {
        return vehicleDoc.data() ?? {};
      }
    } catch (e) {
      print('Error fetching vehicle info: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> _getCustomerInfo(String customerId) async {
    try {
      if (customerId.isEmpty) return {};
      
      final customerDoc = await FirebaseFirestore.instance
          .collection('Customer')
          .doc(customerId)
          .get();
      
      if (customerDoc.exists) {
        return customerDoc.data() ?? {};
      }
    } catch (e) {
      print('Error fetching customer info: $e');
    }
    return {};
  }
}