import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';

class InvoiceFormScreen extends StatefulWidget {
  final Invoice? invoice;
  final bool isEditing;

  const InvoiceFormScreen({super.key, this.invoice, this.isEditing = false});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  List<Map<String, dynamic>> customers = [];
  Map<String, List<String>> customerVehicles = {};
  List<PartItem> partItems = [PartItem()];

  String? selectedCustomer;
  String? selectedVehicle;
  double discount = 0.0;
  final double taxRate = 0.06;
  bool isPercentDiscount = false;
  bool isDraft = false;
  DateTime? dueDate;

  double get subtotal {
    return partItems.fold(0, (sum, item) => sum + (item.total));
  }

  double get tax => subtotal * taxRate;

  double get discountAmount {
    if (isPercentDiscount) {
      return subtotal * (discount / 100);
    } else {
      return discount;
    }
  }

  double get total => subtotal + tax - discountAmount;

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      print("Initializing form with invoice data"); // Debug print
      print("Discount: ${widget.invoice!.discount}"); // Debug print
      print("Discount Type: ${widget.invoice!.discountType}"); // Debug print

      // Initialize form with existing invoice data
      selectedCustomer = widget.invoice!.customerName;
      selectedVehicle = widget.invoice!.vehicleNumber;
      dueDate = widget.invoice!.dueDate;

      // Initialize discount values
      discount = widget.invoice!.discount;
      isPercentDiscount = widget.invoice!.discountType == 'percentage';

      // Initialize parts
      partItems =
          widget.invoice!.parts
              .map(
                (part) => PartItem(
                  description: part['description'] ?? '',
                  quantity:
                      (part['quantity'] ?? 1)
                          as int, // Cast to ensure proper type
                  unitPrice:
                      (part['unitPrice'] ?? 0.0)
                          as double, // Cast to ensure proper type
                ),
              )
              .toList();

      if (partItems.isEmpty) {
        partItems = [PartItem()];
      }
    } else {
      // Set default due date for new invoices
      dueDate = DateTime.now().add(Duration(days: 30));
      discount = 0.0;
      isPercentDiscount = false;
    }
    _loadCustomers(); // Load customers from database
  }

  Future<void> _loadCustomers() async {
    try {
      final QuerySnapshot customerSnapshot =
          await FirebaseFirestore.instance.collection('Customer').get();

      setState(() {
        customers =
            customerSnapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'name':
                        (doc.data() as Map<String, dynamic>)['cusName'] ?? '',
                    'vehicles':
                        (doc.data() as Map<String, dynamic>)['vehicleIds'] ??
                        [],
                  },
                )
                .toList();

        // Create customer vehicles map
        customerVehicles.clear();
        for (var customer in customers) {
          customerVehicles[customer['name']] = List<String>.from(
            customer['vehicles'],
          );
        }
      });
    } catch (e) {
      print('Error loading customers: $e');
    }
  }

  Future<void> _submit() async {
    try {
      final invoiceData = {
        'customerName': selectedCustomer,
        'vehicleId': selectedVehicle,
        'date': widget.isEditing ? widget.invoice!.date : DateTime.now(),
        'dueDate': Timestamp.fromDate(dueDate!),
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'discountType': isPercentDiscount ? 'percentage' : 'fixed',
        'totalAmount': total,
        'status': widget.isEditing ? widget.invoice!.status : 'Pending',
        'parts':
            partItems
                .map(
                  (item) => {
                    'description': item.description,
                    'quantity': item.quantity,
                    'unitPrice': item.unitPrice,
                    'total': item.total,
                  },
                )
                .toList(),
      };

      if (widget.isEditing) {
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(widget.invoice!.id)
            .update(invoiceData);
      } else {
        // Generate a random 4-digit number
        final random = new DateTime.now().millisecondsSinceEpoch % 10000;
        final formattedRandom = random.toString().padLeft(4, '0');
        final invoiceId = 'Inv$formattedRandom';

        // Create new document with custom ID
        await FirebaseFirestore.instance
            .collection('Invoice')
            .doc(invoiceId)
            .set(invoiceData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Invoice created successfully: $invoiceId'),
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

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          dueDate ??
          DateTime.now().add(Duration(days: 30)), // Default to 30 days from now
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != dueDate) {
      setState(() {
        dueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Invoice' : 'Create Invoice'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Update the customer dropdown section
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Customer',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              value: selectedCustomer,
              items: customers
                  .map((c) => c['name'] as String)
                  .toList(
                    growable: false,
                  ) // Using fixed-length list for better performance
                  .map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  )
                  .toList(growable: false), // Fixed-length list for menu items
              onChanged: (value) {
                setState(() {
                  selectedCustomer = value;
                  selectedVehicle =
                      null; // Reset vehicle selection when customer changes
                });
              },
              hint: Text('Select Customer'),
            ),
            SizedBox(height: 12),
            // Update the vehicle dropdown section
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              value: selectedVehicle,
              items: (selectedCustomer != null
                      ? (customerVehicles[selectedCustomer] ?? []).toList(
                        growable: false,
                      )
                      : <String>[])
                  .map(
                    (vehicle) =>
                        DropdownMenuItem(value: vehicle, child: Text(vehicle)),
                  )
                  .toList(growable: false), // Fixed-length list for menu items
              onChanged:
                  selectedCustomer != null
                      ? (value) {
                        setState(() {
                          selectedVehicle = value;
                        });
                      }
                      : null,
              hint: Text(
                selectedCustomer == null
                    ? 'Select a customer first'
                    : 'Select Vehicle Number',
              ),
            ),
            SizedBox(height: 12),
            GestureDetector(
              onTap: () => _selectDueDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due Date',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dueDate != null
                          ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                          : 'Select Due Date',
                      style: TextStyle(
                        color:
                            dueDate != null
                                ? Colors.black
                                : Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Parts/Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // List Items
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: partItems.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.teal.shade50),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              children: [
                                // Description Field
                                TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.teal.shade100,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.teal,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  initialValue:
                                      partItems[index]
                                          .description, // Add this line
                                  maxLines: null,
                                  onChanged: (val) {
                                    setState(() {
                                      partItems[index].description = val;
                                    });
                                  },
                                ),
                                SizedBox(height: 12),
                                // Quantity and Unit Price Row
                                Row(
                                  children: [
                                    // Quantity Field
                                    Expanded(
                                      child: TextFormField(
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          labelText: 'Quantity',
                                          filled: true,
                                          fillColor: Colors.white,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.teal.shade100,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.teal,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        initialValue:
                                            partItems[index].quantity
                                                .toString(), // Add this line
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          setState(() {
                                            partItems[index].quantity =
                                                int.tryParse(val) ?? 1;
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Unit Price Field
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          labelText: 'Unit Price (RM)',
                                          filled: true,
                                          fillColor: Colors.white,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.teal.shade100,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.teal,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        initialValue: partItems[index].unitPrice
                                            .toStringAsFixed(
                                              2,
                                            ), // Add this line
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          setState(() {
                                            partItems[index].unitPrice =
                                                double.tryParse(val) ?? 0.0;
                                          });
                                        },
                                      ),
                                    ),
                                    // Delete Button
                                    if (partItems.length > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: IconButton(
                                          icon: Icon(Icons.delete_outline),
                                          color: Colors.red.shade400,
                                          onPressed: () {
                                            setState(() {
                                              partItems.removeAt(index);
                                            });
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // Total Row
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.teal.shade100,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                      Text(
                                        'RM ${partItems[index].total.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal.shade700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add Item Button
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          partItems.add(PartItem());
                        });
                      },
                      icon: Icon(Icons.add_circle_outline),
                      label: Text('Add New Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Discount',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: discount.toString(), // Add this line
                    onChanged: (value) {
                      setState(() {
                        discount = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                ToggleButtons(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('RM'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('%'),
                    ),
                  ],
                  onPressed: (index) {
                    setState(() {
                      isPercentDiscount = index == 1;
                    });
                  },
                  isSelected: [!isPercentDiscount, isPercentDiscount],
                ),
              ],
            ),
            SizedBox(height: 12),
            Card(
              color: Color.fromARGB(255, 243, 235, 207),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Subtotal', value: subtotal),
                    _SummaryRow(label: 'GST (6%)', value: tax),
                    _SummaryRow(label: 'Discount', value: -discountAmount),
                    Divider(),
                    _SummaryRow(label: 'Total', value: total, isBold: true),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(48),
                      textStyle: TextStyle(fontSize: 16),
                      side: BorderSide(color: Colors.grey),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFC700),
                      foregroundColor: Color(0xFF22211F),
                      minimumSize: Size.fromHeight(48),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    child: Text('Submit Invoice'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                isBold
                    ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22211F),
                    )
                    : TextStyle(color: Color(0xFF22211F)),
          ),
          Text(
            (value < 0 ? '- ' : '') + 'RM ${value.abs().toStringAsFixed(2)}',
            style:
                isBold
                    ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22211F),
                    )
                    : TextStyle(color: Color(0xFF22211F)),
          ),
        ],
      ),
    );
  }
}

class PartItem {
  String description;
  int quantity;
  double unitPrice;

  PartItem({this.description = '', this.quantity = 1, this.unitPrice = 0.0});

  double get total => quantity * unitPrice;
}
