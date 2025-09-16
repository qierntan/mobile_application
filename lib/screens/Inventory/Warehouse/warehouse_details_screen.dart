import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WarehouseDetailsScreen extends StatelessWidget {
  final String warehouseId;
  const WarehouseDetailsScreen({super.key, required this.warehouseId});

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
        title: const Text('Warehouse Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete warehouse?'),
                  content: const Text('This will remove the warehouse document.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) {
                await FirebaseFirestore.instance.collection('Warehouse').doc(warehouseId).delete();
                if (context.mounted) Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WarehouseEditScreen(warehouseId: warehouseId),
                ),
              );
              if (updated == true && context.mounted) {
                (context as Element).markNeedsBuild();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('Warehouse').doc(warehouseId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Warehouse not found'));
          }
          final data = snapshot.data!.data()!;
          final name = (data['warehouseName'] ?? 'Unknown').toString();
          final region = (data['region'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final phoneNumber = (data['phoneNumber'] ?? '').toString();
          final contactPerson = (data['contactPerson'] ?? '').toString();
          final deliver = (data['Deliver'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _infoRow(Icons.place_outlined, region.isEmpty ? 'Region: -' : region),
                    _infoRow(Icons.person_outline, contactPerson.isEmpty ? 'Contact: -' : contactPerson),
                    _infoRow(Icons.phone_outlined, phoneNumber.isEmpty ? 'Phone: -' : phoneNumber),
                    _infoRow(Icons.email_outlined, email.isEmpty ? 'Email: -' : email),
                    _infoRow(Icons.local_shipping_outlined, deliver.isEmpty ? 'Delivery: -' : deliver),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

class WarehouseEditScreen extends StatefulWidget {
  final String warehouseId;
  const WarehouseEditScreen({super.key, required this.warehouseId});

  @override
  State<WarehouseEditScreen> createState() => _WarehouseEditScreenState();
}

class _WarehouseEditScreenState extends State<WarehouseEditScreen> {
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance.collection('Warehouse').doc(widget.warehouseId).get();
    final d = snap.data();
    if (d == null) return;
    _name.text = (d['warehouseName'] ?? '').toString();
    _id.text = widget.warehouseId;
    _person.text = (d['contactPerson'] ?? '').toString();
    _phone.text = (d['phoneNumber'] ?? '').toString();
    _email.text = (d['email'] ?? '').toString();
    _region.text = (d['region'] ?? '').toString();
    _deliver.text = (d['Deliver'] ?? '').toString();
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('Warehouse').doc(_id.text.trim()).set({
        'warehouseName': _name.text.trim(),
        'contactPerson': _person.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'email': _email.text.trim(),
        'region': _region.text.trim(),
        'Deliver': _deliver.text.trim(),
      });
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
        title: const Text('Edit Warehouse Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('Warehouse Name', _name),
            _field('Warehouse ID', _id, enabled: false),
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
                    : const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {TextInputType? keyboardType, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: c,
        enabled: enabled,
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


