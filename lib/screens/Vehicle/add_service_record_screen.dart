import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddServiceRecordScreen extends StatefulWidget {
  final String customerId;
  final String vehicleId;

  const AddServiceRecordScreen({
    Key? key,
    required this.customerId,
    required this.vehicleId,
  }) : super(key: key);

  @override
  _AddServiceRecordScreenState createState() => _AddServiceRecordScreenState();
}

class _AddServiceRecordScreenState extends State<AddServiceRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceTypeController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Service Record'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _serviceTypeController,
                decoration: InputDecoration(labelText: 'Service Type', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Enter service type' : null,
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Text(
                  _selectedDate == null
                      ? 'Select Service Date'
                      : 'Date: ${_selectedDate!.toIso8601String().split('T')[0]}',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && _selectedDate != null) {
                        String serviceId = DateTime.now().millisecondsSinceEpoch.toString();
                        final service = {
                          'service_type': _serviceTypeController.text,
                          'date': _selectedDate!.toIso8601String(),
                          'notes': _notesController.text,
                        };
                        FirebaseFirestore.instance
                            .collection('vehicles')
                            .doc(widget.vehicleId)
                            .update({
                          'service_history.$serviceId': service,
                        }).then((_) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Service record added')),
                          );
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    child: Text('Save'),
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