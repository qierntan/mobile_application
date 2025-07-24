import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddVehicleScreen extends StatefulWidget {
  final String customerId;
  final String? vehicleId;
  final Map<String, dynamic>? vehicleData;

  const AddVehicleScreen({
    Key? key,
    required this.customerId,
    this.vehicleId,
    this.vehicleData,
  }) : super(key: key);

  @override
  _AddVehicleScreenState createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _vinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.vehicleData != null) {
      _makeController.text = widget.vehicleData!['make'] ?? '';
      _modelController.text = widget.vehicleData!['model'] ?? '';
      _yearController.text = widget.vehicleData!['year']?.toString() ?? '';
      _vinController.text = widget.vehicleData!['vin'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicleId == null ? 'Add Vehicle' : 'Edit Vehicle'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _makeController,
                decoration: InputDecoration(labelText: 'Make', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Enter make' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Enter model' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _yearController,
                decoration: InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty || int.tryParse(value) == null ? 'Enter valid year' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _vinController,
                decoration: InputDecoration(labelText: 'VIN', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Enter VIN' : null,
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
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final vehicle = {
                          'make': _makeController.text,
                          'model': _modelController.text,
                          'year': int.parse(_yearController.text),
                          'vin': _vinController.text,
                          'service_history': widget.vehicleData != null ? widget.vehicleData!['service_history'] : {},
                        };
                        final vehicleRef = FirebaseFirestore.instance.collection('vehicles');
                        String newVehicleId = DateTime.now().millisecondsSinceEpoch.toString();
                        if (widget.vehicleId == null) {
                          await vehicleRef.doc(newVehicleId).set(vehicle);
                          await FirebaseFirestore.instance
                              .collection('Customer')
                              .doc(widget.customerId)
                              .update({
                            'vehicleIds': FieldValue.arrayUnion([newVehicleId]),
                          });
                        } else {
                          await vehicleRef.doc(widget.vehicleId).update(vehicle);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(widget.vehicleId == null ? 'Vehicle added' : 'Vehicle updated')),
                        );
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