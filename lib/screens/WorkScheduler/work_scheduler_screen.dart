import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_application/model/job.dart';
import 'package:mobile_application/model/vehicle.dart';
import 'job_details_screen.dart';
import 'work_schedule_screen.dart';

// Custom scroll behavior to enable mouse wheel scrolling
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class Mechanic {
  final String id;
  final String name;
  int workload;

  Mechanic({required this.id, required this.name, this.workload = 0});
}

class WorkSchedulerScreen extends StatefulWidget {
  const WorkSchedulerScreen({super.key});

  @override
  State<WorkSchedulerScreen> createState() => _WorkSchedulerScreenState();
}

class _WorkSchedulerScreenState extends State<WorkSchedulerScreen> {
  String selectedFilter = 'Assigned'; // Default to showing assigned jobs
  final TextEditingController _searchController = TextEditingController();
  bool showAssignmentMode = false; // Toggle between view mode and assignment mode
  String _searchQuery = '';

  List<Mechanic> mechanics = [
    Mechanic(id: '1', name: 'Jackson Lee'),
    Mechanic(id: '2', name: 'Dylan Leong'),
    Mechanic(id: '3', name: 'Dixon Yap'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _assignJob(String jobId, String? mechanicName) async {
    try {
      await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(jobId)
          .update({
        'mechanicName': mechanicName ?? '',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job assignment updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job assignment: $e')),
      );
    }
  }

  JobStatus _parseJobStatus(String status) {
    // Handle both lowercase and proper case from Firestore
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

  Future<List<Job>> _filterJobsAsync(List<DocumentSnapshot> docs) async {
    List<Job> jobs = [];
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final statusFromFirestore = data['status'] ?? 'assigned';
      final parsedStatus = _parseJobStatus(statusFromFirestore);
      
      // Enhanced debug logging for time field
      print('=== DEBUG TIME FIELD FOR JOB ${doc.id} ===');
      print('Raw time field from Firestore: ${data['time']}');
      print('Time field type: ${data['time'].runtimeType}');
      
      final firestoreTime = (data['time'] as Timestamp?)?.toDate();
      print('Converted firestoreTime: $firestoreTime');
      
      if (firestoreTime == null) {
        print('⚠️  WARNING: Job ${doc.id} has null time field!');
      }
      
      final actualTime = firestoreTime ?? DateTime(2025, 9, 18, 10, 0);
      final localTime = actualTime.toLocal();
      
      print('Job ${doc.id}: Firestore status = "$statusFromFirestore", Parsed status = $parsedStatus');
      print('Job ${doc.id}: Firestore time = $actualTime, Local time = $localTime');
      
      // Fetch vehicle data using vehicleId
      final vehicleId = data['vehicleId'] ?? '';
      Vehicle? vehicle;
      String carModel = '';
      String plateNumber = '';
      String imageUrl = '';
      
      if (vehicleId.isNotEmpty) {
        try {
          final vehicleDoc = await FirebaseFirestore.instance
              .collection('Vehicle')
              .doc(vehicleId)
              .get();
          
          if (vehicleDoc.exists) {
            vehicle = Vehicle.fromMap(vehicleDoc.data()!, vehicleDoc.id);
            carModel = vehicle.fullCarModel;
            plateNumber = vehicle.carPlateNumber;
            imageUrl = vehicle.imageUrl;
            print('Vehicle data loaded for job ${doc.id}: $carModel ($plateNumber)');
          } else {
            print('⚠️  WARNING: Vehicle $vehicleId not found for job ${doc.id}');
            carModel = 'Unknown Vehicle';
            plateNumber = 'Unknown';
          }
        } catch (e) {
          print('❌ ERROR: Failed to load vehicle $vehicleId for job ${doc.id}: $e');
          carModel = 'Error Loading Vehicle';
          plateNumber = 'Error';
        }
      } else {
        print('⚠️  WARNING: Job ${doc.id} has no vehicleId');
        carModel = 'No Vehicle';
        plateNumber = 'No Plate';
      }
      
      print('=== END DEBUG ===');
      
      jobs.add(Job(
        id: doc.id,
        carModel: carModel,
        plateNumber: plateNumber,
        mechanic: data['mechanicName'] ?? '',
        serviceType: data['serviceType'] ?? '',
        scheduledTime: actualTime,
        imageUrl: imageUrl,
        status: parsedStatus,
      ));
    }

    // Filter by status
    print('Selected filter: $selectedFilter');
    print('Total jobs before filtering: ${jobs.length}');
    
    List<Job> statusFilteredJobs = jobs.where((job) {
      bool shouldInclude = false;
      switch (selectedFilter) {
        case 'Assigned':
          shouldInclude = job.status == JobStatus.assigned;
          break;
        case 'Completed':
          shouldInclude = job.status == JobStatus.completed;
          break;
        default:
          shouldInclude = job.status == JobStatus.assigned;
      }
      
      print('Job ${job.id}: status=${job.status}, filter=$selectedFilter, include=$shouldInclude');
      return shouldInclude;
    }).toList();
    
    print('Jobs after status filtering: ${statusFilteredJobs.length}');
    
    // Then filter by search text
    if (_searchQuery.isEmpty) {
      return statusFilteredJobs;
    }
    
    return statusFilteredJobs.where((job) =>
        job.carModel.toLowerCase().contains(_searchQuery) ||
        job.plateNumber.toLowerCase().contains(_searchQuery) ||
        job.mechanic.toLowerCase().contains(_searchQuery) ||
        job.serviceType.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  void _updateMechanicWorkloads(List<Job> jobs) {
    for (var mechanic in mechanics) {
      mechanic.workload = jobs.where((job) => 
        job.mechanic == mechanic.name && job.status == JobStatus.assigned
      ).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final CollectionReference jobs = FirebaseFirestore.instance.collection('Jobs');

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFFFA726),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.tune, color: Colors.white),
                          onPressed: () {
                            // Show filter options
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkScheduleScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Search bar
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(30),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Filter dropdown
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        isExpanded: true,
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedFilter = newValue!;
                          });
                        },
                        items: <String>['Assigned', 'Completed']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Job cards list with Firestore StreamBuilder
            Expanded(
              child: MouseRegion(
                child: StreamBuilder<QuerySnapshot>(
                  stream: jobs.snapshots(),
                  builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No jobs found.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return FutureBuilder<List<Job>>(
                    future: _filterJobsAsync(snapshot.data!.docs),
                    builder: (context, jobsSnapshot) {
                      if (jobsSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (jobsSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading jobs: ${jobsSnapshot.error}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[600],
                            ),
                          ),
                        );
                      }

                      final filteredJobs = jobsSnapshot.data ?? [];
                      
                      // Update mechanic workloads with current jobs
                      if (showAssignmentMode) {
                        _updateMechanicWorkloads(filteredJobs);
                      }

                      return ScrollConfiguration(
                        behavior: CustomScrollBehavior(),
                        child: Scrollbar(
                          child: CustomScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            slivers: [
                          // Mechanic workloads (show when in assignment mode)
                          if (showAssignmentMode)
                            SliverToBoxAdapter(
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mechanic Workloads',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[700],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: mechanics.map((m) => Chip(
                                        label: Text('${m.name}: ${m.workload} jobs'),
                                        backgroundColor: Colors.teal[50],
                                        labelStyle: TextStyle(color: Colors.teal[700]),
                                      )).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Jobs list
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final job = filteredJobs[index];
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16) +
                                      EdgeInsets.only(
                                        bottom: index == filteredJobs.length - 1 ? 24 : 12,
                                      ),
                                  child: JobCard(
                                    job: job,
                                    showAssignmentMode: showAssignmentMode,
                                    mechanics: mechanics,
                                    onAssignJob: _assignJob,
                                  ),
                                );
                              },
                              childCount: filteredJobs.length,
                            ),
                          ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final Job job;
  final bool showAssignmentMode;
  final List<Mechanic> mechanics;
  final Function(String, String?) onAssignJob;

  const JobCard({
    super.key,
    required this.job,
    required this.showAssignmentMode,
    required this.mechanics,
    required this.onAssignJob,
  });

  Color _getCarColor(String carModel) {
    switch (carModel.toLowerCase()) {
      case 'toyota camry':
        return Colors.red[600]!;
      case 'honda civic':
        return Colors.grey[700]!;
      case 'honda accord':
        return Colors.blue[700]!;
      case 'proton x70':
        return Colors.black87;
      case 'perodua myvi':
        return Colors.blue[600]!;
      default:
        return Colors.blue[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        print('JobCard tapped for job: ${job.id}');
        // Show immediate feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening job details for ${job.carModel}...'),
            duration: Duration(milliseconds: 500),
          ),
        );
        
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailsScreen(job: job),
            ),
          );
        } catch (e) {
          print('Navigation error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening job details: $e')),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Car image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _getCarColor(job.carModel),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: _getCarColor(job.carModel),
                    child: Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Job details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.carModel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Car Plate Number: ${job.plateNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Mechanic: ${job.mechanic.isEmpty ? 'Unassigned' : job.mechanic}',
                      style: TextStyle(
                        fontSize: 12,
                        color: job.mechanic.isEmpty ? Colors.red[600] : Colors.grey[600],
                        fontWeight: job.mechanic.isEmpty ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      'Service Type: ${job.serviceType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Time: ${job.formattedDate}, ${job.formattedTime}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action buttons or assignment dropdown
              if (showAssignmentMode && job.status == JobStatus.assigned)
                // Assignment dropdown - prevent tap propagation
                GestureDetector(
                  onTap: () {}, // Consume tap to prevent navigation
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: job.mechanic.isEmpty ? null : job.mechanic,
                        hint: Text('Assign', style: TextStyle(fontSize: 12)),
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Unassigned')),
                          ...mechanics.map((m) => DropdownMenuItem(
                            value: m.name, 
                            child: Text(m.name)
                          )),
                        ],
                        onChanged: (value) => onAssignJob(job.id, value),
                      ),
                    ),
                  ),
                )
              else if (!showAssignmentMode && job.status == JobStatus.assigned)
                // Regular action buttons (edit/delete) - prevent tap propagation
                GestureDetector(
                  onTap: () {}, // Consume tap to prevent navigation
                  child: IconButton(
                    icon: Icon(Icons.edit, color: Colors.grey[600]),
                    onPressed: () {
                      // Edit job
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
