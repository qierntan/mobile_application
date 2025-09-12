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
    final minute = scheduledTime.minute.toString().padLeft(2, '0');
    final period = scheduledTime.hour >= 12 ? 'PM' : 'AM';
    final displayHour = scheduledTime.hour > 12 ? scheduledTime.hour - 12 : scheduledTime.hour;
    final displayHourStr = displayHour == 0 ? '12' : displayHour.toString();
    return '$displayHourStr:$minute $period';
  }

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[scheduledTime.month - 1]} ${scheduledTime.day}';
  }
}

enum JobStatus {
  assigned,
  inProgress,
  completed,
  cancelled,
}
