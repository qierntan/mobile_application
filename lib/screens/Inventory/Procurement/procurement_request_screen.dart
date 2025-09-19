import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_application/model/inventory_management/procurement.dart';
import 'package:mobile_application/model/inventory_management/part.dart';
import 'package:mobile_application/controller/inventory_management/procurement_controller.dart';
import 'package:mobile_application/controller/inventory_management/part_controller.dart';

class ProcurementRequestScreen extends StatefulWidget {
  final String partId;
  const ProcurementRequestScreen({Key? key, required this.partId}) : super(key: key);

  @override
  State<ProcurementRequestScreen> createState() => _ProcurementRequestScreenState();
}

class _ProcurementRequestScreenState extends State<ProcurementRequestScreen> {
  final ProcurementController _procurementController = ProcurementController();
  final PartController _partController = PartController();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  DateTime? _expectedDate;
  bool _save = false;
  Part? _part; // store loaded part details

  @override
  void initState() {
    super.initState();
    _loadPartDetails();
  }

  Future<void> _loadPartDetails() async {
    final part = await _partController.getPartById(widget.partId);
    if (mounted) {
      setState(() => _part = part);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _save) return;
    if (_part == null) return;
    setState(() => _save = true);

    try {
      final procurement = Procurement(
        partId: widget.partId,
        partName: _part!.partName,
        orderQty: int.parse(_qtyController.text),
        warehouse: _part!.partWarehouse!,
        requestedDate: DateTime.now(),
        expectedDate: _expectedDate,
        remarks: _remarksController.text.isNotEmpty ? _remarksController.text : null,
        status: ProcurementStatus.pending,
      );

      await _procurementController.addProcurement(procurement);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _save = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Procurement Request',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _part == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Part Name (read only)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Part Name'),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_part!.partName),
                        ),
                      ],
                    ),
                  ),

                  _field('Quantity', _qtyController,
                      keyboardType: TextInputType.number),

                  // Expected Date picker
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(
                            text: _expectedDate != null
                                ? DateFormat("yyyy-MM-dd")
                                    .format(_expectedDate!)
                                : "",
                          ),
                          decoration: InputDecoration(
                            labelText: "Expected Date",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                  ),

                  _field('Remarks (if any)', _remarksController,
                      validator: (_) => null),

                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _save ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _save
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {TextInputType? keyboardType,
      FormFieldValidator<String>? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
