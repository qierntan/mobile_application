import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});
  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  String filter = 'Monthly';
  int tabIndex = 0;
  bool _isLoading = true;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  List<Map<String, dynamic>> monthlyData = [];
  List<Map<String, dynamic>> dailyData = [];
  List<Map<String, dynamic>> topCustomers = [];
  List<Map<String, dynamic>> paymentTrends = [];

  // Monthly filter data
  List<Map<String, dynamic>> monthlyTopCustomers = [];
  List<Map<String, dynamic>> monthlyPaymentTrends = [];

  // Specific month filter data
  List<Map<String, dynamic>> specificMonthTopCustomers = [];
  List<Map<String, dynamic>> specificMonthPaymentTrends = [];

  @override
  void initState() {
    super.initState();
    // Ensure proper initialization
    if (selectedMonth < 1 || selectedMonth > 12) {
      selectedMonth = DateTime.now().month;
    }
    if (selectedYear < 2020 || selectedYear > 2030) {
      selectedYear = DateTime.now().year;
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Get all paid invoices
      final QuerySnapshot invoices =
          await FirebaseFirestore.instance
              .collection('Invoice')
              .where('status', isEqualTo: 'Paid')
              .get();

      await _processInvoiceData(invoices);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching report data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDailyData() async {
    setState(() => _isLoading = true);

    try {
      print(
        'DEBUG: Fetching data for month: $selectedMonth, year: $selectedYear',
      );

      // Validate month before using it
      if (selectedMonth < 1 || selectedMonth > 12) {
        selectedMonth = DateTime.now().month;
        print('DEBUG: Invalid month detected, reset to: $selectedMonth');
      }

      // Get invoices for selected month and year
      final startDate = DateTime(selectedYear, selectedMonth, 1);
      final endDate = DateTime(selectedYear, selectedMonth + 1, 0);

      print('DEBUG: Date range: $startDate to $endDate');
      print('DEBUG: Days in month: ${endDate.day}');

      // Get all paid invoices first, then filter by date
      final QuerySnapshot invoices =
          await FirebaseFirestore.instance
              .collection('Invoice')
              .where('status', isEqualTo: 'Paid')
              .get();

      print('DEBUG: Found ${invoices.docs.length} paid invoices total');

      // Filter invoices for the selected month manually
      final filteredInvoices =
          invoices.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // Use paymentDate for paid invoices, fallback to date field
            final dateToUse = data['paymentDate'] ?? data['date'];
            if (dateToUse != null) {
              final rawDateTime = (dateToUse as Timestamp).toDate();
              // Add 8 hours to match UTC+8 timezone as shown in database
              final date = rawDateTime.add(Duration(hours: 8));
              final isInMonth =
                  date.year == selectedYear && date.month == selectedMonth;

              if (isInMonth) {
                print(
                  'DEBUG: Found invoice ${doc.id} with date: $date (using ${data['paymentDate'] != null ? 'paymentDate' : 'date'})',
                );
              }

              return isInMonth;
            }

            return false;
          }).toList();

      print('DEBUG: Filtered invoices for month: ${filteredInvoices.length}');

      await _processDailyDataFromDocs(
        filteredInvoices,
        endDate.day,
        selectedYear == DateTime.now().year &&
            selectedMonth == DateTime.now().month,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching daily data: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processInvoiceData(QuerySnapshot invoices) async {
    // Process monthly data only
    Map<int, Map<String, double>> monthTotals = {};
    Map<String, double> customerTotals = {};
    Map<String, int> paymentMethodCounts = {};
    Map<String, double> paymentMethodAmounts = {};

    for (var doc in invoices.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Try multiple field names to find the amount
      final amount = (data['total'] ?? data['totalAmount'] ?? 0) as num;
      final amountDouble = amount.toDouble();
      // Use paymentDate for paid invoices, fallback to date field
      final dateToUse = data['paymentDate'] ?? data['date'];
      final rawDateTime = (dateToUse as Timestamp).toDate();
      // Add 8 hours to match UTC+8 timezone as shown in database
      final date = rawDateTime.add(Duration(hours: 8));
      final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';
      final customerName = data['customerName'] as String? ?? 'Unknown';

      // Monthly totals for current year
      if (date.year == DateTime.now().year) {
        final month = date.month;
        monthTotals[month] = monthTotals[month] ?? {};
        monthTotals[month]!['sales'] =
            (monthTotals[month]!['sales'] ?? 0) + amountDouble;
      }

      // Customer totals
      customerTotals[customerName] =
          (customerTotals[customerName] ?? 0) + amountDouble;

      // Payment method counts
      paymentMethodCounts[paymentMethod] =
          (paymentMethodCounts[paymentMethod] ?? 0) + 1;

      // Payment method amounts
      paymentMethodAmounts[paymentMethod] =
          (paymentMethodAmounts[paymentMethod] ?? 0) + amountDouble;
    }

    // Convert monthly data
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    monthlyData = List.generate(12, (index) {
      return {
        'month': months[index],
        'sales': monthTotals[index + 1]?['sales'] ?? 0.0,
      };
    });

    // Convert customer totals to list and sort
    monthlyTopCustomers =
        customerTotals.entries
            .map(
              (e) => {
                'name': e.key,
                'amount': e.value,
                'attitude': _getCustomerAttitude(e.value),
              },
            )
            .toList()
          ..sort(
            (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
          );

    // Convert payment trends and sort in descending order by count (number of payments)
    monthlyPaymentTrends =
        paymentMethodCounts.entries
            .map(
              (e) => {
                'method': e.key,
                'count': e.value,
                'amount': paymentMethodAmounts[e.key] ?? 0.0,
              },
            )
            .toList()
          ..sort((a, b) {
            // First sort by count in descending order
            int countCompare = (b['count'] as int).compareTo(a['count'] as int);
            if (countCompare != 0) return countCompare;
            // If counts are equal, sort by amount in descending order
            return (b['amount'] as double).compareTo(a['amount'] as double);
          });

    // Set default top customers and payment trends to monthly data
    topCustomers = monthlyTopCustomers;
    paymentTrends = monthlyPaymentTrends;
  }

  Future<void> _processDailyDataFromDocs(
    List<QueryDocumentSnapshot> docs,
    int daysInMonth,
    bool isCurrentMonth,
  ) async {
    print(
      'DEBUG: Processing daily data for $daysInMonth days from ${docs.length} documents',
    );

    Map<int, double> dayTotals = {};
    Map<String, double> customerTotals = {};
    Map<String, int> paymentMethodCounts = {};
    Map<String, double> paymentMethodAmounts = {};

    for (var doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        print('DEBUG: Processing document: ${doc.id}');
        print('DEBUG: Document fields: ${data.keys.toList()}');

        // Use the correct field mapping: prioritize 'total' over 'totalAmount'
        final amount = (data['total'] ?? data['totalAmount'] ?? 0) as num;
        final amountDouble = amount.toDouble();

        // Use paymentDate for paid invoices, fallback to date field
        final dateToUse = data['paymentDate'] ?? data['date'];
        // Get the raw timestamp and manually handle timezone to match database display
        final rawDateTime = (dateToUse as Timestamp).toDate();
        // Add 8 hours to match UTC+8 timezone as shown in database
        final transactionDate = rawDateTime.add(Duration(hours: 8));
        print(
          'DEBUG: Using field: ${data['paymentDate'] != null ? 'paymentDate' : 'date'}',
        );
        print('DEBUG: Raw timestamp: $rawDateTime');
        print('DEBUG: Adjusted for UTC+8: $transactionDate');

        final day = transactionDate.day;
        final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';
        final customerName = data['customerName'] as String? ?? 'Unknown';

        print(
          'DEBUG: Amount: $amountDouble, Day: $day, Customer: $customerName, PaymentMethod: $paymentMethod',
        );

        // Add to day totals
        dayTotals[day] = (dayTotals[day] ?? 0) + amountDouble;

        // Customer totals for specific month
        customerTotals[customerName] =
            (customerTotals[customerName] ?? 0) + amountDouble;

        // Payment method counts for specific month
        paymentMethodCounts[paymentMethod] =
            (paymentMethodCounts[paymentMethod] ?? 0) + 1;

        // Payment method amounts for specific month
        paymentMethodAmounts[paymentMethod] =
            (paymentMethodAmounts[paymentMethod] ?? 0) + amountDouble;
      } catch (e) {
        print('ERROR processing document ${doc.id}: $e');
      }
    }

    print('DEBUG: Day totals: $dayTotals');

    // Create daily data for all days in the month - with safety checks
    try {
      if (daysInMonth <= 0 || daysInMonth > 31) {
        print('ERROR: Invalid daysInMonth: $daysInMonth');
        daysInMonth = DateTime.now().day; // Fallback
      }

      dailyData = List.generate(daysInMonth, (index) {
        final day = index + 1;
        final sales = dayTotals[day] ?? 0.0;
        return {'day': day, 'sales': sales};
      });

      print('DEBUG: Generated daily data length: ${dailyData.length}');
      print('DEBUG: Daily data: $dailyData');
    } catch (e) {
      print('ERROR generating daily data: $e');
      dailyData = []; // Fallback to empty list
    }

    // Convert customer totals to list and sort for specific month
    try {
      specificMonthTopCustomers =
          customerTotals.entries
              .map(
                (e) => {
                  'name': e.key,
                  'amount': e.value,
                  'attitude': _getCustomerAttitude(e.value),
                },
              )
              .toList()
            ..sort(
              (a, b) =>
                  (b['amount'] as double).compareTo(a['amount'] as double),
            );
    } catch (e) {
      print('ERROR processing customers: $e');
      specificMonthTopCustomers = [];
    }

    // Convert payment trends for specific month and sort in descending order by count
    try {
      specificMonthPaymentTrends =
          paymentMethodCounts.entries
              .map(
                (e) => {
                  'method': e.key,
                  'count': e.value,
                  'amount': paymentMethodAmounts[e.key] ?? 0.0,
                },
              )
              .toList()
            ..sort((a, b) {
              // First sort by count in descending order
              int countCompare = (b['count'] as int).compareTo(
                a['count'] as int,
              );
              if (countCompare != 0) return countCompare;
              // If counts are equal, sort by amount in descending order
              return (b['amount'] as double).compareTo(a['amount'] as double);
            });
    } catch (e) {
      print('ERROR processing payment trends: $e');
      specificMonthPaymentTrends = [];
    }

    // Update current display data
    topCustomers = specificMonthTopCustomers;
    paymentTrends = specificMonthPaymentTrends;

    print(
      'DEBUG: Processing complete. Top customers: ${topCustomers.length}, Payment trends: ${paymentTrends.length}',
    );
  }

  Widget _buildDailyBarChart(
    double totalSales,
    List<Map<String, dynamic>> dailyData,
  ) {
    // Filter out days with zero sales
    final nonZeroDays =
        dailyData.where((d) => (d['sales'] as double) > 0).toList();

    // Define a consistent color palette for days
    final List<Color> dayColors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
      Color(0xFFFFC107),
      Color(0xFF795548),
      Color(0xFF607D8B),
      Color(0xFFFF5722),
      Color(0xFF3F51B5),
      Color(0xFF009688),
      Color(0xFFCDDC39),
      Color(0xFFFF7043),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFFB74D),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFF26C6DA),
      Color(0xFFFFCA28),
      Color(0xFF8D6E63),
      Color(0xFF78909C),
      Color(0xFFFF8A65),
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFD4E157),
      Color(0xFFFFCC02),
      Color(0xFF29B6F6),
      Color(0xFF7CB342),
      Color(0xFFFFB300),
    ];

    // Create pie chart data
    final pieData =
        nonZeroDays.map((d) {
          final value = d['sales'] as double;
          final day = d['day'] as int;
          final isMax =
              value ==
              nonZeroDays
                  .map((d) => d['sales'] as double)
                  .reduce((a, b) => a > b ? a : b);

          // Use day number for consistent coloring (day 1-31)
          final color =
              isMax
                  ? Color(0xFFFFC700)
                  : dayColors[(day - 1) % dayColors.length];

          return PieChartSectionData(
            value: value,
            color: color,
            title: 'Day $day',
            radius: isMax ? 50 : 40,
            titleStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white,
            ),
          );
        }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Revenue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22211F),
                  ),
                ),
                _buildMonthSelector(),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'RM ${totalSales.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22211F),
              ),
            ),
            SizedBox(height: 20),
            if (nonZeroDays.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: pieData,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ...nonZeroDays.map((d) {
                final value = d['sales'] as double;
                final day = d['day'] as int;
                final percent =
                    totalSales > 0
                        ? (value / totalSales * 100).toStringAsFixed(1)
                        : '0';
                final index = nonZeroDays.indexOf(d);
                final color = pieData[index].color;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text('Day $day')),
                      Text(
                        'RM ${value.toStringAsFixed(2)} ($percent%)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            ] else
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No data available for this month',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Ensure selectedMonth is within valid range
    if (selectedMonth < 1 || selectedMonth > 12) {
      selectedMonth = DateTime.now().month;
    }

    return DropdownButton<int>(
      value: selectedMonth,
      onChanged: (value) {
        if (value != null && value >= 1 && value <= 12) {
          setState(() {
            selectedMonth = value;
            _fetchDailyData();
          });
        }
      },
      items: List.generate(12, (index) {
        return DropdownMenuItem<int>(
          value: index + 1,
          child: Text(months[index]),
        );
      }),
      underline: Container(),
      style: TextStyle(color: Color(0xFF22211F)),
    );
  }

  String _getCustomerAttitude(double amount) {
    if (amount > 2000) return 'Excellent';
    if (amount > 1000) return 'Very Good';
    if (amount > 500) return 'Good';
    return 'Regular';
  }

  Widget _buildSalesCard(
    double totalSales,
    List<Map<String, dynamic>> detailsData,
    Map<String, dynamic>? maxItem,
  ) {
    if (filter == 'Specific Month') {
      return _buildDailyBarChart(totalSales, detailsData);
    }

    // Filter out zero sales data
    final nonZeroData =
        detailsData.where((d) => (d['sales'] as double) > 0).toList();

    // Define consistent colors for each month
    final List<Color> monthColors = [
      Color(0xFF2196F3), // Jan - Blue
      Color(0xFF4CAF50), // Feb - Green
      Color(0xFFFF9800), // Mar - Orange
      Color(0xFFE91E63), // Apr - Pink
      Color(0xFF9C27B0), // May - Purple
      Color(0xFF00BCD4), // Jun - Cyan
      Color(0xFFFFC107), // Jul - Amber
      Color(0xFF795548), // Aug - Brown
      Color(0xFF607D8B), // Sep - Blue Grey
      Color(0xFFFF5722), // Oct - Deep Orange
      Color(0xFF3F51B5), // Nov - Indigo
      Color(0xFF009688), // Dec - Teal
    ];

    final pieData =
        nonZeroData.map((d) {
          final value = d['sales'] as double;
          final monthName = d['month'] as String;
          final isMax = maxItem != null && d == maxItem;

          // Get month index from month name for consistent coloring
          final monthNames = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          final monthIndex = monthNames.indexOf(monthName);
          final color =
              isMax
                  ? Color(0xFFFFC700)
                  : (monthIndex >= 0 ? monthColors[monthIndex] : Colors.grey);

          return PieChartSectionData(
            value: value,
            color: color,
            title: monthName,
            radius: isMax ? 50 : 40,
            titleStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white,
            ),
          );
        }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total Revenue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22211F),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'RM ${totalSales.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22211F),
              ),
            ),
            SizedBox(height: 20),
            if (detailsData.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: pieData,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ...nonZeroData.map((d) {
                final value = d['sales'] as double;
                final percent =
                    totalSales > 0
                        ? (value / totalSales * 100).toStringAsFixed(1)
                        : '0';
                final index = nonZeroData.indexOf(d);
                final color = pieData[index].color;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text('${d['month']}')),
                      Text(
                        'RM ${value.toStringAsFixed(2)} ($percent%)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            ] else
              Text('No data available for this period'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final now = DateTime.now();
    final isCurrentMonth =
        selectedYear == now.year && selectedMonth == now.month;
    final monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthLabel =
        filter == 'Specific Month'
            ? '${monthNames[selectedMonth]} ${isCurrentMonth ? '(Current)' : selectedYear}'
            : 'Monthly';

    return Column(
      children: [
        Text(
          '$monthLabel Analytics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF22211F),
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: Text('Top Customers'),
              selected: tabIndex == 0,
              onSelected: (_) => setState(() => tabIndex = 0),
              selectedColor: Color(0xFFFFC700),
              labelStyle: TextStyle(
                color: tabIndex == 0 ? Colors.white : Color(0xFF22211F),
              ),
            ),
            SizedBox(width: 12),
            ChoiceChip(
              label: Text('Payment Methods'),
              selected: tabIndex == 1,
              onSelected: (_) => setState(() => tabIndex = 1),
              selectedColor: Color(0xFFFFC700),
              labelStyle: TextStyle(
                color: tabIndex == 1 ? Colors.white : Color(0xFF22211F),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    if (tabIndex == 0) {
      return Column(
        children:
            topCustomers.take(5).map((customer) {
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFFFC700),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    customer['name'] as String,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Attitude: ${customer['attitude']}'),
                  trailing: Text(
                    'RM ${(customer['amount'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22211F),
                    ),
                  ),
                ),
              );
            }).toList(),
      );
    } else {
      return Column(
        children:
            paymentTrends.map((method) {
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFFFC700),
                    child: Icon(Icons.payment, color: Colors.white),
                  ),
                  title: Text(
                    method['method'] as String,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${method['count']} payments',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM ${(method['amount'] as double).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22211F),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report'),
        backgroundColor: Color(0xFFF6F2EA),
        foregroundColor: Color(0xFF22211F),
        actions: [
          DropdownButton<String>(
            value: filter,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  filter = value;
                  if (value == 'Specific Month') {
                    _fetchDailyData();
                  } else {
                    // Switch back to monthly data
                    topCustomers = monthlyTopCustomers;
                    paymentTrends = monthlyPaymentTrends;
                  }
                });
              }
            },
            items:
                ['Monthly', 'Specific Month'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
            underline: Container(),
            style: TextStyle(color: Color(0xFF22211F)),
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
      backgroundColor: Color(0xFFF6F2EA),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final currentMonthIndex = now.month;
                  final filteredMonthlyData = monthlyData.sublist(
                    0,
                    currentMonthIndex,
                  );

                  double totalSales;
                  List<Map<String, dynamic>> detailsData;
                  Map<String, dynamic>? maxItem;

                  if (filter == 'Specific Month') {
                    totalSales = dailyData.fold(
                      0.0,
                      (sum, d) => sum + (d['sales'] as double),
                    );
                    detailsData = dailyData;
                    maxItem =
                        detailsData.isNotEmpty
                            ? detailsData.reduce(
                              (a, b) =>
                                  ((a['sales'] ?? 0) as num) >
                                          ((b['sales'] ?? 0) as num)
                                      ? a
                                      : b,
                            )
                            : null;
                  } else {
                    // Show all months from January to current month
                    totalSales = filteredMonthlyData.fold(
                      0.0,
                      (sum, d) => sum + (d['sales'] as double),
                    );
                    detailsData = filteredMonthlyData;
                    maxItem =
                        detailsData.isNotEmpty
                            ? detailsData.reduce(
                              (a, b) =>
                                  ((a['sales'] ?? 0) as num) >
                                          ((b['sales'] ?? 0) as num)
                                      ? a
                                      : b,
                            )
                            : null;
                  }

                  return RefreshIndicator(
                    onRefresh: _fetchData,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSalesCard(totalSales, detailsData, maxItem),
                          SizedBox(height: 20),
                          _buildTabSelector(),
                          SizedBox(height: 20),
                          _buildTabContent(),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
