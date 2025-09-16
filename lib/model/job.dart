class Job {
  final String id;
  final String carModel;
  final String plateNumber;
  final String mechanic;
  final String serviceType;
  final DateTime scheduledTime;
  final String imageUrl;
  final JobStatus status;

  Job({
    required this.id,
    required this.carModel,
    required this.plateNumber,
    required this.mechanic,
    required this.serviceType,
    required this.scheduledTime,
    required this.imageUrl,
    this.status = JobStatus.assigned,
  });

  String get formattedTime {
    // Convert to local time to handle timezone properly
    final localTime = scheduledTime.toLocal();
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';
    
    // Fix 12-hour conversion logic
    int displayHour = localTime.hour;
    if (displayHour == 0) {
      displayHour = 12; // 12 AM
    } else if (displayHour > 12) {
      displayHour = displayHour - 12; // 1-11 PM
    }
    // displayHour 12 stays as 12 (12 PM)
    
    return '$displayHour:$minute $period';
  }

  String get formattedDate {
    // Convert to local time to handle timezone properly
    final localTime = scheduledTime.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[localTime.month - 1]} ${localTime.day}';
  }
}

enum JobStatus {
  assigned,
  inProgress,
  completed,
  cancelled,
}
