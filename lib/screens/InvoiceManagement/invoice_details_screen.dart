import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mobile_application/controller/invoice_management/invoice_pdf_controller.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';
import 'package:mobile_application/screens/InvoiceManagement/invoice_form_screen.dart';
import 'package:mobile_application/screens/InvoiceManagement/invoice_preview_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;
  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Stream<DocumentSnapshot> invoiceStream;

  Future<void> sendReminderEmail() async {
    try {
      print('Starting email reminder process...');

      // First, get fresh invoice data from Firestore to ensure we have latest discount info
      print('Fetching fresh invoice data from Firestore...');
      final invoiceDoc =
          await FirebaseFirestore.instance
              .collection('Invoice')
              .doc(widget.invoice.id)
              .get();

      if (!invoiceDoc.exists) {
        throw Exception('Invoice not found in database');
      }

      final invoiceData = invoiceDoc.data() as Map<String, dynamic>;
      print(
        'Fresh invoice data retrieved with discount: ${invoiceData['discount']} (${invoiceData['discountType']})',
      );

      // First, get customer data
      print('Fetching customer data for: ${invoiceData['customerName']}');
      final customerDoc =
          await FirebaseFirestore.instance
              .collection('Customer')
              .where('cusName', isEqualTo: invoiceData['customerName'])
              .get();

      if (customerDoc.docs.isEmpty) {
        print('No customer found with name: ${invoiceData['customerName']}');
        throw Exception('Customer not found in database');
      }

      // Verify this invoice is actually overdue
      if (invoiceData['status'] != 'Overdue') {
        print('Invoice status is not Overdue: ${invoiceData['status']}');
        throw Exception('Cannot send reminder for non-overdue invoice');
      }

      final customerData = customerDoc.docs.first.data();
      print('Customer data found: ${customerData.toString()}');

      final customerEmail = customerData['cusEmail'] as String?;
      if (customerEmail == null || customerEmail.isEmpty) {
        print('Customer email is missing or empty');
        throw Exception('Customer email not found');
      }
      print('Customer email found: $customerEmail');

      // Create fresh invoice object with latest data for payment link generation
      final freshInvoice = Invoice(
        id: widget.invoice.id,
        customerName: invoiceData['customerName'] ?? '',
        vehicleId: invoiceData['vehicleId'] ?? '',
        date: (invoiceData['date'] as Timestamp).toDate(),
        dueDate: (invoiceData['dueDate'] as Timestamp).toDate(),
        subtotal: (invoiceData['subtotal'] ?? 0.0).toDouble(),
        tax: (invoiceData['tax'] ?? 0.0).toDouble(),
        total: (invoiceData['totalAmount'] ?? 0.0).toDouble(),
        status: invoiceData['status'] ?? '',
        parts: List<Map<String, dynamic>>.from(invoiceData['parts'] ?? []),
        discount: (invoiceData['discount'] ?? 0.0).toDouble(),
        discountType: invoiceData['discountType'] ?? 'fixed',
      );

      // Generate the Stripe payment URL
      print('Generating payment link...');
      final stripePaymentUrl =
          await InvoicePdfController.createStripePaymentLink(freshInvoice);
      if (stripePaymentUrl == null) {
        print('Failed to generate Stripe payment link');
        throw Exception('Failed to generate payment link');
      }
      print('Payment link generated successfully');

      print('Setting up SMTP server...');
      late final SmtpServer smtpServer;
      try {
        smtpServer = gmail('kfuichong0412@gmail.com', 'rsgt xnai tdqt ygml');
        print('SMTP server configured successfully');
      } catch (e) {
        print('Failed to configure SMTP server: $e');
        throw Exception(
          'Email server configuration failed. Please check your internet connection and try again.',
        );
      }

      // Extract services, parts, and labor from the fresh invoice data
      print('Extracting invoice details...');
      final parts = List<Map<String, dynamic>>.from(invoiceData['parts'] ?? []);
      print('Parts: ${parts.length} items');

      print('Creating email content...');
      print('Building services HTML...');
      print('Building parts HTML with ${parts.length} parts');
      String partsHtml =
          parts
              .map(
                (part) => '''<tr>
          <td style="padding: 8px; border-bottom: 1px solid #ddd;">${part['description'] ?? 'Part'}</td>
          <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">RM ${(part['total'] ?? 0.0).toStringAsFixed(2)}</td>
        </tr>
        ${part['quantity'] != null ? '''<tr>
          <td colspan="2" style="padding: 4px 8px; color: #666; font-size: 12px;">
            Quantity: ${part['quantity']} × RM ${(part['unitPrice'] ?? 0.0).toStringAsFixed(2)}
          </td>
        </tr>''' : ''}''',
              )
              .join();
      final message =
          Message()
            ..from = Address('kfuichong0412@gmail.com', 'Invoice Management')
            ..recipients.add(customerEmail)
            ..subject =
                'Payment Reminder: Invoice ${invoiceData['customerName']}'
            ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #d32f2f;">Payment Reminder</h2>
            <p>Dear ${invoiceData['customerName']},</p>
            <p>This is a friendly reminder that the payment for your invoice is overdue.</p>
            
            <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
              <h3 style="margin-top: 0;">Invoice Details:</h3>
              <p style="margin: 5px 0;">Vehicle Number: ${invoiceData['vehicleId'] ?? ''}</p>
              <p style="margin: 5px 0;">Invoice Date: ${DateFormat('dd/MM/yyyy').format((invoiceData['date'] as Timestamp).toDate())}</p>
              <p style="margin: 5px 0;">Due Date: ${DateFormat('dd/MM/yyyy').format((invoiceData['dueDate'] as Timestamp).toDate())}</p>
            </div>

            <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
              <tr style="background-color: #f5f5f5;">
                <th style="padding: 12px 8px; text-align: left; border-bottom: 2px solid #ddd;">Description</th>
                <th style="padding: 12px 8px; text-align: right; border-bottom: 2px solid #ddd;">Amount</th>
              </tr>
              
              
              <!-- Parts -->
              ${partsHtml}
            
              
              <!-- Subtotal -->
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #ddd;">Subtotal</td>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">RM ${(invoiceData['subtotal'] ?? 0.0).toStringAsFixed(2)}</td>
              </tr>
              
              <!-- Tax -->
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #ddd;">Tax (6%)</td>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">RM ${(invoiceData['tax'] ?? 0.0).toStringAsFixed(2)}</td>
              </tr>

              <!-- Discount (if applicable) -->
              ${(invoiceData['discount'] ?? 0.0) > 0 ? '''
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; color: #d32f2f;">Discount ${invoiceData['discountType'] == 'percentage' ? '(${invoiceData['discount']}%)' : ''}</td>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right; color: #d32f2f;">-RM ${invoiceData['discountType'] == 'percentage' ? ((invoiceData['subtotal'] ?? 0.0) * (invoiceData['discount'] ?? 0.0) / 100).toStringAsFixed(2) : (invoiceData['discount'] ?? 0.0).toStringAsFixed(2)}</td>
              </tr>

              ''' : ''}
              
              <!-- Total -->
              <tr style="font-weight: bold; background-color: #f5f5f5;">
                <td style="padding: 12px 8px;">Total Amount</td>
                <td style="padding: 12px 8px; text-align: right;">RM ${(invoiceData['totalAmount'] ?? 0.0).toStringAsFixed(2)}</td>
              </tr>
            </table>

            <p style="color: #d32f2f; font-weight: bold;">Please process the payment at your earliest convenience.</p>
            <p>If you have already made the payment, please disregard this reminder.</p>
            
            <div style="text-align: center; margin: 30px 0;">
              <p style="font-weight: bold; color: #2196F3;">Scan QR Code to Make Payment</p>
              <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(stripePaymentUrl)}" 
                   alt="Payment QR Code" 
                   style="width: 200px; height: 200px; margin: 10px auto; display: block;" />
            </div>

            <div style="margin-top: 30px;">
              <p>Thank you for your business!</p>
              <p>Best regards,<br>Invoice Management Team</p>
            </div>
          </div>
        ''';

      print('Attempting to send email...');
      try {
        final sendReport = await send(message, smtpServer);
        print('Message sent successfully!');
        print('Send report: ${sendReport.toString()}');
      } catch (emailError) {
        print('SMTP Error: $emailError');
        if (emailError.toString().contains(
          'Username and Password not accepted',
        )) {
          throw Exception(
            'Email authentication failed. Please check the email credentials.',
          );
        } else {
          throw Exception('Failed to send email: ${emailError.toString()}');
        }
      }
    } catch (e) {
      print('Error in sendReminderEmail: $e');
      throw e;
    }
  }

  Future<void> _checkAndUpdateOverdueStatus() async {
    final now = DateTime.now();
    final doc =
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(widget.invoice.id)
            .get();

    if (doc.exists) {
      final data = doc.data()!;
      final dueDate = (data['dueDate'] as Timestamp).toDate();
      final status = data['status'] as String;

      // If the invoice is unpaid and past due date, mark as overdue
      if (status == 'Unpaid' && now.isAfter(dueDate)) {
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(widget.invoice.id)
            .update({'status': 'Overdue'});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check for overdue status
    _checkAndUpdateOverdueStatus();
    // Set up stream to listen to invoice changes
    invoiceStream =
        FirebaseFirestore.instance
            .collection('Invoice')
            .doc(widget.invoice.id)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Details'),
        backgroundColor: Color(0xFFF6F2EA),
        foregroundColor: Color(0xFF22211F),
        elevation: 0,
      ),
      backgroundColor: Color(0xFFF6F2EA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: invoiceStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // Check if document exists and has data
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // Document has been deleted
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context, true); // Return to previous screen
            });
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          // ignore: unnecessary_null_comparison
          if (data == null) {
            return Center(child: Text('Invoice data is invalid'));
          }

          final parts = List<Map<String, dynamic>>.from(data['parts'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['customerName'] ?? '',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22211F),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Vehicle: ${data['vehicleId'] ?? ''}',
                          style: TextStyle(color: Color(0xFF22211F)),
                        ),
                        Text(
                          'Invoice Date: ${DateFormat('dd/MM/yyyy').format((data['date'] as Timestamp).toDate())}',
                          style: TextStyle(color: Color(0xFF22211F)),
                        ),
                        Text(
                          'Due Date: ${DateFormat('dd/MM/yyyy').format((data['dueDate'] as Timestamp).toDate())}',
                          style: TextStyle(color: Color(0xFF22211F)),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22211F),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  data['status'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(
                                    data['status'],
                                  ).withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                data['status'] ?? '',
                                style: TextStyle(
                                  color: _getStatusColor(data['status']),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parts/Services',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        ...parts.map(
                          (item) => _BreakdownRow(
                            label: item['description'] ?? '',
                            value: (item['total'] ?? 0.0).toDouble(),
                            quantity: item['quantity'] ?? 1,
                            unitPrice: item['unitPrice'] ?? 0.0,
                          ),
                        ),
                        Divider(),
                        _BreakdownRow(
                          label: 'Subtotal',
                          value: (data['subtotal'] ?? 0.0).toDouble(),
                        ),
                        _BreakdownRow(
                          label: 'Tax (6%)',
                          value: (data['tax'] ?? 0.0).toDouble(),
                        ),
                        // Add discount row
                        if ((data['discount'] ?? 0.0) > 0)
                          _BreakdownRow(
                            label:
                                data['discountType'] == 'percentage'
                                    ? 'Discount (${data['discount']}%)'
                                    : 'Discount',
                            value:
                                data['discountType'] == 'percentage'
                                    ? -((data['subtotal'] ?? 0.0) *
                                            (data['discount'] ?? 0.0) /
                                            100)
                                        .toDouble()
                                    : -(data['discount'] ?? 0.0).toDouble(),
                            textColor: Colors.red,
                          ),
                        Divider(),
                        _BreakdownRow(
                          label: 'Total Amount',
                          value: (data['totalAmount'] ?? 0.0).toDouble(),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        if (widget.invoice.status == 'Unpaid') ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder:
                                    (_) => _PaymentMethodDialog(
                                      onPaid: (method, note) {
                                        _markAsPaid(method, note);
                                      },
                                    ),
                              );
                            },
                            icon: Icon(Icons.attach_money, color: Colors.white),
                            label: Text('Mark as Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(
                                255,
                                61,
                                248,
                                123,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final stripePaymentUrl =
                                  await InvoicePdfController.createStripePaymentLink(
                                    widget.invoice,
                                  );
                              if (stripePaymentUrl != null) {
                                await _showInvoicePreview(
                                  stripePaymentUrl: stripePaymentUrl,
                                );
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to generate payment link',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.visibility, color: Colors.white),
                            label: Text('Preview'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFC700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _deleteInvoice,
                            icon: Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (widget.invoice.status == 'Paid') ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              _showInvoicePreview(
                                stripePaymentUrl: '',
                              ); // No QR for paid
                            },
                            icon: Icon(Icons.visibility, color: Colors.white),
                            label: Text('Preview'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFC700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _deleteInvoice,
                            icon: Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (widget.invoice.status == 'Overdue') ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder:
                                    (_) => _PaymentMethodDialog(
                                      onPaid: (method, note) {
                                        _markAsPaid(method, note);
                                      },
                                    ),
                              );
                            },
                            icon: Icon(Icons.attach_money, color: Colors.white),
                            label: Text('Mark as Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(
                                255,
                                61,
                                248,
                                123,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await sendReminderEmail();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Reminder email sent successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to send reminder email',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.email, color: Colors.white),
                            label: Text('Send Reminder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final stripePaymentUrl =
                                  await InvoicePdfController.createStripePaymentLink(
                                    widget.invoice,
                                  );
                              if (stripePaymentUrl != null) {
                                await _showInvoicePreview(
                                  stripePaymentUrl: stripePaymentUrl,
                                );
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to generate payment link',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.visibility, color: Colors.white),
                            label: Text('Preview'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFC700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _deleteInvoice,
                            icon: Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (widget.invoice.status == 'Pending') ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Edit logic: open form screen for editing
                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final updatedInvoice = Invoice(
                                id: widget.invoice.id,
                                customerName: data['customerName'] ?? '',
                                vehicleId: data['vehicleId'] ?? '',
                                date: (data['date'] as Timestamp).toDate(),
                                dueDate:
                                    (data['dueDate'] as Timestamp).toDate(),
                                subtotal: (data['subtotal'] ?? 0.0).toDouble(),
                                tax: (data['tax'] ?? 0.0).toDouble(),
                                total: (data['totalAmount'] ?? 0.0).toDouble(),
                                status: data['status'] ?? '',
                                parts: List<Map<String, dynamic>>.from(
                                  data['parts'] ?? [],
                                ),
                                discount: (data['discount'] ?? 0.0).toDouble(),
                                discountType: data['discountType'] ?? 'fixed',
                              );

                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => InvoiceFormScreen(
                                        invoice: updatedInvoice,
                                        isEditing: true,
                                      ),
                                ),
                              );

                              if (result == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Invoice updated successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: Icon(Icons.edit, color: Color(0xFF22211F)),
                            label: Text(
                              'Edit',
                              style: TextStyle(color: Color(0xFF22211F)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFC700),
                              foregroundColor: Color(0xFF22211F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: Text('Approve Invoice'),
                                      content: Text(
                                        'Are you sure you want to approve this invoice?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(false),
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('Approve'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirm == true) {
                                try {
                                  // Update the status in Firestore
                                  await FirebaseFirestore.instance
                                      .collection('Invoice')
                                      .doc(widget.invoice.id)
                                      .update({'status': 'Unpaid'});

                                  // Show success message
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Invoice approved successfully',
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        margin: EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Refresh page by popping and passing true
                                  Navigator.pop(context, true);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Failed to approve invoice'),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                        margin: EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: Icon(Icons.check_circle, color: Colors.white),
                            label: Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _deleteInvoice,
                            icon: Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ), // <-- force white
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.fromHeight(48),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Invoice'),
            content: Text(
              'Are you sure you want to delete this invoice? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      try {
        // Delete the invoice from Firestore
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(widget.invoice.id)
            .delete();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Invoice deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        // Show error message if deletion fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Failed to delete invoice'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  // Helper method to handle preview functionality
  Future<void> _showInvoicePreview({required String stripePaymentUrl}) async {
    // Get current document data to ensure we have latest values
    final docSnapshot =
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(widget.invoice.id)
            .get();
    final data = docSnapshot.data() as Map<String, dynamic>;

    // Use widget.invoice.status to maintain the original status
    final invoice = Invoice(
      id: widget.invoice.id,
      customerName: data['customerName'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      total: (data['totalAmount'] ?? 0.0).toDouble(),
      status: widget.invoice.status, // Keep the original status
      parts: List<Map<String, dynamic>>.from(data['parts'] ?? []),
      discount: (data['discount'] ?? 0.0).toDouble(),
      discountType: data['discountType'] ?? 'fixed',
      paymentDate: (data['paymentDate'] as Timestamp?)?.toDate(),
    );

    print('Debug - Created Invoice object:');
    print('Discount: ${invoice.discount}');
    print('Discount Type: ${invoice.discountType}');
    print('Total: ${invoice.total}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => InvoicePreviewScreen(
              invoice: invoice,
              stripePaymentUrl: stripePaymentUrl,
            ),
      ),
    );
  }

  // Update the _markAsPaid method in _InvoiceDetailScreenState
  Future<void> _markAsPaid(String paymentMethod, String note) async {
    try {
      // Update both status and payment date
      await FirebaseFirestore.instance
          .collection('Invoice')
          .doc(widget.invoice.id)
          .update({
            'status': 'Paid',
            'paymentMethod': paymentMethod,
            'paymentNote': note,
            'paymentDate': Timestamp.now(),
          });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Invoice Paid successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      // Navigate back to refresh the list
      Navigator.pop(context, true);
    } catch (e) {
      // Show error message if update fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to update payment status'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}

// Update the _BreakdownRow widget to include quantity and unit price
class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final int? quantity;
  final double? unitPrice;
  final Color? textColor; // Add this

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.quantity,
    this.unitPrice,
    this.textColor, // Add this
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: textColor, // Use the color if provided
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: textStyle)),
              Text(
                'RM ${value.abs().toStringAsFixed(2)}', // Use abs() for discount
                style: textStyle,
              ),
            ],
          ),
          if (quantity != null && unitPrice != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Quantity: $quantity × RM ${unitPrice!.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  // Change to StatefulWidget
  final Function(String method, String note) onPaid;
  const _PaymentMethodDialog({required this.onPaid});

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  String? selectedMethod;
  String note = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Cash'),
              leading: Radio<String>(
                value: 'Cash',
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() {
                    selectedMethod = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text('Bank Transfer'),
              leading: Radio<String>(
                value: 'Bank Transfer',
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() {
                    selectedMethod = value;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                onChanged: (value) {
                  setState(() {
                    note = value;
                  });
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (selectedMethod != null) {
                  widget.onPaid(selectedMethod!, note);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a payment method'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Confirm Payment', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

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
