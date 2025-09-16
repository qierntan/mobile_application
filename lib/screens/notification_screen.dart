import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_application/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final String? notificationType;
  final Map<String, dynamic>? arguments;

  const NotificationScreen({Key? key, this.notificationType, this.arguments})
    : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  bool isEditMode = false;
  Set<String> selectedNotifications = Set<String>();

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    // If navigated from notification tap, show specific notification
    if (widget.notificationType != null && widget.arguments != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSpecificNotification();
      });
    }
  }

  void _handleSpecificNotification() {
    if (widget.notificationType == 'payment' && widget.arguments != null) {
      final paymentId = widget.arguments!['paymentId'];
      _showPaymentDetailsDialog(paymentId);
    }
  }

  Future<void> _loadNotifications() async {
    try {
      // Fetch actual notifications from Firebase
      final notificationService = NotificationService();
      final firebaseNotifications =
          await notificationService.getNotificationsFromFirebase();

      // Convert Firebase data to display format
      final List<Map<String, dynamic>> formattedNotifications =
          firebaseNotifications.map<Map<String, dynamic>>((notification) {
            IconData icon;
            Color color;

            switch (notification['type']) {
              case 'payment':
                icon = Icons.payment;
                color = Colors.green;
                break;
              case 'service':
                icon = Icons.build;
                color = Colors.orange;
                break;
              case 'reply':
                icon = Icons.chat_bubble_outline;
                color = Colors.blue;
                break;
              default:
                icon = Icons.notifications;
                color = Colors.grey;
            }

            return {
              'id': notification['id'],
              'type': notification['type'],
              'title': notification['title'],
              'message': notification['message'],
              'timestamp': notification['timestamp'],
              'isRead': notification['isRead'],
              'icon': icon,
              'color': color,
              // Add specific data based on type
              ...notification['data'] as Map<String, dynamic>,
            };
          }).toList();

      setState(() {
        notifications = formattedNotifications;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode
              ? '${selectedNotifications.length} selected'
              : 'Notifications',
        ),
        backgroundColor: Color(0xFF5A9FD4),
        foregroundColor: Colors.white,
        actions: [
          if (isEditMode) ...[
            if (selectedNotifications.isNotEmpty) ...[
              IconButton(
                onPressed: _batchMarkAsRead,
                icon: Icon(Icons.mark_email_read),
                tooltip: 'Mark as read',
              ),
              IconButton(
                onPressed: _batchDelete,
                icon: Icon(Icons.delete),
                tooltip: 'Delete selected',
              ),
            ],
            if (notifications.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    if (selectedNotifications.length == notifications.length) {
                      selectedNotifications.clear();
                    } else {
                      selectedNotifications.clear();
                      for (var notification in notifications) {
                        selectedNotifications.add(notification['id']);
                      }
                    }
                  });
                },
                child: Text(
                  selectedNotifications.length == notifications.length
                      ? 'Unselect All'
                      : 'Select All',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            TextButton(
              onPressed: () {
                setState(() {
                  isEditMode = false;
                  selectedNotifications.clear();
                });
              },
              child: Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            if (notifications.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    isEditMode = true;
                  });
                },
                icon: Icon(Icons.edit),
                tooltip: 'Edit notifications',
              ),
            IconButton(
              icon: Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'delete_all':
                    _showDeleteAllConfirmation();
                    break;
                }
              },
              itemBuilder:
                  (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Delete All',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'You\'ll see notifications here when they arrive',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final timestamp = notification['timestamp'] as DateTime;
    final timeAgo = _getTimeAgo(timestamp);
    final notificationId = notification['id'] as String;
    final isSelected = selectedNotifications.contains(notificationId);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      color:
          isSelected
              ? Color(0xFF5A9FD4).withOpacity(0.1)
              : (isRead ? Colors.grey[50] : Colors.white),
      child: InkWell(
        onTap: () {
          if (isEditMode) {
            _toggleNotificationSelection(notificationId);
          } else {
            _handleNotificationTap(notification);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox in edit mode
              if (isEditMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleNotificationSelection(notificationId);
                  },
                  activeColor: Color(0xFF5A9FD4),
                ),
                SizedBox(width: 8),
              ],
              // Icon container
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (notification['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification['icon'],
                  color: notification['color'],
                  size: 24,
                ),
              ),
              SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'],
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification['message'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        if (!isEditMode)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed:
                                    () =>
                                        _handleNotificationAction(notification),
                                child: Text(
                                  'View',
                                  style: TextStyle(
                                    color: Color(0xFF5A9FD4),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    () => _deleteNotification(notification),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[400],
                                  size: 20,
                                ),
                                tooltip: 'Delete notification',
                                constraints: BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.all(4),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read locally
    setState(() {
      notification['isRead'] = true;
    });

    // Mark as read in Firebase
    final notificationService = NotificationService();
    notificationService.markNotificationAsRead(notification['id']);

    // Handle specific notification type
    _handleNotificationAction(notification);
  }

  void _handleNotificationAction(Map<String, dynamic> notification) {
    final type = notification['type'];

    switch (type) {
      case 'payment':
        // Use paymentId from notification data if available, otherwise use invoiceId
        final paymentId =
            notification['paymentId'] ??
            notification['invoiceId'] ??
            notification['id'];
        _showPaymentDetailsDialog(paymentId);
        break;
      case 'service':
        final vehicleId = notification['vehicleId'] ?? 'Unknown Vehicle';
        _showServiceDetailsDialog(vehicleId);
        break;
      case 'reply':
        final customerId = notification['customerId'] ?? 'Unknown Customer';
        _showReplyDetailsDialog(customerId);
        break;
    }
  }

  void _showPaymentDetailsDialog(String paymentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDetailsDialog(paymentId: paymentId);
      },
    );
  }

  void _showServiceDetailsDialog(String vehicleId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.build, color: Colors.orange),
              SizedBox(width: 8),
              Text('Service Reminder'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vehicle ID: $vehicleId'),
              SizedBox(height: 8),
              Text('This vehicle is due for scheduled maintenance.'),
              SizedBox(height: 8),
              Text('Please schedule a service appointment.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to vehicle details or scheduling screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigate to vehicle details')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('Schedule Service'),
            ),
          ],
        );
      },
    );
  }

  void _showReplyDetailsDialog(String customerId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Customer Reply'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer ID: $customerId'),
              SizedBox(height: 8),
              Text('Customer replied to your message.'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"Thank you for the excellent service! Very satisfied with the work done."',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to customer chat or details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigate to customer chat')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Reply'),
            ),
          ],
        );
      },
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
    });

    // Mark all as read in Firebase
    final notificationService = NotificationService();
    notificationService.markAllNotificationsAsRead();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('All notifications marked as read')));
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete All Notifications'),
          content: Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllNotifications();
              },
              child: Text('Delete All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteNotification(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Notification'),
          content: Text('Are you sure you want to delete this notification?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performDeleteNotification(notification);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _performDeleteNotification(Map<String, dynamic> notification) async {
    try {
      final notificationId = notification['id'] as String;
      await NotificationService().deleteNotification(notificationId);

      // Refresh the notifications list
      _loadNotifications();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting notification'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteAllNotifications() async {
    try {
      await NotificationService().deleteAllNotifications();

      // Refresh the notifications list
      _loadNotifications();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All notifications deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting all notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting notifications'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleNotificationSelection(String notificationId) {
    setState(() {
      if (selectedNotifications.contains(notificationId)) {
        selectedNotifications.remove(notificationId);
      } else {
        selectedNotifications.add(notificationId);
      }
    });
  }

  void _batchMarkAsRead() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mark as Read'),
          content: Text(
            'Mark ${selectedNotifications.length} notification(s) as read?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performBatchMarkAsRead();
              },
              child: Text(
                'Mark as Read',
                style: TextStyle(color: Color(0xFF5A9FD4)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performBatchMarkAsRead() async {
    try {
      final notificationService = NotificationService();

      // Mark selected notifications as read in Firebase
      for (String notificationId in selectedNotifications) {
        await notificationService.markNotificationAsRead(notificationId);
      }

      // Update local state
      setState(() {
        for (var notification in notifications) {
          if (selectedNotifications.contains(notification['id'])) {
            notification['isRead'] = true;
          }
        }
        isEditMode = false;
        selectedNotifications.clear();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notifications as read'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _batchDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Notifications'),
          content: Text(
            'Are you sure you want to delete ${selectedNotifications.length} notification(s)? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performBatchDelete();
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _performBatchDelete() async {
    try {
      final notificationService = NotificationService();

      // Delete selected notifications from Firebase
      for (String notificationId in selectedNotifications) {
        await notificationService.deleteNotification(notificationId);
      }

      // Refresh the notifications list
      _loadNotifications();

      // Reset edit mode
      setState(() {
        isEditMode = false;
        selectedNotifications.clear();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifications deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting notifications'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class PaymentDetailsDialog extends StatefulWidget {
  final String paymentId;

  const PaymentDetailsDialog({Key? key, required this.paymentId})
    : super(key: key);

  @override
  _PaymentDetailsDialogState createState() => _PaymentDetailsDialogState();
}

class _PaymentDetailsDialogState extends State<PaymentDetailsDialog> {
  Map<String, dynamic>? paymentDetails;
  Map<String, dynamic>? invoiceDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      // Fetch actual payment details from Firebase
      await _fetchFromFirebase();
    } catch (e) {
      print('Error fetching from Firebase: $e');
      // Show error state instead of mock data
      setState(() {
        isLoading = false;
        paymentDetails = null;
        invoiceDetails = null;
      });
    }
  }

  Future<void> _fetchFromFirebase() async {
    try {
      DocumentSnapshot? foundDoc;

      // Check if paymentId is in P1001 format
      if (widget.paymentId.startsWith('P')) {
        // Extract numeric part from payment ID
        final numericPart = widget.paymentId.substring(1);

        // Search for invoice containing this number in the ID
        final invoiceQuery =
            await FirebaseFirestore.instance
                .collection('Invoice')
                .where('status', isEqualTo: 'Paid')
                .get();

        // Find invoice with matching numeric part in ID
        for (var doc in invoiceQuery.docs) {
          if (doc.id.contains(numericPart)) {
            foundDoc = doc;
            break;
          }
        }

        // If not found by numeric match, get the most recent paid invoice
        if (foundDoc == null && invoiceQuery.docs.isNotEmpty) {
          // Sort by payment date and get the most recent
          final sortedDocs =
              invoiceQuery.docs.toList()..sort((a, b) {
                final aData = a.data();
                final bData = b.data();
                final aDate = aData['paymentDate'] as Timestamp?;
                final bDate = bData['paymentDate'] as Timestamp?;
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });
          foundDoc = sortedDocs.first;
        }
      } else {
        // Try to find invoice by exact ID match
        final doc =
            await FirebaseFirestore.instance
                .collection('Invoice')
                .doc(widget.paymentId)
                .get();
        if (doc.exists) {
          foundDoc = doc;
        }
      }

      if (foundDoc == null || !foundDoc.exists) {
        // Show error state
        setState(() {
          isLoading = false;
          paymentDetails = null;
          invoiceDetails = null;
        });
        return;
      }

      // At this point foundDoc is guaranteed to be non-null
      final invoiceDoc = foundDoc;
      final data = invoiceDoc.data() as Map<String, dynamic>;

      // Use the provided payment ID or generate one
      String paymentId =
          widget.paymentId.startsWith('P')
              ? widget.paymentId
              : _generatePaymentId(invoiceDoc.id);

      setState(() {
        invoiceDetails = {
          'id': invoiceDoc.id,
          'customerName': data['customerName'] ?? 'Unknown Customer',
          'vehicleId':
              data['vehicleId'] ?? data['vehicleNumber'] ?? 'Unknown Vehicle',
          'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
          'paymentDate':
              (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'paymentMethod': data['paymentMethod'] ?? 'Online Payment',
          'parts': List<Map<String, dynamic>>.from(data['parts'] ?? []),
          'subtotal': (data['subtotal'] ?? 0.0).toDouble(),
          'tax': (data['tax'] ?? 0.0).toDouble(),
          'discount': (data['discount'] ?? 0.0).toDouble(),
          'discountType': data['discountType'] ?? 'fixed',
          'paymentSessionId': data['paymentSessionId'],
        };

        paymentDetails = {
          'paymentId': paymentId,
          'amount': invoiceDetails!['totalAmount'],
          'customerName': invoiceDetails!['customerName'],
          'invoiceId': invoiceDetails!['id'],
          'paymentDate': invoiceDetails!['paymentDate'],
          'paymentMethod': invoiceDetails!['paymentMethod'],
          'status': 'Completed',
        };

        isLoading = false;
      });
    } catch (e) {
      print('Error fetching from Firebase: $e');
      // Show error state
      setState(() {
        isLoading = false;
        paymentDetails = null;
        invoiceDetails = null;
      });
    }
  }

  // Generate payment ID in P1001 format based on invoice ID
  String _generatePaymentId(String invoiceId) {
    // Extract numeric part from invoice ID if it contains numbers
    final RegExp regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(invoiceId);

    if (match != null) {
      final numericPart = match.group(0)!;
      return 'P$numericPart';
    } else {
      // If no numbers found, use current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shortId = (timestamp % 10000).toString().padLeft(4, '0');
      return 'P$shortId';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Dialog(
        child: Container(
          padding: EdgeInsets.all(20),
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Show error state if no payment details found
    if (paymentDetails == null || invoiceDetails == null) {
      return Dialog(
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'Payment Details Not Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'The payment information could not be loaded from Firebase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5A9FD4),
                  foregroundColor: Colors.white,
                ),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Payment Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Summary
                    _buildSectionHeader('Payment Summary'),
                    _buildDetailRow('Payment ID', paymentDetails!['paymentId']),
                    _buildDetailRow(
                      'Amount',
                      'RM ${paymentDetails!['amount'].toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Customer',
                      paymentDetails!['customerName'],
                    ),
                    _buildDetailRow('Invoice ID', paymentDetails!['invoiceId']),
                    _buildDetailRow(
                      'Payment Date',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(paymentDetails!['paymentDate']),
                    ),
                    _buildDetailRow(
                      'Payment Method',
                      paymentDetails!['paymentMethod'],
                    ),
                    _buildDetailRow(
                      'Status',
                      paymentDetails!['status'],
                      valueColor: Colors.green,
                      isBold: true,
                    ),

                    SizedBox(height: 20),

                    // Invoice Details
                    if (invoiceDetails != null) ...[
                      _buildSectionHeader('Invoice Details'),
                      if (invoiceDetails!['parts'] != null &&
                          invoiceDetails!['parts'].isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'Items:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...invoiceDetails!['parts']
                            .map<Widget>(
                              (part) => _buildItemRow(
                                part['description'] ?? 'Unknown Item',
                                part['quantity']?.toString() ?? '1',
                                'RM ${(part['unitPrice'] ?? 0.0).toStringAsFixed(2)}',
                                'RM ${(part['total'] ?? 0.0).toStringAsFixed(2)}',
                              ),
                            )
                            .toList(),
                        Divider(),
                        _buildCalculationRow(
                          'Subtotal',
                          'RM ${invoiceDetails!['subtotal'].toStringAsFixed(2)}',
                        ),
                        _buildCalculationRow(
                          'Tax (6%)',
                          'RM ${invoiceDetails!['tax'].toStringAsFixed(2)}',
                        ),
                        if (invoiceDetails!['discount'] > 0)
                          _buildCalculationRow(
                            invoiceDetails!['discountType'] == 'percentage'
                                ? 'Discount (${invoiceDetails!['discount']}%)'
                                : 'Discount',
                            '-RM ${invoiceDetails!['discountType'] == 'percentage' ? (invoiceDetails!['subtotal'] * invoiceDetails!['discount'] / 100).toStringAsFixed(2) : invoiceDetails!['discount'].toStringAsFixed(2)}',
                            valueColor: Colors.red,
                          ),
                        Divider(thickness: 2),
                        _buildCalculationRow(
                          'Total',
                          'RM ${invoiceDetails!['totalAmount'].toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E2E2E),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    String description,
    String quantity,
    String unitPrice,
    String total,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(description, style: TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              quantity,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              unitPrice,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              total,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
