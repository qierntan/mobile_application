import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/services/job_conflict_service.dart';

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

      // Handle potential trailing-space typo in Firestore field key
      final Timestamp? ts = (jobData['time'] ?? jobData['time ']) as Timestamp?;
      final DateTime? dt = ts?.toDate();

      // Load available mechanics based on the job time
      List<Map<String, String>> availableMechanics = [];
      if (dt != null) {
        availableMechanics = await _loadAvailableMechanics(dt);
      } else {
        // If no time is set, load all mechanics
        availableMechanics = await _loadAllMechanics();
      }

      setState(() {
        _plateNumber = plate;
        _year = year;
        _vin = vin;
        _serviceType = (jobData['serviceType'] ?? '').toString();
        _mechanics = availableMechanics;
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

  Future<List<Map<String, String>>> _loadAllMechanics() async {
    try {
      final mechSnap = await FirebaseFirestore.instance
          .collection('Mechanics')
          .get();
      return mechSnap.docs.map((d) {
        final m = d.data();
        return {
          'mechanicId': (m['mechanicId'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
        };
      }).where((e) => e['mechanicId']!.isNotEmpty && e['name']!.isNotEmpty).toList();
    } catch (e) {
      print('Error loading all mechanics: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _loadAvailableMechanics(DateTime jobTime) async {
    try {
      print('Loading available mechanics for time: $jobTime');
      
      // Get list of available mechanic IDs
      final availableMechanicIds = await JobConflictService.getAvailableMechanics(
        jobTime: jobTime,
        excludeJobId: widget.jobId, // Exclude current job from conflict check
      );
      
      print('Available mechanic IDs: $availableMechanicIds');
      
      // Get all mechanics and filter by availability
      final mechSnap = await FirebaseFirestore.instance
          .collection('Mechanics')
          .get();
      
      List<Map<String, String>> availableMechanics = [];
      
      for (var doc in mechSnap.docs) {
        final m = doc.data();
        final mechanicId = (m['mechanicId'] ?? '').toString();
        final name = (m['name'] ?? '').toString();
        
        if (mechanicId.isNotEmpty && name.isNotEmpty) {
          // Include mechanic if they're available OR if they're currently assigned to this job
          // Note: We need to check the current job's mechanicId from the database, not _selectedMechanicId
          // which might not be set yet during initial load
          bool isCurrentlyAssigned = false;
          if (widget.jobId.isNotEmpty) {
            try {
              final currentJobDoc = await FirebaseFirestore.instance.collection('Jobs').doc(widget.jobId).get();
              if (currentJobDoc.exists) {
                final currentJobData = currentJobDoc.data() as Map<String, dynamic>;
                final currentJobMechanicId = (currentJobData['mechanicId'] ?? '').toString();
                isCurrentlyAssigned = currentJobMechanicId == mechanicId;
              }
            } catch (e) {
              print('Error checking current job assignment: $e');
            }
          }
          
          if (availableMechanicIds.contains(mechanicId) || isCurrentlyAssigned) {
            availableMechanics.add({
              'mechanicId': mechanicId,
              'name': name,
            });
            print('→ Including mechanic: $name ($mechanicId) - ${isCurrentlyAssigned ? 'currently assigned' : 'available'}');
          } else {
            print('→ Excluding mechanic: $name ($mechanicId) - not available');
          }
        }
      }
      
      print('Final available mechanics count: ${availableMechanics.length}');
      return availableMechanics;
    } catch (e) {
      print('Error loading available mechanics: $e');
      // Fallback to loading all mechanics if there's an error
      return await _loadAllMechanics();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      final DateTime newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime?.hour ?? 9, // Default to 9 AM if no time set
        _selectedDateTime?.minute ?? 0,
      );
      
      await _updateDateTimeAndRefreshMechanics(newDateTime);
    }
  }

  Future<void> _selectTime() async {
    if (_selectedDateTime == null) {
      // If no date is set, set today's date first
      final today = DateTime.now();
      _selectedDateTime = DateTime(today.year, today.month, today.day, 9, 0);
    }
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime!),
    );
    
    if (picked != null) {
      final DateTime newDateTime = DateTime(
        _selectedDateTime!.year,
        _selectedDateTime!.month,
        _selectedDateTime!.day,
        picked.hour,
        picked.minute,
      );
      
      await _updateDateTimeAndRefreshMechanics(newDateTime);
    }
  }

  Future<void> _updateDateTimeAndRefreshMechanics(DateTime newDateTime) async {
    setState(() {
      _selectedDateTime = newDateTime;
    });
    
    // Refresh available mechanics based on new time
    await _refreshAvailableMechanics();
  }

  Future<void> _refreshAvailableMechanics() async {
    if (_selectedDateTime == null) return;
    
    try {
      print('Refreshing available mechanics for new time: $_selectedDateTime');
      
      // Store current selection to check if it's still valid
      final currentMechanicId = _selectedMechanicId;
      
      // Load available mechanics for the new time
      final availableMechanics = await _loadAvailableMechanics(_selectedDateTime!);
      
      setState(() {
        _mechanics = availableMechanics;
        
        // Check if currently selected mechanic is still available
        if (currentMechanicId != null) {
          final isStillAvailable = availableMechanics.any((m) => m['mechanicId'] == currentMechanicId);
          if (!isStillAvailable) {
            // Current mechanic is no longer available, clear selection
            _selectedMechanicId = null;
            print('→ Current mechanic is no longer available, cleared selection');
            
            // Show warning to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Selected mechanic is no longer available at this time. Please choose another mechanic.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      });
      
      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated available mechanics for ${_formattedDate(_selectedDateTime!)} at ${_formattedTime(_selectedDateTime!)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error refreshing available mechanics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating mechanic availability: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    print('=== SUBMIT START ===');
    print('Job ID: ${widget.jobId}');
    print('Selected Mechanic: $_selectedMechanicId');
    print('Selected DateTime: $_selectedDateTime');
    
    // ALWAYS check for time conflicts if a mechanic is assigned
    if (_selectedMechanicId != null && _selectedMechanicId!.isNotEmpty && _selectedDateTime != null) {
      print('Running conflict check...');
      print('CONDITIONS MET: mechanicId=$_selectedMechanicId, dateTime=$_selectedDateTime');
      print('CONDITIONS MET: mechanicId type=${_selectedMechanicId.runtimeType}, dateTime type=${_selectedDateTime.runtimeType}');
      final hasConflict = await JobConflictService.checkTimeConflict(
        currentJobId: widget.jobId,
        mechanicId: _selectedMechanicId!,
        jobTime: _selectedDateTime!,
      );
      print('Conflict check result: $hasConflict');
      
      if (hasConflict) {
        print('CONFLICT DETECTED - Blocking save');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: This mechanic already has a job at this time slot'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      } else {
        print('No conflicts found - Proceeding with save');
      }
    } else {
      print('Skipping conflict check - No mechanic assigned or no time set');
    }
    
    try {
      print('Updating job in database...');
      Map<String, dynamic> updateData = {
        'mechanicId': _selectedMechanicId ?? '',
        'status': (_selectedMechanicId == null || _selectedMechanicId!.isEmpty) ? 'Unassigned' : 'Assigned',
      };
      
      // Update time if it was changed
      if (_selectedDateTime != null) {
        updateData['time'] = Timestamp.fromDate(_selectedDateTime!);
      }
      
      await FirebaseFirestore.instance.collection('Jobs').doc(widget.jobId).update(updateData);
      
      print('Job updated successfully in database');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error updating job: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job: $e')),
      );
    }
    
    print('=== SUBMIT END ===');
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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Assign Mechanic'),
                          if (_selectedDateTime != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_mechanics.length} available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                      if (_selectedDateTime != null && _mechanics.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No mechanics available at this time. Try selecting a different time slot.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
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
                                InkWell(
                                  onTap: _selectDate,
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedDateTime == null ? 'Select Date' : _formattedDate(_selectedDateTime!),
                                            style: TextStyle(
                                              color: _selectedDateTime == null ? Colors.grey[600] : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Time'),
                                InkWell(
                                  onTap: _selectTime,
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedDateTime == null ? 'Select Time' : _formattedTime(_selectedDateTime!),
                                            style: TextStyle(
                                              color: _selectedDateTime == null ? Colors.grey[600] : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                                      ],
                                    ),
                                  ),
                                ),
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
