import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart';
import '../../controller/service_invoice_controller.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;

  const ServiceHistoryScreen({super.key, required this.vehicleId});

  @override
  _ServiceHistoryScreenState createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  // Filter and sort state variables
  String _sortBy = 'date'; // date, cost, serviceType
  bool _sortDescending = true;
  String _filterServiceType = 'All';
  double _minCost = 0;
  double _maxCost = 1000000; // Increased to 1 million to accommodate expensive services
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _availableServiceTypes = ['All'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Service History",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Filter and Sort Controls
          _buildFilterSortControls(),
          // Service History List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ServiceRecord')
            .where('vehicleId', isEqualTo: widget.vehicleId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No service history found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final filteredAndSortedDocs = _filterAndSortDocuments(snapshot.data!.docs);
          return _buildServiceHistoryList(filteredAndSortedDocs);
        },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Customers tab should be selected for service history
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color.fromARGB(255, 178, 72, 249),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // Handle navigation based on index
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeNavigator()),
                (route) => false,
              );
              break;
            case 1:
              // Navigate to customers section
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeNavigator()),
                (route) => false,
              );
              break;
            case 2:
            case 3:
            case 4:
              // Show under development message for other tabs
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🚧 This screen is under development.')),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Jobs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSortControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Sort Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSortDialog,
                  icon: Icon(Icons.sort),
                  label: Text('Sort: ${_getSortLabel()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 178, 72, 249),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Filter Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: Icon(Icons.filter_list),
                  label: Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_hasActiveFilters()) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Active filters: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Expanded(
                  child: Text(
                    _getActiveFiltersText(),
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceHistoryList(List<QueryDocumentSnapshot> documents) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No service records match your filters',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filter settings',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final data = doc.data() as Map<String, dynamic>;
        
        // Parse date from Firestore (handle both Timestamp and String)
        DateTime date;
        if (data['date'] is Timestamp) {
          final Timestamp timestamp = data['date'] as Timestamp;
          date = timestamp.toDate();
        } else if (data['date'] is String) {
          // Handle ISO string format like "2024-01-15T00:00:00.000"
          date = DateTime.parse(data['date'] as String);
        } else {
          // Fallback to current date if format is unexpected
          date = DateTime.now();
        }
        
        final String serviceType = data['serviceType'] ?? 'Service';
        final int kilometers = (data['kilometers'] ?? 0).toInt();
        final double cost = (data['cost'] ?? 0.0).toDouble();
        final String description = data['description'] ?? '';
        final String formattedDate = '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year}';

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final currentContext = context;
                      try {
                        // Show loading indicator
                        showDialog(
                          context: currentContext,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        );

                        // Generate service invoice PDF
                        await ServiceInvoiceController.generateServiceInvoice(data, widget.vehicleId);
                        
                        // Close loading indicator
                        if (mounted) Navigator.of(currentContext).pop();
                      } catch (e) {
                        // Close loading indicator
                        if (mounted) Navigator.of(currentContext).pop();
                        
                        // Show error message
                        if (mounted) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: Text('Error generating invoice: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildInfoRow('Service Type', serviceType),
              _buildInfoRow('Kilometers', '${kilometers.toString()} km'),
              _buildInfoRow('Cost', 'RM ${cost.toStringAsFixed(2)}'),
              if (description.isNotEmpty)
                _buildInfoRow('Description', description),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // Helper methods for filter and sort functionality
  String _getSortLabel() {
    String label = '';
    switch (_sortBy) {
      case 'date':
        label = 'Date';
        break;
      case 'cost':
        label = 'Cost';
        break;
      case 'serviceType':
        label = 'Service Type';
        break;
    }
    return '$label ${_sortDescending ? '↓' : '↑'}';
  }

  bool _hasActiveFilters() {
    return _filterServiceType != 'All' ||
           _startDate != null ||
           _endDate != null ||
           _minCost > 0 ||
           _maxCost < 1000000;
  }

  String _getActiveFiltersText() {
    List<String> filters = [];
    if (_filterServiceType != 'All') filters.add('Type: $_filterServiceType');
    if (_startDate != null || _endDate != null) filters.add('Date range');
    if (_minCost > 0 || _maxCost < 1000000) filters.add('Cost: RM $_minCost - RM $_maxCost');
    return filters.join(', ');
  }

  void _clearFilters() {
    setState(() {
      _filterServiceType = 'All';
      _minCost = 0;
      _maxCost = 1000000;
      _startDate = null;
      _endDate = null;
    });
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Sort by'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text('Date'),
                    value: 'date',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Cost'),
                    value: 'cost',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Service Type'),
                    value: 'serviceType',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Order: '),
                      Switch(
                        value: _sortDescending,
                        onChanged: (value) {
                          setDialogState(() {
                            _sortDescending = value;
                          });
                          setState(() {
                            _sortDescending = value;
                          });
                        },
                      ),
                      Text(_sortDescending ? 'Descending' : 'Ascending'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Filter Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Type Filter
                    Text('Service Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _filterServiceType,
                      isExpanded: true,
                      items: _availableServiceTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _filterServiceType = newValue!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Cost Range Filter
                    Text('Cost Range:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RangeSlider(
                      values: RangeValues(_minCost, _maxCost),
                      min: 0,
                      max: 1000000,
                      divisions: 20,
                      labels: RangeLabels('RM ${_minCost.round()}', 'RM ${_maxCost.round()}'),
                      onChanged: (RangeValues values) {
                        setDialogState(() {
                          _minCost = values.start;
                          _maxCost = values.end;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Date Range Filter
                    Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  _startDate = date;
                                });
                              }
                            },
                            child: Text(_startDate != null 
                              ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                              : 'Start Date'),
                          ),
                        ),
                        Text(' - '),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: _startDate ?? DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  _endDate = date;
                                });
                              }
                            },
                            child: Text(_endDate != null 
                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                              : 'End Date'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearFilters();
                    Navigator.pop(context);
                  },
                  child: Text('Clear All'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Apply filters
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterAndSortDocuments(List<QueryDocumentSnapshot> documents) {
    // Extract unique service types for filter options
    Set<String> serviceTypes = {'All'};
    for (var doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final serviceType = data['serviceType'] ?? 'Service';
      serviceTypes.add(serviceType);
    }
    _availableServiceTypes = serviceTypes.toList();

    // Apply filters
    List<QueryDocumentSnapshot> filteredDocs = documents.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Service type filter
      if (_filterServiceType != 'All') {
        final serviceType = data['serviceType'] ?? 'Service';
        if (serviceType != _filterServiceType) {
          return false;
        }
      }
      
      // Cost filter
      final cost = (data['cost'] ?? 0.0).toDouble();
      if (cost < _minCost || cost > _maxCost) {
        return false;
      }
      
      // Date filter
      if (_startDate != null || _endDate != null) {
        DateTime date;
        if (data['date'] is Timestamp) {
          final Timestamp timestamp = data['date'] as Timestamp;
          date = timestamp.toDate();
        } else if (data['date'] is String) {
          date = DateTime.parse(data['date'] as String);
        } else {
          date = DateTime.now();
        }
        
        if (_startDate != null && date.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && date.isAfter(_endDate!.add(Duration(days: 1)))) {
          return false;
        }
      }
      
      return true;
    }).toList();

    // Apply sorting
    filteredDocs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      
      int comparison = 0;
      
      switch (_sortBy) {
        case 'date':
          DateTime dateA, dateB;
          if (dataA['date'] is Timestamp) {
            dateA = (dataA['date'] as Timestamp).toDate();
          } else if (dataA['date'] is String) {
            dateA = DateTime.parse(dataA['date'] as String);
          } else {
            dateA = DateTime.now();
          }
          
          if (dataB['date'] is Timestamp) {
            dateB = (dataB['date'] as Timestamp).toDate();
          } else if (dataB['date'] is String) {
            dateB = DateTime.parse(dataB['date'] as String);
          } else {
            dateB = DateTime.now();
          }
          
          comparison = dateA.compareTo(dateB);
          break;
          
        case 'cost':
          final costA = (dataA['cost'] ?? 0.0).toDouble();
          final costB = (dataB['cost'] ?? 0.0).toDouble();
          comparison = costA.compareTo(costB);
          break;
          
        case 'serviceType':
          final typeA = dataA['serviceType'] ?? 'Service';
          final typeB = dataB['serviceType'] ?? 'Service';
          comparison = typeA.compareTo(typeB);
          break;
      }
      
      return _sortDescending ? -comparison : comparison;
    });

    return filteredDocs;
  }
}