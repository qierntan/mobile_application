import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';
import 'package:mobile_application/configuration/config.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class InvoicePdfController {
  static HttpServer? _server;
  static bool _isRunning = false;

  static Future<void> generateAndShare(Invoice invoice) async {
    final pdf = pw.Document();
    final dateFormatter = DateFormat('dd MMM yyyy');

    final stripeUrl = await createStripePaymentLink(invoice);

    final qrImage =
        stripeUrl != null
            ? pw.BarcodeWidget(
              data: stripeUrl,
              barcode: pw.Barcode.qrCode(),
              width: 100,
              height: 100,
            )
            : pw.Text('Unable to generate payment link');

    pw.Widget buildItemsTable(List<Map<String, dynamic>> items) {
      if (items.isEmpty) return pw.Container();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(4), // Description
              1: const pw.FlexColumnWidth(1), // Quantity
              2: const pw.FlexColumnWidth(2), // Unit Price
              3: const pw.FlexColumnWidth(2), // Total
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Description',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Unit Price (RM)',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Total (RM)',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              ...items
                  .map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(item['description'] ?? '-'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            (item['quantity'] ?? 1).toString(),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            (item['unitPrice'] as double?)?.toStringAsFixed(
                                  2,
                                ) ??
                                '0.00',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            (item['total'] as double?)?.toStringAsFixed(2) ??
                                '0.00',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INVOICE',
                            style: pw.TextStyle(
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('Invoice ID: ${invoice.id}'),
                          pw.Text('Customer: ${invoice.customerName}'),
                          pw.Text('Vehicle: ${invoice.vehicleId}'),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (stripeUrl != null &&
                              invoice.status != 'Paid') ...[
                            pw.Text(
                              'Scan to Pay',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                            pw.SizedBox(height: 4),
                            qrImage,
                          ],
                          pw.SizedBox(height: 8),
                          if (invoice.status == 'Paid') ...[
                            pw.Text(
                              'Paid Date: ${dateFormatter.format(invoice.paymentDate ?? DateTime.now())}',
                              style: pw.TextStyle(color: PdfColors.black),
                            ),
                            pw.Text(
                              'Status: ${invoice.status}',
                              style: pw.TextStyle(
                                color: PdfColors.green,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            pw.Text(
                              'Due Date: ${dateFormatter.format(invoice.dueDate)}',
                            ),
                            pw.Text(
                              'Status: ${invoice.status}',
                              style: pw.TextStyle(color: PdfColors.black),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(height: 32),
                  buildItemsTable(invoice.parts),
                  pw.SizedBox(height: 12),
                  pw.Divider(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Subtotal: RM ${invoice.subtotal.toStringAsFixed(2)}',
                        ),
                        pw.Text('SST: RM   ${invoice.tax.toStringAsFixed(2)}'),
                        if (invoice.discount > 0)
                          pw.Text(
                            invoice.discountType == 'percentage'
                                ? 'Discount (${invoice.discount}%): -RM ${(invoice.subtotal * invoice.discount / 100).toStringAsFixed(2)}'
                                : 'Discount: -RM   ${invoice.discount.toStringAsFixed(2)}',
                          ),
                        pw.Divider(color: PdfColors.grey300, height: 16),
                        pw.Text(
                          'Total Amount: RM ${invoice.total.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<String?> createStripePaymentLink(Invoice invoice) async {
    // Get customer email from Firestore
    final customerDoc =
        await FirebaseFirestore.instance
            .collection('Customer')
            .where('cusName', isEqualTo: invoice.customerName)
            .limit(1)
            .get();

    if (customerDoc.docs.isEmpty) {
      print('Customer not found: ${invoice.customerName}');
      return null;
    }

    final customerEmail = customerDoc.docs.first.get('cusEmail') as String;

    final response = await http.post(
      Uri.parse('${Config.paymentServerUrl}/create-checkout-session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': invoice.total,
        'description': 'Invoice #${invoice.id}',
        'customer_email': customerEmail,
        'success_url':
            '${Config.paymentServerUrl}/success?session_id={CHECKOUT_SESSION_ID}&invoice_id=${invoice.id}&customer_email=$customerEmail',
        'cancel_url': '${Config.paymentServerUrl}/cancel',
        'metadata': {
          'invoice_id': invoice.id,
          'customer_name': invoice.customerName,
          'vehicle_number': invoice.vehicleId,
          'total_amount': invoice.total.toString(),
          'date': DateFormat('yyyy-MM-dd').format(invoice.date),
        },
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['url'];
    } else {
      return null;
    }
  }

  static Future<void> handlePaymentSuccess(
    String invoiceId,
    String customerEmail,
    String sessionId,
  ) async {
    try {
      print('Starting payment success handling...');
      print('Session ID: $sessionId');
      print('Invoice ID: $invoiceId');
      print('Customer Email: $customerEmail');

      // Get the invoice data
      print('Fetching invoice data from Firestore...');
      final invoiceDoc =
          await FirebaseFirestore.instance
              .collection('Invoice')
              .doc(invoiceId)
              .get();

      if (!invoiceDoc.exists) {
        print('Invoice not found in Firestore: $invoiceId');
        throw Exception('Invoice not found');
      }
      print('Invoice data retrieved successfully');

      final data = invoiceDoc.data() as Map<String, dynamic>;
      final invoice = Invoice(
        id: invoiceId,
        customerName: data['customerName'] ?? 'Unknown Customer',
        vehicleId: data['vehicleId'] ?? data['vehicleId'] ?? 'Unknown Vehicle',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        subtotal: (data['subtotal'] ?? 0.0).toDouble(),
        tax: (data['tax'] ?? 0.0).toDouble(),
        total: (data['totalAmount'] ?? 0.0).toDouble(),
        status: 'Paid',
        parts: List<Map<String, dynamic>>.from(data['parts'] ?? []),
        discount: (data['discount'] ?? 0.0).toDouble(),
        discountType: data['discountType'] ?? 'fixed',
      );

      // Update invoice status in Firestore - CRITICAL: Do this first
      print('Attempting to update Firestore for invoice $invoiceId...');
      try {
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(invoiceId)
            .update({
              'status': 'Paid',
              'paymentDate': FieldValue.serverTimestamp(),
              'paymentMethod': 'Online Payment',
              'paymentSessionId': sessionId,
            });
        print('✅ Invoice status successfully updated to Paid');
      } catch (e) {
        print('❌ CRITICAL ERROR: Failed to update Firestore: $e');
        // Don't throw here - continue with email
      }

      // Send confirmation email - Make this non-blocking
      print('Attempting to send confirmation email to $customerEmail...');
      try {
        await _sendPaymentConfirmationEmail(invoice, customerEmail, '');
        print('✅ Payment confirmation email sent successfully');
      } catch (emailError) {
        print('❌ Email sending failed (non-critical): $emailError');
        // Don't throw - email failure shouldn't break the payment flow
      }

      print('✅ Payment success handling completed');
    } catch (e) {
      print('❌ Error handling payment success: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

  static Future<void> _sendPaymentConfirmationEmail(
    Invoice invoice,
    String customerEmail,
    String paymentUrl,
  ) async {
    print('📧 Starting email send process...');
    print('Sending to: $customerEmail');
    print('Invoice ID: ${invoice.id}');

    try {
      print('⚙️ Configuring SMTP server...');
      final smtpServer = gmail(
        'kfuichong0412@gmail.com',
        'rsgt xnai tdqt ygml',
      );
      print('✅ SMTP server configured successfully');

      // Create HTML for items - handle empty parts gracefully
      final parts =
          invoice.parts.isNotEmpty
              ? invoice.parts
                  .map(
                    (part) => '''<tr>
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">${part['description'] ?? 'N/A'}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: center;">${part['quantity'] ?? 0}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">RM ${(part['unitPrice'] ?? 0.0).toStringAsFixed(2)}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">RM ${(part['total'] ?? 0.0).toStringAsFixed(2)}</td>
          </tr>''',
                  )
                  .join()
              : '<tr><td colspan="4" style="padding: 8px; text-align: center;">No items</td></tr>';

      final message =
          Message()
            ..from = Address('kfuichong0412@gmail.com', 'Invoice Management')
            ..recipients.add(customerEmail)
            ..subject = 'Payment Confirmation - Invoice #${invoice.id}'
            ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background-color: #4CAF50; padding: 20px; text-align: center;">
              <h1 style="color: white; margin: 0;">Thank You for Your Payment!</h1>
            </div>
            
            <div style="padding: 20px;">
              <p>Dear ${invoice.customerName},</p>
              <p>We have received your payment for Invoice #${invoice.id}. Thank you for your business!</p>
              
              <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <h3 style="margin-top: 0;">Payment Details:</h3>
                <p style="margin: 5px 0;">Invoice ID: #${invoice.id}</p>
                <p style="margin: 5px 0;">Vehicle Number: ${invoice.vehicleId}</p>
                <p style="margin: 5px 0;">Payment Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}</p>
                <p style="margin: 5px 0;">Total Amount Paid: RM ${invoice.total.toStringAsFixed(2)}</p>
              </div>

              <h3>Invoice Summary</h3>
              <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
                <tr style="background-color: #f5f5f5;">
                  <th style="padding: 12px 8px; text-align: left; border-bottom: 2px solid #ddd;">Description</th>
                  <th style="padding: 12px 8px; text-align: center; border-bottom: 2px solid #ddd;">Qty</th>
                  <th style="padding: 12px 8px; text-align: right; border-bottom: 2px solid #ddd;">Unit Price</th>
                  <th style="padding: 12px 8px; text-align: right; border-bottom: 2px solid #ddd;">Total</th>
                </tr>
                ${parts}
                <tr>
                  <td colspan="3" style="padding: 8px; text-align: right; font-weight: bold;">Subtotal:</td>
                  <td style="padding: 8px; text-align: right;">RM ${invoice.subtotal.toStringAsFixed(2)}</td>
                </tr>
                <tr>
                  <td colspan="3" style="padding: 8px; text-align: right; font-weight: bold;">SST (6%):</td>
                  <td style="padding: 8px; text-align: right;">RM ${invoice.tax.toStringAsFixed(2)}</td>
                </tr>
                ${invoice.discount > 0 ? '''
                <tr>
                  <td colspan="3" style="padding: 8px; text-align: right; font-weight: bold;">
                    ${invoice.discountType == 'percentage' ? 'Discount (${invoice.discount}%):' : 'Discount:'}
                  </td>
                  <td style="padding: 8px; text-align: right; color: #d32f2f;">
                    -RM ${invoice.discountType == 'percentage' ? (invoice.subtotal * invoice.discount / 100).toStringAsFixed(2) : invoice.discount.toStringAsFixed(2)}
                  </td>
                </tr>
                ''' : ''}
                <tr style="background-color: #f5f5f5;">
                  <td colspan="3" style="padding: 12px 8px; text-align: right; font-weight: bold;">Total Amount Paid:</td>
                  <td style="padding: 12px 8px; text-align: right; font-weight: bold;">RM ${invoice.total.toStringAsFixed(2)}</td>
                </tr>
              </table>

              <div style="margin-top: 30px; text-align: center; border-top: 1px solid #eee; padding-top: 20px;">
                <p style="color: #666;">This is an automatically generated receipt.</p>
                <p style="margin-bottom: 0;">Thank you for your business!</p>
                <p style="color: #666;">Invoice Management Team</p>
              </div>
            </div>
          </div>
        ''';

      print('📤 Attempting to send email...');
      final sendReport = await send(message, smtpServer);
      print('✅ Payment confirmation email sent successfully');
      print('📊 Send report: $sendReport');
    } catch (e, stack) {
      print('❌ Error sending payment confirmation email: $e');
      print('📋 Stack trace: $stack');
      throw Exception('Failed to send email: $e');
    }
  }

  static Future<void> setupPaymentSuccessHandler() async {
    if (kIsWeb) return; // Skip for web platform
    if (_isRunning) {
      print('Server is already running');
      return;
    }

    print('Setting up payment success handler on port 8081...');

    try {
      // Close any existing server instance
      await _server?.close();

      // Bind to all network interfaces and reuse address
      var server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        8081,
        shared: true,
      );
      _server = server;
      _isRunning = true;

      // Print network information for debugging
      print('✅ Payment success handler is listening on port 8081');
      print('🌐 Server accessible at:');
      print('   - localhost:8081');

      _server!.listen((HttpRequest request) async {
        print('Received request: ${request.method} ${request.uri.path}');
        print('Request headers:');
        request.headers.forEach((name, values) {
          print('$name: $values');
        });

        // Set CORS headers for all responses
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set(
          'Access-Control-Allow-Methods',
          'GET, POST, OPTIONS',
        );
        request.response.headers.set(
          'Access-Control-Allow-Headers',
          'Content-Type',
        );

        if (request.method == 'OPTIONS') {
          print('Handling OPTIONS request');
          request.response.statusCode = 200;
          await request.response.close();
          return;
        }

        try {
          if (request.uri.path == '/handle-payment-success' &&
              request.method == 'POST') {
            print('Processing payment success request...');

            final content = await utf8.decoder.bind(request).join();
            print('Received data: $content');

            final data = jsonDecode(content);
            print('Parsed data: $data');

            // Call your payment success handler
            await handlePaymentSuccess(
              data['invoice_id'],
              data['customer_email'],
              data['session_id'],
            );

            print('Payment processed successfully, sending response');
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'success': true,
                'message': 'Payment processed successfully',
              }),
            );
            await request.response.close();
          } else {
            print('Invalid path: ${request.uri.path}');
            request.response.statusCode = 404;
            request.response.write('Not Found');
            await request.response.close();
          }
        } catch (e, stack) {
          print('Error in payment success handler: $e');
          print('Stack trace: $stack');
          request.response.statusCode = 500;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'success': false, 'error': e.toString()}),
          );
          await request.response.close();
        }
      });
    } catch (e, stack) {
      print('Failed to start payment server: $e');
      print('Stack trace: $stack');
      _isRunning = false;
      rethrow;
    }
  }
}
