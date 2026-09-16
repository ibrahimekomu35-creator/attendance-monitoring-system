import 'package:flutter/material.dart';

import '../api_service.dart';

class AddCourseDialog extends StatefulWidget {
  final VoidCallback onCourseAdded;

  const AddCourseDialog({super.key, required this.onCourseAdded});

  @override
  State<AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<AddCourseDialog> {
  final courseCodeController = TextEditingController();
  final courseNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Course'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: courseCodeController,
            decoration: const InputDecoration(
              labelText: 'Course Code (e.g., CS104)',
            ),
          ),
          TextField(
            controller: courseNameController,
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
            if (courseCodeController.text.isNotEmpty &&
                courseNameController.text.isNotEmpty) {
              try {
                await ApiService.addCourse(
                  courseCode: courseCodeController.text.trim(),
                  courseName: courseNameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  widget.onCourseAdded();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Course added successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding course: $e')),
                  );
                }
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
