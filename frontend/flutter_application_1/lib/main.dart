import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'widgets/add_course_dialog.dart';
import 'widgets/add_student_dialog.dart';
import 'widgets/notifications_dialog.dart';
import 'widgets/stat_card.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      home: const AttendanceHomePage(),
    );
  }
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  DateTime selectedDate = DateTime.now();
  int selectedCourseId = 101;
  String searchQuery = '';
  List<dynamic> courses = [];
  int _notificationCount = 0;
  late Future<List<dynamic>> _studentsFuture;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final data = await ApiService.fetchCourses().timeout(
        const Duration(seconds: 5),
      );
      setState(() {
        courses = data;
        if (courses.isNotEmpty &&
            !courses.any((c) => c['course_id'] == selectedCourseId)) {
          selectedCourseId = courses.first['course_id'];
        }
      });
    } catch (e) {
      setState(() {
        courses = [
          {
            'course_id': 101,
            'course_code': 'CS101',
            'course_name': 'Computer Science Intro',
          },
          {
            'course_id': 102,
            'course_code': 'CS102',
            'course_name': 'Data Structures & Algorithms',
          },
          {
            'course_id': 103,
            'course_code': 'CS103',
            'course_name': 'Database Systems',
          },
        ];
      });
    } finally {
      _loadData();
    }
  }

  void _loadData() async {
    String dateStr = selectedDate.toIso8601String().split('T')[0];

    try {
      final notifications = await ApiService.fetchNotifications();
      if (mounted) {
        setState(() {
          _notificationCount = notifications.length;
        });
      }
    } catch (_) {}

    setState(() {
      _studentsFuture =
          ApiService.fetchAttendanceForDate(
            date: dateStr,
            courseId: selectedCourseId,
            search: searchQuery,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'Backend server did not respond in time.',
            ),
          );
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _submitAttendance(int studentId, String status) async {
    try {
      String dateStr = selectedDate.toIso8601String().split('T')[0];
      await ApiService.recordAttendance(
        studentId: studentId,
        courseId: selectedCourseId,
        status: status,
        date: dateStr,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Attendance marked as $status')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _downloadPdf() {
    String selectedFilter = 'All';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export PDF Attendance Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter students by status:'),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedFilter,
                isExpanded: true,
                items: ['All', 'Present', 'Absent', 'Not Marked']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedFilter = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                String dateStr = selectedDate.toIso8601String().split('T')[0];
                String url =
                    'http://127.0.0.1:8000/attendance/pdf?date=$dateStr&course_id=$selectedCourseId&status_filter=$selectedFilter';
                html.window.open(url, '_blank');
              },
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentHistoryDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance History: ${student['name']}'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: FutureBuilder<List<dynamic>>(
            future: ApiService.fetchStudentHistory(student['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('No attendance history found.'),
                );
              }

              final logs = snapshot.data!;
              return ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, idx) {
                  final log = logs[idx];
                  final isPresent = log['status'] == 'Present';
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isPresent ? Icons.check_circle : Icons.cancel,
                      color: isPresent ? Colors.green : Colors.red,
                    ),
                    title: Text('${log['course_code']} - ${log['date']}'),
                    subtitle: Text('Status: ${log['status']}'),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCourseDialog(onCourseAdded: _loadCourses),
    );
  }

  void _showEditCourseDialog() {
    final currentCourse = courses.firstWhere(
      (c) => c['course_id'] == selectedCourseId,
      orElse: () => null,
    );
    if (currentCourse == null) return;

    final codeController = TextEditingController(
      text: currentCourse['course_code'],
    );
    final nameController = TextEditingController(
      text: currentCourse['course_name'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Course Code'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Course Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.updateCourse(
                  courseId: selectedCourseId,
                  courseCode: codeController.text.trim(),
                  courseName: nameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadCourses();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating course: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCourse() async {
    final currentCourse = courses.firstWhere(
      (c) => c['course_id'] == selectedCourseId,
      orElse: () => null,
    );
    if (currentCourse == null) return;

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Course'),
            content: Text(
              'Are you sure you want to delete ${currentCourse['course_name']}? This will also remove associated students and attendance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await ApiService.deleteCourse(selectedCourseId);
        _loadCourses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting course: $e')));
        }
      }
    }
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddStudentDialog(
        selectedCourseId: selectedCourseId,
        onStudentAdded: _loadData,
      ),
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    List<String> nameParts = (student['name'] ?? '').split(' ');
    final firstNameController = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts.first : '',
    );
    final lastNameController = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    );
    final admNoController = TextEditingController(
      text: student['admission_number']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: admNoController,
              decoration: const InputDecoration(labelText: 'Admission Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.updateStudent(
                  studentId: student['id'],
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  admissionNumber: admNoController.text.trim(),
                  courseId: selectedCourseId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating student: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteStudent(Map<String, dynamic> student) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Student'),
            content: Text(
              'Are you sure you want to remove ${student['name']}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await ApiService.deleteStudent(student['id']);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting student: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = selectedDate.toIso8601String().split('T')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance Monitoring'),
        elevation: 2,
        actions: [
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
                  _loadData();
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
          IconButton(
            icon: const Icon(Icons.library_add),
            tooltip: 'Add New Course',
            onPressed: _showAddCourseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add New Student',
            onPressed: _showAddStudentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.white,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(formattedDate),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        courses.any((c) => c['course_id'] == selectedCourseId)
                        ? selectedCourseId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Select Course',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: courses.map<DropdownMenuItem<int>>((c) {
                      return DropdownMenuItem<int>(
                        value: c['course_id'],
                        child: Text(
                          '${c['course_code']} - ${c['course_name']}',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedCourseId = val;
                        });
                        _loadData();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Edit Current Course',
                  onPressed: _showEditCourseDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Current Course',
                  onPressed: _confirmDeleteCourse,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search student by name or admission no...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchQuery = '';
                          });
                          _loadData();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
                _loadData();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load students: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No student records found.'));
                }

                final students = snapshot.data!;
                int totalCount = students.length;
                int presentCount = students
                    .where((s) => s['status'] == 'Present')
                    .length;
                int absentCount = students
                    .where((s) => s['status'] == 'Absent')
                    .length;
                int notMarkedCount = totalCount - (presentCount + absentCount);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          StatCard(
                            title: 'Total',
                            count: '$totalCount',
                            color: Colors.blue.shade800,
                          ),
                          StatCard(
                            title: 'Present',
                            count: '$presentCount',
                            color: Colors.green.shade700,
                          ),
                          StatCard(
                            title: 'Absent',
                            count: '$absentCount',
                            color: Colors.red.shade700,
                          ),
                          StatCard(
                            title: 'Not Marked',
                            count: '$notMarkedCount',
                            color: Colors.orange.shade800,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          String currentStatus =
                              student['status'] ?? 'Not Marked';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student['name'] ??
                                              'Student #${student['id']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Admission No: ${student['admission_number']} | Status: $currentStatus',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              currentStatus == 'Present'
                                              ? Colors.green.shade800
                                              : Colors.green,
                                        ),
                                        onPressed: () => _submitAttendance(
                                          student['id'],
                                          'Present',
                                        ),
                                        child: const Text('Present'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              currentStatus == 'Absent'
                                              ? Colors.red.shade800
                                              : Colors.red,
                                        ),
                                        onPressed: () => _submitAttendance(
                                          student['id'],
                                          'Absent',
                                        ),
                                        child: const Text('Absent'),
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'history') {
                                            _showStudentHistoryDialog(student);
                                          } else if (value == 'edit') {
                                            _showEditStudentDialog(student);
                                          } else if (value == 'delete') {
                                            _confirmDeleteStudent(student);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'history',
                                            child: Row(
                                              children: [
                                                Icon(Icons.history, size: 18),
                                                SizedBox(width: 8),
                                                Text('History'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
