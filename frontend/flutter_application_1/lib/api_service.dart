import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<List<dynamic>> fetchCourses() async {
    final response = await http.get(Uri.parse('$baseUrl/courses'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load courses');
    }
  }

  static Future<void> addCourse({
    required String courseCode,
    required String courseName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/courses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'course_code': courseCode, 'course_name': courseName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add course');
    }
  }

  static Future<void> updateCourse({
    required int courseId,
    required String courseCode,
    required String courseName,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/courses/$courseId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'course_code': courseCode, 'course_name': courseName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update course');
    }
  }

  static Future<void> deleteCourse(int courseId) async {
    final response = await http.delete(Uri.parse('$baseUrl/courses/$courseId'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete course');
    }
  }

  static Future<List<dynamic>> fetchAttendanceForDate({
    required String date,
    required int courseId,
    String search = '',
  }) async {
    final url =
        '$baseUrl/attendance?date=$date&course_id=$courseId&search=${Uri.encodeComponent(search)}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load attendance');
    }
  }

  static Future<List<dynamic>> fetchStudentHistory(int studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/student-history/$studentId'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load student history');
    }
  }

  static Future<List<dynamic>> fetchNotifications() async {
    final response = await http.get(Uri.parse('$baseUrl/notifications'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load notification logs');
    }
  }

  static Future<void> recordAttendance({
    required int studentId,
    required int courseId,
    required String status,
    required String date,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'student_id': studentId,
        'course_id': courseId,
        'status': status,
        'date': date,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to record attendance');
    }
  }

  static Future<void> addStudent({
    required String firstName,
    required String lastName,
    required String admissionNumber,
    required int courseId,
    String? parentFirstName,
    String? parentLastName,
    String? parentPhone,
    String? parentRelationship,
  }) async {
    final Map<String, dynamic> payload = {
      'first_name': firstName,
      'last_name': lastName,
      'admission_number': admissionNumber,
      'course_id': courseId,
    };

    if (parentFirstName != null &&
        parentLastName != null &&
        parentPhone != null &&
        parentRelationship != null &&
        parentPhone.isNotEmpty) {
      payload['parent'] = {
        'first_name': parentFirstName,
        'last_name': parentLastName,
        'phone': parentPhone,
        'relationship': parentRelationship,
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/students'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add student');
    }
  }

  static Future<void> updateStudent({
    required int studentId,
    required String firstName,
    required String lastName,
    required String admissionNumber,
    required int courseId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/students/$studentId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'first_name': firstName,
        'last_name': lastName,
        'admission_number': admissionNumber,
        'course_id': courseId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update student');
    }
  }

  static Future<void> deleteStudent(int studentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/students/$studentId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete student');
    }
  }
}
