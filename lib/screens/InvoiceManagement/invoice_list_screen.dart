import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';
import 'package:mobile_application/screens/InvoiceManagement/invoice_details_screen.dart';
import 'package:mobile_application/controller/invoice_management/invoice_controller.dart';
import 'invoice_form_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String searchQuery = '';
  String filterStatus = 'All';
  final InvoiceController _controller = InvoiceController();
  bool _isCheckingOverdue = false;

  @override
  void initState() {
    super.initState();
    _checkAndUpdateOverdueInvoices();
  }

  // Check and update overdue invoices when screen loads
  Future<void> _checkAndUpdateOverdueInvoices() async {
    if (_isCheckingOverdue) return; // Prevent multiple simultaneous calls

    setState(() {
      _isCheckingOverdue = true;
    });

    try {
      await _controller.updateAllOverdueInvoices();
    } catch (e) {
      print('Error checking overdue invoices: $e');
      // Don't show error to user as this is a background operation
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOverdue = false;
        });
      }
    }
  }

  // Refresh function to reload data
  Future<void> _refreshInvoices() async {
    try {
      // Update overdue invoices and refresh data
      await _checkAndUpdateOverdueInvoices();
    } catch (e) {
      print('Error refreshing invoices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing invoices'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Summary widgets using StreamBuilder
          StreamBuilder<QuerySnapshot>(
            stream: _controller.getAllInvoicesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Something went wrong');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                // Show empty summary cards while loading
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      _SummaryCard(label: 'Paid', value: '0'),
                      _SummaryCard(label: 'Unpaid', value: '0'),
                      _SummaryCard(label: 'Overdue', value: '0'),
                    ],
                  ),
                );
              }

              final invoices = snapshot.data!.docs;
              final paidCount =
                  invoices.where((doc) => doc['status'] == 'Paid').length;
              final unpaidCount =
                  invoices.where((doc) => doc['status'] == 'Unpaid').length;
              final overdueCount =
                  invoices.where((doc) => doc['status'] == 'Overdue').length;

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    _SummaryCard(label: 'Paid', value: '$paidCount'),
                    _SummaryCard(label: 'Unpaid', value: '$unpaidCount'),
                    _SummaryCard(label: 'Overdue', value: '$overdueCount'),
                  ],
                ),
              );
            },
          ),

          // Filter and search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: filterStatus,
                  items:
                      ['All', 'Paid', 'Unpaid', 'Overdue', 'Pending']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      filterStatus = value!;
                    });
                  },
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, vehicle, ID',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // Invoice list using StreamBuilder
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshInvoices,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('Invoice')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Something went wrong'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          if (_isCheckingOverdue) ...[
                            SizedBox(height: 16),
                            Text(
                              'Checking overdue invoices...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  var invoices = snapshot.data!.docs;

                  // Apply filters
                  invoices =
                      invoices.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final matchesStatus =
                            filterStatus == 'All' ||
                            data['status'] == filterStatus;

                        final matchesSearch =
                            data['customerName']
                                .toString()
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()) ||
                            data['vehicleId'].toString().toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            );

                        return matchesStatus && matchesSearch;
                      }).toList();

                  if (invoices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No invoices found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a new invoice to get started',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort: Custom priority order - Pending → Overdue → Unpaid → Paid, then by date
                  invoices.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aStatus = aData['status'] as String;
                    final bStatus = bData['status'] as String;

                    // Define priority order: Pending → Overdue → Unpaid → Paid
                    int getStatusPriority(String status) {
                      switch (status.toLowerCase()) {
                        case 'pending':
                          return 1;
                        case 'overdue':
                          return 2;
                        case 'unpaid':
                          return 3;
                        case 'paid':
                          return 4;
                        default:
                          return 5; // Any other status goes last
                      }
                    }

                    final aPriority = getStatusPriority(aStatus);
                    final bPriority = getStatusPriority(bStatus);

                    // First sort by status priority
                    if (aPriority != bPriority) {
                      return aPriority.compareTo(bPriority);
                    }

                    // If same status, sort by date (most recent first)
                    final aDate = (aData['date'] as Timestamp).toDate();
                    final bDate = (bData['date'] as Timestamp).toDate();
                    return bDate.compareTo(aDate);
                  });

                  return ListView.builder(
                    itemCount: invoices.length,
                    itemBuilder: (context, index) {
                      final data =
                          invoices[index].data() as Map<String, dynamic>;
                      final dueDate =
                          data['dueDate'] != null
                              ? (data['dueDate'] as Timestamp).toDate()
                              : null;

                      final invoice = Invoice(
                        id: invoices[index].id,
                        customerName: data['customerName'] ?? '',
                        vehicleId: data['vehicleId'] ?? '',
                        date: (data['date'] as Timestamp).toDate(),
                        dueDate:
                            dueDate ?? DateTime.now().add(Duration(days: 30)),
                        total: (data['totalAmount'] ?? 0.0).toDouble(),
                        status: data['status'] ?? '',
                        subtotal: (data['subtotal'] ?? 0.0).toDouble(),
                        tax: (data['tax'] ?? 0.0).toDouble(),
                        parts: List<Map<String, dynamic>>.from(
                          data['parts'] ?? [],
                        ),
                      );

                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFFFFC700),
                            child: Icon(
                              Icons.receipt,
                              color: Color(0xFF22211F),
                            ),
                          ),
                          title: Text(
                            invoice.customerName,
                            style: TextStyle(
                              color: Color(0xFF22211F),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_car_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    invoice.vehicleId,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(invoice.date),
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        invoice.status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getStatusColor(
                                          invoice.status,
                                        ).withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      invoice.status,
                                      style: TextStyle(
                                        color: _getStatusColor(invoice.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Text(
                            'RM ${invoice.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Color(0xFF22211F),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        InvoiceDetailScreen(invoice: invoice),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFFFC700),
        foregroundColor: Color(0xFF22211F),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoiceFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'unpaid':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'pending':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: Color(0xFFF6F2EA),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22211F),
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 16, color: Color(0xFF22211F)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
