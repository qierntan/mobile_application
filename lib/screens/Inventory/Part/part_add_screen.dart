import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PartAddScreen extends StatefulWidget {
  const PartAddScreen({super.key});

  @override
  State<PartAddScreen> createState() => _PartAddScreenState();
}

class _PartAddScreenState extends State<PartAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _description = TextEditingController();
  final _qty = TextEditingController();
  final _threshold = TextEditingController();
  final _price = TextEditingController();

  String? _warehouse;
  File? _imageFile;
  bool _save = false;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _description.dispose();
    _qty.dispose();
    _threshold.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage(File file, String partId) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('parts/$partId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image upload failed: $e");
      return null;
    }
  }

  String formatPartName(String input) {
    if (input.trim().isEmpty) return input;
    return input
        .split(' ')
        .map((w) => w.isNotEmpty
            ? w[0].toUpperCase() + w.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  Future<bool> _isDuplicateName(String name) async {
    final duplicate = await FirebaseFirestore.instance
        .collection('Part')
        .where('partName', isEqualTo: formatPartName(name))
        .limit(1)
        .get();
    return duplicate.docs.isNotEmpty;
  }

  Future<bool> _idExists(String id) async {
    final doc = await FirebaseFirestore.instance.collection('Part').doc(id).get();
    return doc.exists;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _save) return;
    setState(() => _save = true);

    try {
      final id = _id.text.trim();
      final formattedName = formatPartName(_name.text.trim());

      if (await _isDuplicateName(formattedName)) {
        _showError('Part name already exists!');
        return;
      }
      if (await _idExists(id)) {
        _showError('Part ID already exists!');
        return;
      }

      String? imageUrl;
      if (_imageFile != null) imageUrl = await _uploadImage(_imageFile!, id);

      final data = {
        'partName': formattedName,
        'currentQty': int.tryParse(_qty.text.trim()) ?? 0,
        'partThreshold': int.tryParse(_threshold.text.trim()) ?? 0,
        'partPrice': double.tryParse(_price.text.trim()) ?? 0,
        'partWarehouse': _warehouse,
        'description': _description.text.trim(),
        'imageUrl': imageUrl,
      };

      await FirebaseFirestore.instance.collection('Part').doc(id).set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Part added successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _save = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _save = false);
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
        title: const Text('Add New Part', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField('Part Name', _name, minLength: 3),
            _buildTextField('Part ID', _id, pattern: r'^[A-Z0-9-]+$', patternError: 'Only uppercase letters, numbers, "-" allowed'),
            _buildTextField('Description', _description, multiline: true),

            _buildImagePicker(),

            _buildTextField('Current Quantity', _qty, isNumber: true),
            _buildTextField('Minimum Threshold', _threshold, isNumber: true),
            _buildTextField('Price Per Unit (RM)', _price, isDecimal: true),

            _buildWarehouseDropdown(),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _save ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _save
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isDecimal = false,
    int? minLength,
    String? pattern,
    String? patternError,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: multiline
            ? TextInputType.multiline
            : isNumber
                ? TextInputType.number
                : isDecimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
        maxLines: multiline ? null : 1,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (minLength != null && v.trim().length < minLength) return 'Must be at least $minLength characters';
          if (isNumber && int.tryParse(v.trim()) == null) return 'Enter a valid integer';
          if (isDecimal && double.tryParse(v.trim()) == null) return 'Enter a valid number';
          if (pattern != null && !RegExp(pattern).hasMatch(v.trim())) return patternError ?? 'Invalid format';
          return null;
        },
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

  Widget _buildImagePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Part Image'),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _imageFile != null
                    ? Image.file(_imageFile!, width: 100, height: 80, fit: BoxFit.contain)
                    : Container(
                        width: 100,
                        height: 80,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, color: Colors.white),
                      ),
              ),
              IconButton(icon: const Icon(Icons.upload_file), onPressed: _pickImage)
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Warehouse').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final warehouses = snapshot.data!.docs.map((d) => d['warehouseName'] as String).toList();
          return DropdownButtonFormField<String>(
            value: _warehouse,
            items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
            onChanged: (v) => setState(() => _warehouse = v),
            decoration: InputDecoration(
              labelText: 'Warehouse',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          );
        },
      ),
    );
  }

}
