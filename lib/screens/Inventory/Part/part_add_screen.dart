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
  final TextEditingController _name = TextEditingController();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _threshold = TextEditingController();
  final TextEditingController _price = TextEditingController();

  String? _warehouse;
  String? _imageUrl;
  File? _imageFile;
  bool _save = false;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _qty.dispose();
    _threshold.dispose();
    _price.dispose();
    super.dispose();
  }

    Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _save) return;
    setState(() => _save = true);
    try {
      final id = _id.text.trim();
      String? imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!, id);
      }
      final data = {
        'partName': _name.text.trim(),
        'currentQty': int.tryParse(_qty.text.trim()) ?? 0,
        'partThreshold': int.tryParse(_threshold.text.trim()) ?? 0,
        'partPrice': double.tryParse(_price.text.trim()) ?? 0,
        'partWarehouse': _warehouse,
        'imageUrl': imageUrl,
      };
      final doc = FirebaseFirestore.instance.collection('Part').doc(id.isEmpty ? null : id);
      if (id.isEmpty) {
        await FirebaseFirestore.instance.collection('Part').add(data);
      } else {
        await doc.set(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _save = false);
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
            _field('Part Name', _name),
            _field('Part ID', _id),

             Padding(
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
                            ? Image.file(_imageFile!,
                                width: 100, height: 80, fit: BoxFit.cover)
                            : Container(
                                width: 100,
                                height: 80,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image,
                                    color: Colors.white),
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: _pickImage,
                      )
                    ],
                  ),
                ],
              ),
            ),

            _field('Current Quantity', _qty),
            _field('Minimum Threshold', _threshold),
            _field('Price Per Unit (RM)', _price),

            // Warehouse dropdown
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Warehouse')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final warehouses = snapshot.data!.docs
                      .map((d) => d['warehouseName'] as String)
                      .toList();
                  return DropdownButtonFormField<String>(
                    value: _warehouse,
                    items: warehouses
                        .map((w) => DropdownMenuItem(
                            value: w, child: Text(w)))
                        .toList(),
                    onChanged: (v) => setState(() => _warehouse = v),
                    decoration: InputDecoration(
                      labelText: 'Warehouse',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  );
                },
              ),
            ),
            
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: _save ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _save
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


