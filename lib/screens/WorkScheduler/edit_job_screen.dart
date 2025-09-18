import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditJobScreen extends StatefulWidget {
  final String jobId;

  const EditJobScreen({super.key, required this.jobId});

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loading = true;
  String _plateNumber = '';
  String _year = '';
  String _vin = '';
  String _serviceType = '';
  String? _selectedMechanicId; // null means Unassigned
  DateTime? _selectedDateTime;
  List<Map<String, String>> _mechanics = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final jobDoc = await FirebaseFirestore.instance.collection('Jobs').doc(widget.jobId).get();
      if (!jobDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job not found')),
          );
          Navigator.pop(context);
        }
        return;
      }
      final jobData = jobDoc.data() as Map<String, dynamic>;

      // vehicle fields
      final String vehicleId = (jobData['vehicleId'] ?? '').toString();
      String plate = '';
      String year = '';
      String vin = '';
      if (vehicleId.isNotEmpty) {
        try {
          final vehicleDoc = await FirebaseFirestore.instance.collection('Vehicle').doc(vehicleId).get();
          if (vehicleDoc.exists) {
            final v = vehicleDoc.data()!;
            plate = (v['carPlateNumber'] ?? '').toString();
            year = (v['year'] ?? '').toString();
            vin = (v['vin'] ?? '').toString();
          }
        } catch (_) {}
      }

      // load mechanics list from Mechanics collection
      List<Map<String, String>> mechanics = [];
      try {
        final mechSnap = await FirebaseFirestore.instance
            .collection('Mechanics')
            .get();
        mechanics = mechSnap.docs.map((d) {
          final m = d.data();
          return {
            'mechanicId': (m['mechanicId'] ?? '').toString(),
            'name': (m['name'] ?? '').toString(),
          };
        }).where((e) => e['mechanicId']!.isNotEmpty && e['name']!.isNotEmpty).toList();
      } catch (_) {}

      final Timestamp? ts = jobData['time'] as Timestamp?;
      final DateTime? dt = ts?.toDate();

      setState(() {
        _plateNumber = plate;
        _year = year;
        _vin = vin;
        _serviceType = (jobData['serviceType'] ?? '').toString();
        _mechanics = mechanics;
        // Prefer mechanicId; fallback: map mechanicName to id if present
        final jobMechanicId = (jobData['mechanicId'] ?? '').toString().trim();
        if (jobMechanicId.isNotEmpty) {
          _selectedMechanicId = jobMechanicId;
        } else {
          final mechName = (jobData['mechanicName'] ?? '').toString().trim();
          final match = _mechanics.firstWhere(
            (m) => m['name'] == mechName,
            orElse: () => const {'mechanicId': '', 'name': ''},
          );
          _selectedMechanicId = (match['mechanicId'] ?? '').isEmpty ? null : match['mechanicId'];
        }
        _selectedDateTime = dt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load job: $e')),
      );
      setState(() { _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await FirebaseFirestore.instance.collection('Jobs').doc(widget.jobId).update({
        'mechanicId': _selectedMechanicId ?? '',
        'status': (_selectedMechanicId == null || _selectedMechanicId!.isEmpty) ? 'Unassigned' : 'Assigned',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Job Details', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Car Plate Number'),
                      _buildReadOnlyPill(_plateNumber),
                      const SizedBox(height: 12),

                      _buildLabel('Year'),
                      _buildReadOnlyPill(_year),
                      const SizedBox(height: 12),

                      _buildLabel('VIN Number'),
                      _buildReadOnlyPill(_vin),
                      const SizedBox(height: 12),

                      _buildLabel('Service Type'),
                      _buildReadOnlyPill(_serviceType),
                      const SizedBox(height: 12),

                      _buildLabel('Assign Mechanic'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedMechanicId,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Unassigned', style: TextStyle(fontWeight: FontWeight.normal))),
                              ..._mechanics.map(
                                (m) => DropdownMenuItem<String?>(value: m['mechanicId'], child: Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.normal))),
                              ),
                            ],
                            onChanged: (val) => setState(() => _selectedMechanicId = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Date'),
                                _buildReadOnlyPill(_selectedDateTime == null ? '' : _formattedDate(_selectedDateTime!)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Time'),
                                _buildReadOnlyPill(_selectedDateTime == null ? '' : _formattedTime(_selectedDateTime!)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: SizedBox(
                          width: 180,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFA726),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            ),
                            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  // Longer pill-style read-only field
  Widget _buildReadOnlyPill(String value) {
    return Container(
      height: 48,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
    );
  }

  String _formattedDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month-1]} ${d.day}, ${d.year}';
  }

  String _formattedTime(DateTime d) {
    int h = d.hour;
    final am = h < 12;
    if (h == 0) h = 12; else if (h > 12) h -= 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm ${am ? 'AM' : 'PM'}';
  }
}
