import 'package:flutter/material.dart';
import 'package:mobile_application/model/job.dart';
import 'package:mobile_application/model/vehicle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  Map<String, dynamic>? jobData;
  Vehicle? vehicleData;
  Map<String, dynamic>? customerData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  Future<void> _loadJobDetails() async {
    try {
      // Load job data
      final jobDoc = await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(widget.job.id)
          .get();
      
      if (jobDoc.exists) {
        final jobDataMap = jobDoc.data()!;
        final vehicleId = jobDataMap['vehicleId'] as String?;
        
        // Load vehicle data if vehicleId exists
        Vehicle? vehicle;
        Map<String, dynamic>? customer;
        
        if (vehicleId != null && vehicleId.isNotEmpty) {
          try {
            final vehicleDoc = await FirebaseFirestore.instance
                .collection('Vehicle')
                .doc(vehicleId)
                .get();
            
            if (vehicleDoc.exists) {
              vehicle = Vehicle.fromMap(vehicleDoc.data()!, vehicleDoc.id);
              
              // Load customer data using customerId from vehicle
              final customerId = vehicle.customerId;
              if (customerId.isNotEmpty) {
                try {
                  final customerDoc = await FirebaseFirestore.instance
                      .collection('Customer')
                      .doc(customerId)
                      .get();
                  
                  if (customerDoc.exists) {
                    customer = customerDoc.data();
                  }
                } catch (e) {
                  print('Error loading customer details: $e');
                }
              }
            }
          } catch (e) {
            print('Error loading vehicle details: $e');
          }
        }
        
        setState(() {
          jobData = jobDataMap;
          vehicleData = vehicle;
          customerData = customer;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading job details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }


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

  Widget _buildCarImage() {
    // For Toyota Camry, we'll show a car silhouette with the appropriate color
    return Container(
      width: double.infinity,
      height: 200,
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getCarColor(vehicleData?.fullCarModel ?? widget.job.carModel),
                _getCarColor(vehicleData?.fullCarModel ?? widget.job.carModel).withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.directions_car,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Job Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.black87),
                    onPressed: () {
                      // Edit job functionality
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Car model title
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        vehicleData?.fullCarModel ?? widget.job.carModel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Car image
                    _buildCarImage(),

                    // Vehicle Info
                    _buildInfoSection(
                      'Vehicle Info',
                      [
                        _buildInfoRow('Car Plate Number', vehicleData?.carPlateNumber ?? widget.job.plateNumber),
                        _buildInfoRow('Year', vehicleData?.year.toString() ?? '2021'),
                        _buildInfoRow('VIN', vehicleData?.vin ?? '1234XYZ987'),
                      ],
                    ),

                    // Customer Info
                    _buildInfoSection(
                      'Customer Info',
                      [
                        _buildInfoRow('Name', customerData?['cusName'] ?? 'Unknown Customer'),
                        _buildInfoRow('Contact', customerData?['cusPhone'] ?? 'No Contact'),
                      ],
                    ),

                    // Job Details
                    _buildInfoSection(
                      'Job Details',
                      [
                        _buildInfoRow('Service Type', widget.job.serviceType),
                        _buildInfoRow('Assigned Mechanic', widget.job.mechanic.isEmpty ? 'Unassigned' : widget.job.mechanic),
                        _buildInfoRow('Time', '${widget.job.formattedDate}, ${widget.job.formattedTime}'),
                      ],
                    ),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
