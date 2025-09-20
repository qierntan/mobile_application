import 'package:cloud_firestore/cloud_firestore.dart';

class JobConflictService {
  /// Checks if assigning a mechanic to a job at a specific time would create a conflict
  /// Returns true if there's a conflict, false otherwise
  static Future<bool> checkTimeConflict({
    required String currentJobId,
    required String mechanicId,
    required dynamic jobTime,
  }) async {
    try {
      print('=== CONFLICT CHECK START ===');
      print('Current job ID: "$currentJobId"');
      print('Selected mechanic: "$mechanicId"');
      print('Selected time: $jobTime');
      print('Selected time type: ${jobTime.runtimeType}');
      
      // Force fresh query from database (no cache)
      QuerySnapshot allJobsSnapshot;
      try {
        allJobsSnapshot = await FirebaseFirestore.instance
            .collection('Jobs')
            .get(const GetOptions(source: Source.server));
        print('Used server source for fresh data');
      } catch (e) {
        print('Server fetch failed, trying cache: $e');
        await Future.delayed(Duration(milliseconds: 500));
        allJobsSnapshot = await FirebaseFirestore.instance
            .collection('Jobs')
            .get();
        print('Used cache source');
      }
      
      print('Total jobs in database: ${allJobsSnapshot.docs.length}');
      
      int conflictCount = 0;
      List<String> conflictingJobs = [];
      
      // Convert jobTime to DateTime for comparison
      DateTime? selectedDateTime;
      if (jobTime is Timestamp) {
        selectedDateTime = jobTime.toDate();
      } else if (jobTime is DateTime) {
        selectedDateTime = jobTime;
      }
      
      if (selectedDateTime == null) {
        print('Could not convert jobTime to DateTime');
        return false;
      }
      
      // Check if any job has the same mechanic and time (excluding current job)
      for (var doc in allJobsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final jobMechanicId = (data['mechanicId'] ?? '').toString();
        
        // Check both 'time' and 'time ' fields
        final otherJobTime = data['time'] ?? data['time '];
        if (otherJobTime == null) {
          print('Job ${doc.id}: No time field found');
          continue;
        }
        
        // Convert to DateTime for comparison
        DateTime? otherJobDateTime;
        if (otherJobTime is Timestamp) {
          otherJobDateTime = otherJobTime.toDate();
        } else if (otherJobTime is DateTime) {
          otherJobDateTime = otherJobTime;
        }
        
        if (otherJobDateTime == null) {
          print('Job ${doc.id}: Could not convert time to DateTime');
          continue;
        }
        
        // Skip current job
        if (doc.id == currentJobId) {
          print('→ SKIPPING current job ${doc.id}');
          continue;
        }
        
        // Check if same time and same mechanic
        // Use a more robust time comparison that accounts for potential timezone issues
        bool sameTime = _isSameTimeSlot(otherJobDateTime, selectedDateTime);
        bool sameMechanic = jobMechanicId == mechanicId;
        
        print('→ Job ${doc.id}: sameTime=$sameTime, sameMechanic=$sameMechanic');
        print('  → Job time: $otherJobDateTime (${otherJobDateTime.millisecondsSinceEpoch})');
        print('  → Selected time: $selectedDateTime (${selectedDateTime.millisecondsSinceEpoch})');
        print('  → Time difference: ${(otherJobDateTime.millisecondsSinceEpoch - selectedDateTime.millisecondsSinceEpoch).abs()}ms');
        print('  → Job mechanic: "$jobMechanicId" vs Selected mechanic: "$mechanicId"');
        print('  → Mechanic match: ${jobMechanicId == mechanicId}');
        
        if (sameTime && sameMechanic) {
          conflictCount++;
          conflictingJobs.add(doc.id);
          print('→ CONFLICT #$conflictCount: Job ${doc.id} has mechanic $jobMechanicId at same time $otherJobDateTime');
        }
      }
      
      print('=== CONFLICT CHECK END ===');
      print('Total conflicts found: $conflictCount');
      print('Conflicting job IDs: $conflictingJobs');
      
      return conflictCount > 0;
    } catch (e) {
      print('Error checking time conflict: $e');
      return false; // Allow save if check fails
    }
  }

  /// Gets mechanicId from mechanic name
  static Future<String?> getMechanicIdFromName(String mechanicName) async {
    try {
      final mechanicQuery = await FirebaseFirestore.instance
          .collection('Mechanics')
          .where('name', isEqualTo: mechanicName)
          .limit(1)
          .get();

      if (mechanicQuery.docs.isNotEmpty) {
        final mechData = mechanicQuery.docs.first.data();
        return (mechData['mechanicId'] ?? '').toString();
      }
      return null;
    } catch (e) {
      print('Error getting mechanicId from name: $e');
      return null;
    }
  }

  /// Gets mechanic name from mechanicId
  static Future<String?> getMechanicNameFromId(String mechanicId) async {
    try {
      final mechanicQuery = await FirebaseFirestore.instance
          .collection('Mechanics')
          .where('mechanicId', isEqualTo: mechanicId)
          .limit(1)
          .get();

      if (mechanicQuery.docs.isNotEmpty) {
        final mechData = mechanicQuery.docs.first.data();
        return (mechData['name'] ?? '').toString();
      }
      return null;
    } catch (e) {
      print('Error getting mechanic name from ID: $e');
      return null;
    }
  }

  /// Checks if a specific mechanic is available at a given time
  /// Returns true if available, false if they have a conflict
  static Future<bool> isMechanicAvailable({
    required String mechanicId,
    required dynamic jobTime,
    String? excludeJobId, // Job to exclude from conflict check (for editing existing jobs)
  }) async {
    try {
      print('=== AVAILABILITY CHECK START ===');
      print('Checking availability for mechanic: "$mechanicId"');
      print('At time: $jobTime');
      print('Excluding job: $excludeJobId');
      
      // Force fresh query from database
      QuerySnapshot allJobsSnapshot;
      try {
        allJobsSnapshot = await FirebaseFirestore.instance
            .collection('Jobs')
            .get(const GetOptions(source: Source.server));
        print('Used server source for fresh data');
      } catch (e) {
        print('Server fetch failed, trying cache: $e');
        await Future.delayed(Duration(milliseconds: 500));
        allJobsSnapshot = await FirebaseFirestore.instance
            .collection('Jobs')
            .get();
        print('Used cache source');
      }
      
      // Convert jobTime to DateTime for comparison
      DateTime? selectedDateTime;
      if (jobTime is Timestamp) {
        selectedDateTime = jobTime.toDate();
      } else if (jobTime is DateTime) {
        selectedDateTime = jobTime;
      }
      
      if (selectedDateTime == null) {
        print('Could not convert jobTime to DateTime');
        return true; // If we can't determine time, assume available
      }
      
      // Check if any job has the same mechanic and time (excluding specified job)
      for (var doc in allJobsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final jobMechanicId = (data['mechanicId'] ?? '').toString();
        
        // Skip if not the mechanic we're checking
        if (jobMechanicId != mechanicId) {
          continue;
        }
        
        // Skip if this is the job we're excluding (for editing existing jobs)
        if (excludeJobId != null && doc.id == excludeJobId) {
          print('→ SKIPPING excluded job ${doc.id}');
          continue;
        }
        
        // Check both 'time' and 'time ' fields
        final otherJobTime = data['time'] ?? data['time '];
        if (otherJobTime == null) {
          print('Job ${doc.id}: No time field found');
          continue;
        }
        
        // Convert to DateTime for comparison
        DateTime? otherJobDateTime;
        if (otherJobTime is Timestamp) {
          otherJobDateTime = otherJobTime.toDate();
        } else if (otherJobTime is DateTime) {
          otherJobDateTime = otherJobTime;
        }
        
        if (otherJobDateTime == null) {
          print('Job ${doc.id}: Could not convert time to DateTime');
          continue;
        }
        
        // Check if same time
        bool sameTime = _isSameTimeSlot(otherJobDateTime, selectedDateTime);
        
        print('→ Job ${doc.id}: sameTime=$sameTime');
        print('  → Job time: $otherJobDateTime vs Selected time: $selectedDateTime');
        
        if (sameTime) {
          print('→ CONFLICT FOUND: Mechanic $mechanicId has job ${doc.id} at same time $otherJobDateTime');
          print('=== AVAILABILITY CHECK END - NOT AVAILABLE ===');
          return false; // Mechanic is not available
        }
      }
      
      print('=== AVAILABILITY CHECK END - AVAILABLE ===');
      return true; // Mechanic is available
    } catch (e) {
      print('Error checking mechanic availability: $e');
      return true; // If check fails, assume available to avoid blocking
    }
  }

  /// Gets all available mechanics at a specific time
  /// Returns a list of mechanic IDs that are available
  static Future<List<String>> getAvailableMechanics({
    required dynamic jobTime,
    String? excludeJobId,
  }) async {
    try {
      print('=== GETTING AVAILABLE MECHANICS ===');
      print('At time: $jobTime');
      print('Excluding job: $excludeJobId');
      
      // Get all mechanics
      final mechanicsSnapshot = await FirebaseFirestore.instance
          .collection('Mechanics')
          .get();
      
      List<String> availableMechanics = [];
      
      for (var doc in mechanicsSnapshot.docs) {
        final data = doc.data();
        final mechanicId = (data['mechanicId'] ?? '').toString();
        
        if (mechanicId.isNotEmpty) {
          final isAvailable = await isMechanicAvailable(
            mechanicId: mechanicId,
            jobTime: jobTime,
            excludeJobId: excludeJobId,
          );
          
          if (isAvailable) {
            availableMechanics.add(mechanicId);
            print('→ Mechanic $mechanicId is AVAILABLE');
          } else {
            print('→ Mechanic $mechanicId is NOT AVAILABLE');
          }
        }
      }
      
      print('=== AVAILABLE MECHANICS: $availableMechanics ===');
      return availableMechanics;
    } catch (e) {
      print('Error getting available mechanics: $e');
      return []; // Return empty list if error occurs
    }
  }

  /// Helper method to check if two DateTime objects represent the same time slot
  /// This accounts for potential timezone differences and small time variations
  static bool _isSameTimeSlot(DateTime time1, DateTime time2) {
    // Convert both times to UTC for comparison
    final utc1 = time1.toUtc();
    final utc2 = time2.toUtc();
    
    // Check if they're at the same moment (exact match)
    if (utc1.isAtSameMomentAs(utc2)) {
      return true;
    }
    
    // Check if they're within 1 minute of each other (handles small time differences)
    final timeDifference = (utc1.millisecondsSinceEpoch - utc2.millisecondsSinceEpoch).abs();
    if (timeDifference <= 60000) { // 1 minute = 60,000 milliseconds
      return true;
    }
    
    // Also check if they're within the same hour (in case of timezone conversion issues)
    final hour1 = utc1.hour;
    final hour2 = utc2.hour;
    final day1 = utc1.day;
    final day2 = utc2.day;
    final month1 = utc1.month;
    final month2 = utc2.month;
    final year1 = utc1.year;
    final year2 = utc2.year;
    
    // Same year, month, day, and hour
    return year1 == year2 && month1 == month2 && day1 == day2 && hour1 == hour2;
  }
}
