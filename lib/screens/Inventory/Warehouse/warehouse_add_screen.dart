import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WarehouseAddScreen extends StatefulWidget {
  const WarehouseAddScreen({super.key});

  @override
  State<WarehouseAddScreen> createState() => _WarehouseAddScreenState();
}

class _WarehouseAddScreenState extends State<WarehouseAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _person = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _region = TextEditingController();
  final TextEditingController _deliver = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _person.dispose();
    _phone.dispose();
    _email.dispose();
    _region.dispose();
    _deliver.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final data = {
        'warehouseName': _name.text.trim(),
        'contactPerson': _person.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'email': _email.text.trim(),
        'region': _region.text.trim(),
        'Deliver': _deliver.text.trim(),
      };
      final id = _id.text.trim();
      final doc = FirebaseFirestore.instance.collection('Warehouse').doc(id.isEmpty ? null : id);
      if (id.isEmpty) {
        await FirebaseFirestore.instance.collection('Warehouse').add(data);
      } else {
        await doc.set(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Add New Warehouse', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('Warehouse Name', _name),
            _field('Warehouse ID', _id),
            _field('Contact Person', _person),
            _field('Phone Number', _phone, keyboardType: TextInputType.phone),
            _field('Email', _email, keyboardType: TextInputType.emailAddress),
            _field('Region', _region),
            _field('Delivery Lead Time', _deliver),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}


