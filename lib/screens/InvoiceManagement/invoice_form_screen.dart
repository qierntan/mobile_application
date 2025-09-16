import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_application/model/invoice_management/invoice.dart';

class InvoiceFormScreen extends StatefulWidget {
  final Invoice? invoice;
  final bool isEditing;

  const InvoiceFormScreen({super.key, this.invoice, this.isEditing = false});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerFieldController = TextEditingController();
  final _vehicleFieldController = TextEditingController();
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
      selectedVehicle = widget.invoice!.vehicleId;
      _customerFieldController.text = widget.invoice!.customerName;
      _vehicleFieldController.text = widget.invoice!.vehicleId;
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

  @override
  void dispose() {
    _customerFieldController.dispose();
    _vehicleFieldController.dispose();
    super.dispose();
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
      // Validate form fields
      if (!_validateAndSaveForm()) return;

      final invoiceData = {
        'customerName': _customerFieldController.text.trim(),
        'vehicleId': _vehicleFieldController.text.trim(),
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

  bool _validateAndSaveForm() {
    final formValid = _formKey.currentState?.validate() ?? false;

    // Due date check
    if (dueDate == null) {
      _showError('Please select a due date.');
      return false;
    }

    // Customer & vehicle validation
    if (_customerFieldController.text.trim().isEmpty) {
      _showError('Please enter or select a customer.');
      return false;
    }
    if (_vehicleFieldController.text.trim().isEmpty) {
      _showError('Please enter or select a vehicle ID.');
      return false;
    }

    // Optional: Validate if customer exists and vehicle belongs to customer
    if (selectedCustomer != null && selectedVehicle != null) {
      final vehicles = customerVehicles[selectedCustomer] ?? const <String>[];
      if (!vehicles.contains(selectedVehicle)) {
        _showError('Selected vehicle does not belong to the chosen customer.');
        return false;
      }
    }

    // Parts validation
    if (!_validateParts()) return false;

    // Discount validation against amounts
    final baseTotal = subtotal + tax; // before discount
    if (!isPercentDiscount) {
      if (discount < 0) {
        _showError('Discount cannot be negative.');
        return false;
      }
      if (discount > baseTotal) {
        _showError(
          'Discount cannot exceed subtotal + tax (RM ${baseTotal.toStringAsFixed(2)}).',
        );
        return false;
      }
    } else {
      if (discount < 0 || discount > 100) {
        _showError('Percentage discount must be between 0 and 100.');
        return false;
      }
    }

    if (!formValid) return false;
    return true;
  }

  bool _validateParts() {
    if (partItems.isEmpty) {
      _showError('Please add at least one part/service.');
      return false;
    }
    for (int i = 0; i < partItems.length; i++) {
      final p = partItems[i];
      if (p.description.trim().isEmpty) {
        _showError('Item ${i + 1}: description is required.');
        return false;
      }
      if (p.quantity <= 0) {
        _showError('Item ${i + 1}: quantity must be at least 1.');
        return false;
      }
      if (p.unitPrice < 0) {
        _showError('Item ${i + 1}: unit price cannot be negative.');
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      body: Form(
        key: _formKey,
        autovalidateMode:
            AutovalidateMode.disabled, // Changed from onUserInteraction
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Customer field with dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _customerFieldController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      hintText: 'Type or select customer',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: PopupMenuButton<String>(
                        icon: Icon(Icons.arrow_drop_down),
                        onSelected: (String value) {
                          setState(() {
                            _customerFieldController.text = value;
                            selectedCustomer = value;
                            _vehicleFieldController.clear();
                            selectedVehicle = null;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          // Filter customers based on what's typed
                          String searchText =
                              _customerFieldController.text.toLowerCase();
                          List<String> filteredCustomers =
                              customers
                                  .map((customer) => customer['name'] as String)
                                  .where(
                                    (name) =>
                                        name.toLowerCase().contains(searchText),
                                  )
                                  .toList();

                          if (filteredCustomers.isEmpty) {
                            filteredCustomers =
                                customers
                                    .map(
                                      (customer) => customer['name'] as String,
                                    )
                                    .toList();
                          }

                          return filteredCustomers.map<PopupMenuEntry<String>>((
                            String value,
                          ) {
                            return PopupMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedCustomer =
                            customers.firstWhere(
                              (c) => c['name'] == value,
                              orElse: () => {},
                            )['name'];
                        if (selectedCustomer != value) {
                          selectedCustomer = null;
                        }
                        // Clear vehicle when customer changes
                        _vehicleFieldController.clear();
                        selectedVehicle = null;
                      });
                    },
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter or select customer name'
                                : null,
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Vehicle field with dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _vehicleFieldController,
                    enabled: _customerFieldController.text.trim().isNotEmpty,
                    decoration: InputDecoration(
                      labelText: 'Vehicle ID',
                      hintText:
                          _customerFieldController.text.trim().isEmpty
                              ? 'Please select a customer first'
                              : 'Type or select vehicle',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon:
                          _customerFieldController.text.trim().isNotEmpty
                              ? PopupMenuButton<String>(
                                icon: Icon(Icons.arrow_drop_down),
                                onSelected: (String value) {
                                  setState(() {
                                    _vehicleFieldController.text = value;
                                    selectedVehicle = value;
                                  });
                                },
                                itemBuilder: (BuildContext context) {
                                  List<String> availableVehicles = [];

                                  if (selectedCustomer != null) {
                                    availableVehicles =
                                        customerVehicles[selectedCustomer] ??
                                        [];
                                  } else {
                                    String typedCustomer =
                                        _customerFieldController.text.trim();
                                    String? matchedCustomer = customerVehicles
                                        .keys
                                        .firstWhere(
                                          (customerName) =>
                                              customerName.toLowerCase() ==
                                              typedCustomer.toLowerCase(),
                                          orElse: () => '',
                                        );

                                    if (matchedCustomer.isNotEmpty) {
                                      availableVehicles =
                                          customerVehicles[matchedCustomer] ??
                                          [];
                                    }
                                  }

                                  return availableVehicles
                                      .map<PopupMenuEntry<String>>((
                                        String value,
                                      ) {
                                        return PopupMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      })
                                      .toList();
                                },
                              )
                              : Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey[400],
                              ),
                      fillColor:
                          _customerFieldController.text.trim().isEmpty
                              ? Colors.grey[100]
                              : null,
                      filled: _customerFieldController.text.trim().isEmpty,
                    ),
                    onChanged: (value) {
                      if (_customerFieldController.text.trim().isNotEmpty) {
                        setState(() {
                          selectedVehicle = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (_customerFieldController.text.trim().isEmpty) {
                        return 'Please select a customer first';
                      }
                      return value == null || value.trim().isEmpty
                          ? 'Please enter or select vehicle ID'
                          : null;
                    },
                  ),
                  if (_customerFieldController.text.trim().isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Please fill in customer name to enable vehicle selection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else if (selectedCustomer != null &&
                      customerVehicles[selectedCustomer]?.isNotEmpty == true)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Available vehicles for $selectedCustomer: ${customerVehicles[selectedCustomer]?.join(", ")}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    )
                  else if (_customerFieldController.text.trim().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Builder(
                        builder: (context) {
                          String typedCustomer =
                              _customerFieldController.text.trim();

                          String? matchedCustomer = customerVehicles.keys
                              .firstWhere(
                                (customerName) =>
                                    customerName.toLowerCase() ==
                                    typedCustomer.toLowerCase(),
                                orElse: () => '',
                              );

                          if (matchedCustomer.isEmpty) {
                            matchedCustomer =
                                customerVehicles.keys
                                    .where(
                                      (customerName) =>
                                          customerName.toLowerCase().contains(
                                            typedCustomer.toLowerCase(),
                                          ) ||
                                          typedCustomer.toLowerCase().contains(
                                            customerName.toLowerCase(),
                                          ),
                                    )
                                    .firstOrNull;
                          }

                          if (matchedCustomer != null &&
                              customerVehicles[matchedCustomer]?.isNotEmpty ==
                                  true) {
                            return Text(
                              'Available vehicles for $matchedCustomer: ${customerVehicles[matchedCustomer]?.join(", ")}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
                          } else {
                            return Text(
                              'No vehicles found for "$typedCustomer". Please select a valid customer.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],
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
                      padding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFC700),
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
                          color: Color(0xFF22211F),
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
                              side: BorderSide(
                                color: Color(0xFFFFC700).withOpacity(0.3),
                              ),
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
                                          color: Color(
                                            0xFFFFC700,
                                          ).withOpacity(0.5),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Color(0xFFFFC700),
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
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Description is required';
                                      }
                                      return null;
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Color(
                                                  0xFFFFC700,
                                                ).withOpacity(0.5),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Color(0xFFFFC700),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          initialValue:
                                              partItems[index].quantity
                                                  .toString(), // Add this line
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              partItems[index].quantity =
                                                  int.tryParse(val) ?? 1;
                                            });
                                          },
                                          validator: (val) {
                                            final q = int.tryParse(val ?? '');
                                            if (q == null || q <= 0) {
                                              return 'Enter a valid quantity (>=1)';
                                            }
                                            return null;
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Color(
                                                  0xFFFFC700,
                                                ).withOpacity(0.5),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Color(0xFFFFC700),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          initialValue: partItems[index]
                                              .unitPrice
                                              .toStringAsFixed(
                                                2,
                                              ), // Add this line
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d{0,2}'),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              partItems[index].unitPrice =
                                                  double.tryParse(val) ?? 0.0;
                                            });
                                          },
                                          validator: (val) {
                                            final p = double.tryParse(
                                              val ?? '',
                                            );
                                            if (p == null || p < 0) {
                                              return 'Enter a valid price (>=0)';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      // Delete Button
                                      if (partItems.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
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
                                      color: Color(0xFFFFC700).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(
                                          0xFFFFC700,
                                        ).withOpacity(0.5),
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
                                            color: Color(0xFF22211F),
                                          ),
                                        ),
                                        Text(
                                          'RM ${partItems[index].total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF22211F),
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
                          backgroundColor: Color(0xFFFFC700),
                          foregroundColor: Color(0xFF22211F),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      initialValue: discount.toString(), // Add this line
                      onChanged: (value) {
                        setState(() {
                          discount = double.tryParse(value) ?? 0.0;
                        });
                      },
                      validator: (val) {
                        final d = double.tryParse(val ?? '');
                        if (d == null || d < 0) {
                          return 'Enter a valid discount (>=0)';
                        }
                        if (isPercentDiscount && (d < 0 || d > 100)) {
                          return 'Percent must be 0 - 100';
                        }
                        if (!isPercentDiscount) {
                          final maxFixed = subtotal + tax;
                          if (d > maxFixed) {
                            return 'Cannot exceed RM ${maxFixed.toStringAsFixed(2)}';
                          }
                        }
                        return null;
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
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: Colors.grey[600]!),
                        foregroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.isEditing ? 'Update Invoice' : 'Create Invoice',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
