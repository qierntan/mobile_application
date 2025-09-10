import 'package:flutter/material.dart';

class Mechanic {
  final String id;
  final String name;
  int workload;

  Mechanic({required this.id, required this.name, this.workload = 0});
}

class Job {
  final String id;
  final String vehicle;
  final String description;
  final DateTime scheduledDate;
  String? assignedMechanicId;
  final String status;

  Job({
    required this.id,
    required this.vehicle,
    required this.description,
    required this.scheduledDate,
    this.assignedMechanicId,
    required this.status,
  });
}

class WorkSchedulerScreen extends StatefulWidget {
  const WorkSchedulerScreen({Key? key}) : super(key: key);

  @override
  State<WorkSchedulerScreen> createState() => _WorkSchedulerScreenState();
}

class _WorkSchedulerScreenState extends State<WorkSchedulerScreen> {
  List<Mechanic> mechanics = [
    Mechanic(id: '1', name: 'Alice'),
    Mechanic(id: '2', name: 'Bob'),
    Mechanic(id: '3', name: 'Charlie'),
  ];

  List<Job> jobs = [
    Job(
      id: 'j1',
      vehicle: 'Toyota Camry',
      description: 'Oil Change',
      scheduledDate: DateTime.now(),
      assignedMechanicId: '1',
      status: 'Scheduled',
    ),
    Job(
      id: 'j2',
      vehicle: 'Honda Accord',
      description: 'Brake Inspection',
      scheduledDate: DateTime.now().add(Duration(days: 1)),
      assignedMechanicId: null,
      status: 'Pending',
    ),
    Job(
      id: 'j3',
      vehicle: 'Ford F-150',
      description: 'Tire Rotation',
      scheduledDate: DateTime.now().add(Duration(days: 2)),
      assignedMechanicId: '2',
      status: 'Scheduled',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _updateMechanicWorkloads();
  }

  void _updateMechanicWorkloads() {
    for (var mechanic in mechanics) {
      mechanic.workload = jobs.where((job) => job.assignedMechanicId == mechanic.id).length;
    }
  }

  void _assignJob(Job job, String? mechanicId) {
    setState(() {
      job.assignedMechanicId = mechanicId;
      _updateMechanicWorkloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Work Scheduler'), backgroundColor: Colors.teal),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mechanic Workloads', style: TextStyle(fontWeight: FontWeight.bold)),
                ...mechanics.map((m) => Chip(label: Text('${m.name}: ${m.workload} jobs'))),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: ListTile(
                    leading: const Icon(Icons.assignment),
                    title: Text(job.description),
                    subtitle: Text('Vehicle: ${job.vehicle}\nDate: ${job.scheduledDate.toLocal().toString().split(' ')[0]}\nStatus: ${job.status}'),
                    trailing: DropdownButton<String?>(
                      value: job.assignedMechanicId,
                      hint: const Text('Assign'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Unassigned')),
                        ...mechanics.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                      ],
                      onChanged: (value) => _assignJob(job, value),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 