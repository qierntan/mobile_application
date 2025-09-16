import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../main.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;

  const ServiceHistoryScreen({super.key, required this.vehicleId});

  @override
  _ServiceHistoryScreenState createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {

  Future<void> _generateServiceInvoicePDF(Map<String, dynamic> serviceData, String documentId) async {
    try {
      // Parse date from Firestore
      DateTime date;
      if (serviceData['date'] is Timestamp) {
        final Timestamp timestamp = serviceData['date'] as Timestamp;
        date = timestamp.toDate();
      } else if (serviceData['date'] is String) {
        date = DateTime.parse(serviceData['date'] as String);
      } else {
        date = DateTime.now();
      }

      final String serviceType = serviceData['serviceType'] ?? 'Service';
      final int kilometers = (serviceData['kilometers'] ?? 0).toInt();
      final double cost = (serviceData['cost'] ?? 0.0).toDouble();
      final String description = serviceData['description'] ?? '';
      final String formattedDate = DateFormat('dd MMM yyyy').format(date);

      // Create PDF document
      final pdf = pw.Document();

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
                        'Invoice #: INV-${documentId.substring(0, 8).toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 30),
                
                // Service Details
                pw.Text(
                  'Service Details',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                
                pw.SizedBox(height: 15),
                
                // Details Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('Service Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(formattedDate),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('Service Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(serviceType),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('Vehicle Kilometers', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('${kilometers.toString()} km'),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Text(description),
                          ),
                        ],
                      ),
                  ],
                ),
                
                pw.SizedBox(height: 30),
                
                // Cost Summary
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Cost',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'RM ${cost.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.Spacer(),
                
                // Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'Thank you for choosing our service!',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Show print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Service_Invoice_${formattedDate.replaceAll(' ', '_')}.pdf',
      );

    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Service History",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ServiceRecord')
            .where('vehicleId', isEqualTo: widget.vehicleId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No service history found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildServiceHistoryList(snapshot.data!.docs);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Customers tab should be selected for service history
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color.fromARGB(255, 178, 72, 249),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // Handle navigation based on index
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeNavigator()),
                (route) => false,
              );
              break;
            case 1:
              // Navigate to customers section
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeNavigator()),
                (route) => false,
              );
              break;
            case 2:
            case 3:
            case 4:
              // Show under development message for other tabs
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🚧 This screen is under development.')),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Jobs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHistoryList(List<QueryDocumentSnapshot> documents) {
    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final data = doc.data() as Map<String, dynamic>;
        
        // Parse date from Firestore (handle both Timestamp and String)
        DateTime date;
        if (data['date'] is Timestamp) {
          final Timestamp timestamp = data['date'] as Timestamp;
          date = timestamp.toDate();
        } else if (data['date'] is String) {
          // Handle ISO string format like "2024-01-15T00:00:00.000"
          date = DateTime.parse(data['date'] as String);
        } else {
          // Fallback to current date if format is unexpected
          date = DateTime.now();
        }
        
        final String serviceType = data['serviceType'] ?? 'Service';
        final int kilometers = (data['kilometers'] ?? 0).toInt();
        final double cost = (data['cost'] ?? 0.0).toDouble();
        final String description = data['description'] ?? '';
        final String formattedDate = '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year}';

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _generateServiceInvoicePDF(data, doc.id),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildInfoRow('Service Type', serviceType),
              _buildInfoRow('Kilometers', '${kilometers.toString()} km'),
              _buildInfoRow('Cost', 'RM ${cost.toStringAsFixed(2)}'),
              if (description.isNotEmpty)
                _buildInfoRow('Description', description),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}