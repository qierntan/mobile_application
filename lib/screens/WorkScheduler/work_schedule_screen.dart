import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/model/job.dart';

class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});

  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  DateTime selectedDate = DateTime.now();
  String? selectedMechanicId; // mechanicId from Mechanics collection
  
  List<Map<String, String>> mechanics = []; // [{mechanicId, name}]

  @override
  void initState() {
    super.initState();
    _loadMechanics();
  }

  Future<void> _loadMechanics() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('Mechanics').get();
      final loaded = snap.docs.map((d) {
        final m = d.data();
        return {
          'mechanicId': (m['mechanicId'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
        };
      }).where((m) => m['mechanicId']!.isNotEmpty && m['name']!.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        mechanics = loaded;
        if (selectedMechanicId == null && mechanics.isNotEmpty) {
          selectedMechanicId = mechanics.first['mechanicId'];
        }
      });
    } catch (_)
    {}
  }
  
  List<String> timeSlots = [
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFFFA726),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  JobStatus _parseJobStatus(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return JobStatus.assigned;
      case 'inprogress':
      case 'in progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.assigned;
    }
  }

  Future<List<Job>> _filterJobsByMechanicAndDateAsync(List<DocumentSnapshot> docs) async {
    List<Job> allJobs = [];
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final statusFromFirestore = data['status'] ?? 'assigned';
      final parsedStatus = _parseJobStatus(statusFromFirestore);
      
      final firestoreTime = (data['time'] as Timestamp?)?.toDate();
      final actualTime = firestoreTime ?? DateTime(2025, 9, 18, 10, 0);
      
      // Fetch vehicle data using vehicleId
      final vehicleId = data['vehicleId'] ?? '';
      String plateNumber = '';
      String carModel = '';
      String imageUrl = '';
      
      if (vehicleId.isNotEmpty) {
        try {
          final vehicleDoc = await FirebaseFirestore.instance
              .collection('Vehicle')
              .doc(vehicleId)
              .get();
          
          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
            plateNumber = vehicleData['carPlateNumber'] ?? '';
            carModel = '${vehicleData['make'] ?? ''} ${vehicleData['model'] ?? ''}'.trim();
            imageUrl = vehicleData['imageUrl'] ?? '';
          }
        } catch (e) {
          print('Error loading vehicle $vehicleId: $e');
        }
      }
      
      allJobs.add(Job(
        id: doc.id,
        carModel: carModel,
        plateNumber: plateNumber,
        mechanic: (data['mechanicId'] ?? '').toString(), // store mechanicId for filtering
        serviceType: data['serviceType'] ?? '',
        scheduledTime: actualTime,
        imageUrl: imageUrl,
        status: parsedStatus,
      ));
    }

    // Filter by selected mechanic and date
    List<Job> filteredJobs = allJobs.where((job) {
      // Filter by selected mechanic (by id)
      bool mechanicMatch = (selectedMechanicId == null)
          ? true
          : job.mechanic == selectedMechanicId;
      
      // Filter by selected date (same day) - convert to local time
      DateTime localTime = job.scheduledTime.toLocal();
      bool dateMatch = localTime.year == selectedDate.year &&
                      localTime.month == selectedDate.month &&
                      localTime.day == selectedDate.day;
      
      return mechanicMatch && dateMatch;
    }).toList();

    return filteredJobs;
  }

  Job? _findJobForTimeSlot(List<Job> jobs, String timeSlot) {
    // Convert timeSlot string to hour for comparison
    int targetHour = _parseTimeSlot(timeSlot);
    
    print('Looking for jobs at hour: $targetHour (from timeSlot: $timeSlot)');
    
    for (Job job in jobs) {
      // Use local time for comparison
      DateTime localTime = job.scheduledTime.toLocal();
      int jobHour = localTime.hour;
      print('Job ${job.serviceType} is at hour: $jobHour (local time: $localTime)');
      if (jobHour == targetHour) {
        print('Match found: ${job.serviceType} at $timeSlot');
        return job;
      }
    }
    print('No job found for timeSlot: $timeSlot');
    return null;
  }

  int _parseTimeSlot(String timeSlot) {
    // Parse time slots like "9:00 AM", "12:00 PM" to 24-hour format
    List<String> parts = timeSlot.split(':');
    int hour = int.parse(parts[0]);
    bool isPM = timeSlot.contains('PM');
    
    if (isPM && hour != 12) {
      hour += 12;
    } else if (!isPM && hour == 12) {
      hour = 0;
    }
    
    print('Parsed timeSlot "$timeSlot" to hour: $hour');
    return hour;
  }

  Widget _buildJobCard(String serviceType, String vehicle, String timeSlot) {
    return Container(
      height: 60,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            serviceType,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Vehicle: $vehicle',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 56, left: 16),
                        child: Text(
                          'Work Schedule',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 56),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.tune, color: Colors.grey[600]),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFFFA726),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.calendar_today, color: Colors.white),
                                onPressed: _selectDate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                    // Date and Date picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(width: 4),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Mechanic chips (horizontally scrollable)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                      children: mechanics.map((mechanic) {
                        final isSelected = mechanic['mechanicId'] == selectedMechanicId;
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedMechanicId = mechanic['mechanicId'];
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFFFFA726) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                mechanic['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Time slots and jobs with Firestore data
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('Jobs').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData) {
                          return Container();
                        }

                        return FutureBuilder<List<Job>>(
                          future: _filterJobsByMechanicAndDateAsync(snapshot.data!.docs),
                          builder: (context, jobsSnapshot) {
                            if (jobsSnapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            if (jobsSnapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading jobs: ${jobsSnapshot.error}',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            List<Job> filteredJobs = jobsSnapshot.data ?? [];

                            return Column(
                              children: timeSlots.map((timeSlot) {
                                // Find job for this time slot
                                Job? job = _findJobForTimeSlot(filteredJobs, timeSlot);
                                
                                return Container(
                                  height: 68,
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Time column
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          timeSlot,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      
                                      // Vertical line separator
                                      Container(
                                        width: 1,
                                        height: 60,
                                        margin: EdgeInsets.symmetric(horizontal: 16),
                                        color: Colors.grey[300],
                                      ),
                                      
                                      // Job column
                                      Expanded(
                                        child: job != null 
                                          ? _buildJobCard(job.serviceType, job.plateNumber, timeSlot)
                                          : Container(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

}
 