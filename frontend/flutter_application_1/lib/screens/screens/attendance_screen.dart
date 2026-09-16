import 'package:flutter/material.dart';

import '../api_service.dart';
import '../widgets/add_student_dialog.dart';
import '../widgets/notifications_dialog.dart';

class AttendanceScreen extends StatefulWidget {
  final int courseId;

  const AttendanceScreen({super.key, required this.courseId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<dynamic> _students = [];
  List<dynamic> _courses = [];
  bool _isLoading = true;
  String _selectedDate = DateTime.now().toString().split(' ')[0];
  int _selectedCourseId = 101;
  String _searchQuery = '';
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final courses = await ApiService.fetchCourses();
      setState(() => _courses = courses);
      await _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading initial data: $e')),
        );
      }
    }
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final records = await ApiService.fetchAttendanceForDate(
        date: _selectedDate,
        courseId: _selectedCourseId,
        search: _searchQuery,
      );
      final notifications = await ApiService.fetchNotifications();
      setState(() {
        _students = records;
        _notificationCount = notifications.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading attendance: $e')));
      }
    }
  }

  Future<void> _updateStatus(int studentId, String status) async {
    try {
      await ApiService.recordAttendance(
        studentId: studentId,
        courseId: _selectedCourseId,
        status: status,
        date: _selectedDate,
      );
      _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording attendance: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int total = _students.length;
    int present = _students.where((s) => s['status'] == 'Present').length;
    int absent = _students.where((s) => s['status'] == 'Absent').length;
    int notMarked = total - (present + absent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance Monitoring'),
        actions: [
          // 1. Notification Bell Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Notifications',
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => const NotificationsDialog(),
                  );
                  _loadAttendance();
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // 2. Header Quick Actions
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'Add Student',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddStudentDialog(
                  selectedCourseId: _selectedCourseId,
                  onStudentAdded: _loadAttendance,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Parent',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddStudentDialog(
              selectedCourseId: _selectedCourseId,
              onStudentAdded: _loadAttendance,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Controls: Date and Course Dropdown
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate),
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(_selectedDate),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked.toString().split(' ')[0];
                        });
                        _loadAttendance();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        _courses.any((c) => c['course_id'] == _selectedCourseId)
                        ? _selectedCourseId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Select Course',
                      border: OutlineInputBorder(),
                    ),
                    items: _courses.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['course_id'],
                        child: Text(
                          '${c['course_code']} - ${c['course_name']}',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCourseId = val);
                        _loadAttendance();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Field
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search student by name or admission no...',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _loadAttendance();
              },
            ),
            const SizedBox(height: 16),

            // Metrics Summary Cards
            Row(
              children: [
                _buildMetricCard('Total', total, Colors.blue),
                _buildMetricCard('Present', present, Colors.green),
                _buildMetricCard('Absent', absent, Colors.red),
                _buildMetricCard('Not Marked', notMarked, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),

            // Student List
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final currentStatus = student['status'] ?? 'Not Marked';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            student['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Admission No: ${student['admission_number']} | Status: $currentStatus',
                          ),
                          trailing: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentStatus == 'Present'
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                  ),
                                  onPressed: () =>
                                      _updateStatus(student['id'], 'Present'),
                                  child: const Text('Present'),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentStatus == 'Absent'
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                  onPressed: () =>
                                      _updateStatus(student['id'], 'Absent'),
                                  child: const Text('Absent'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}