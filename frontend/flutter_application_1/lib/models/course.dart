class Course {
  final int courseId;
  final String courseCode;
  final String courseName;

  Course({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['course_id'],
      courseCode: json['course_code'],
      courseName: json['course_name'],
    );
  }
}
