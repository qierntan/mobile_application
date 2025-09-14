import 'package:flutter/material.dart';
import 'package:mobile_application/model/job.dart';

class AssignedJobsScreen extends StatefulWidget {
  @override
  _AssignedJobsScreenState createState() => _AssignedJobsScreenState();
}

class _AssignedJobsScreenState extends State<AssignedJobsScreen> {
  String selectedFilter = 'Assigned Jobs'; // Default to Assigned Jobs
  final TextEditingController _searchController = TextEditingController();

  // Sample data - in a real app this would come from a database
  final List<Job> jobs = [
    // Assigned Jobs
    Job(
      id: '1',
      carModel: 'Toyota Camry',
      plateNumber: 'WPC 3322',
      mechanic: 'Jackson Lee',
      serviceType: 'Engine Oil Change',
      scheduledTime: DateTime(2024, 8, 10, 10, 0),
      imageUrl: 'assets/toyota_camry.jpg',
      status: JobStatus.assigned,
    ),
    Job(
      id: '3',
      carModel: 'Proton X70',
      plateNumber: 'WAL 1118',
      mechanic: 'Dylan Leong',
      serviceType: 'Air Filter Replacement',
      scheduledTime: DateTime(2024, 8, 11, 11, 0),
      imageUrl: 'assets/proton_x70.jpg',
      status: JobStatus.assigned,
    ),
    // Completed Jobs
    Job(
      id: '2',
      carModel: 'Honda Civic',
      plateNumber: 'WVY 6568',
      mechanic: 'Dixon Yap',
      serviceType: 'Dashcam Installation',
      scheduledTime: DateTime(2024, 8, 10, 14, 0),
      imageUrl: 'assets/honda_civic.jpg',
      status: JobStatus.completed,
    ),
    Job(
      id: '4',
      carModel: 'Perodua Myvi',
      plateNumber: 'VHW 3262',
      mechanic: 'Jackson Lee',
      serviceType: 'Brake Pad Replacement',
      scheduledTime: DateTime(2024, 8, 8, 10, 0),
      imageUrl: 'assets/perodua_myvi.jpg',
      status: JobStatus.completed,
    ),
  ];

  List<Job> get filteredJobs {
    List<Job> statusFilteredJobs = jobs;
    
    // Filter by status first
    statusFilteredJobs = jobs.where((job) {
      switch (selectedFilter) {
        case 'Assigned Jobs':
          return job.status == JobStatus.assigned;
        case 'Completed Jobs':
          return job.status == JobStatus.completed;
        default:
          return job.status == JobStatus.assigned; // Default to assigned
      }
    }).toList();
    
    // Then filter by search text
    if (_searchController.text.isEmpty) {
      return statusFilteredJobs;
    }
    
    return statusFilteredJobs.where((job) =>
        job.carModel.toLowerCase().contains(_searchController.text.toLowerCase()) ||
        job.plateNumber.toLowerCase().contains(_searchController.text.toLowerCase()) ||
        job.mechanic.toLowerCase().contains(_searchController.text.toLowerCase()) ||
        job.serviceType.toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();
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
                  Text(
                    selectedFilter,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Search bar and filter row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      
                      // Filter button
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
                      
                      // Calendar button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                          onPressed: () {
                            // Show calendar
                          },
                        ),
                      ),
                    ],
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
                        items: <String>['Assigned Jobs', 'Completed Jobs']
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
            
            // Job cards list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredJobs.length,
                itemBuilder: (context, index) {
                  final job = filteredJobs[index];
                  return JobCard(job: job);
                },
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

  const JobCard({Key? key, required this.job}) : super(key: key);

  Color _getCarColor(String carModel) {
    switch (carModel.toLowerCase()) {
      case 'toyota camry':
        return Colors.red[600]!;
      case 'honda civic':
        return Colors.grey[700]!;
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
    return Container(
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
                    'Mechanic: ${job.mechanic}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
            
            // Action buttons (only show for assigned jobs)
            if (job.status == JobStatus.assigned)
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.grey[600]),
                    onPressed: () {
                      // Edit job
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(height: 8),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[400]),
                    onPressed: () {
                      // Delete job
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
