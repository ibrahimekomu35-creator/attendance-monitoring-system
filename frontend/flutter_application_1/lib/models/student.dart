class Student {
  final int id;
  final String name;
  final String admissionNumber;
  final String status;

  Student({
    required this.id,
    required this.name,
    required this.admissionNumber,
    required this.status,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'] ?? 'Student #${json['id']}',
      admissionNumber: json['admission_number']?.toString() ?? '',
      status: json['status'] ?? 'Not Marked',
    );
  }
}
