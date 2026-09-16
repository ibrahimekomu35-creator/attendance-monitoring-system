import 'package:flutter/material.dart';

import '../api_service.dart';

class AddStudentDialog extends StatefulWidget {
  final int selectedCourseId;
  final VoidCallback onStudentAdded;

  const AddStudentDialog({
    super.key,
    required this.selectedCourseId,
    required this.onStudentAdded,
  });

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final admNoController = TextEditingController();

  final parentFirstNameController = TextEditingController();
  final parentLastNameController = TextEditingController();
  final parentPhoneController = TextEditingController();
  final parentEmailController = TextEditingController();
  String parentRelationship = 'Father';

  bool isLoading = false;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    admNoController.dispose();
    parentFirstNameController.dispose();
    parentLastNameController.dispose();
    parentPhoneController.dispose();
    parentEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Student & Parent Contact'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Student Info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: admNoController,
                decoration: const InputDecoration(
                  labelText: 'Admission Number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Primary Parent/Guardian Info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: parentFirstNameController,
                decoration: const InputDecoration(
                  labelText: 'Parent First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: parentLastNameController,
                decoration: const InputDecoration(
                  labelText: 'Parent Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: parentPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: parentEmailController,
                decoration: const InputDecoration(
                  labelText: 'Parent Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: parentRelationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
                items: ['Father', 'Mother', 'Guardian', 'Other']
                    .map(
                      (rel) => DropdownMenuItem(value: rel, child: Text(rel)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => parentRelationship = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => isLoading = true);
                    try {
                      await ApiService.addStudent(
                        firstName: firstNameController.text.trim(),
                        lastName: lastNameController.text.trim(),
                        admissionNumber: admNoController.text.trim(),
                        courseId: widget.selectedCourseId,
                        parentFirstName: parentFirstNameController.text.trim(),
                        parentLastName: parentLastNameController.text.trim(),
                        parentPhone: parentPhoneController.text.trim(),
                        parentEmail: parentEmailController.text.trim(),
                        parentRelationship: parentRelationship,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        widget.onStudentAdded();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding student: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  }
                },
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Student'),
        ),
      ],
    );
  }
}
