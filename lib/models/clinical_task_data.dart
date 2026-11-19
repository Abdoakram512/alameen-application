import 'package:equatable/equatable.dart';
import 'assignment.dart';
import 'assignment_submission.dart';

/// بيانات المهام والتسليمات القادمة من GET /student/assignments
class StudentAssignmentsData extends Equatable {
  final List<Assignment> tasks;
  final List<AssignmentSubmission> submissions;

  const StudentAssignmentsData({
    this.tasks = const [],
    this.submissions = const [],
  });

  factory StudentAssignmentsData.fromJson(Map<String, dynamic> rawJson) {
    final data = (rawJson['data'] is Map)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    final rawTasks = data['tasks'] as List? ?? const [];
    final tasks = rawTasks
        .whereType<Map>()
        .map((m) => Assignment.fromLaravelJson(Map<String, dynamic>.from(m)))
        .toList();

    final rawSubs = data['submissions'] as List? ?? const [];
    final submissions = rawSubs
        .whereType<Map>()
        .map((m) => AssignmentSubmission.fromLaravelJson(Map<String, dynamic>.from(m)))
        .toList();

    return StudentAssignmentsData(
      tasks: tasks,
      submissions: submissions,
    );
  }

  /// التكليفات التي لم يقم الطالب بتسليمها بعد
  List<Assignment> get pendingTasks {
    final submittedTaskIds = submissions.map((s) => s.assignmentId).toSet();
    return tasks.where((t) => !submittedTaskIds.contains(t.id)).toList();
  }

  /// التسليمات المعتمدة والمرصودة
  List<AssignmentSubmission> get gradedSubmissions {
    return submissions.where((s) => s.isGraded && s.score != null).toList();
  }

  /// متوسط درجات التكليفات المعتمدة
  int? get averageScore {
    final graded = gradedSubmissions;
    if (graded.isEmpty) return null;
    final total = graded.map((s) => s.score!).reduce((a, b) => a + b);
    return (total / graded.length).round();
  }

  int get pendingCount => pendingTasks.length;
  int get submittedCount => submissions.length;

  @override
  List<Object?> get props => [tasks, submissions];
}

/// تفاصيل مهمة سريرية مع أحدث تسليم لها من GET /student/assignments/{task}
class ClinicalTaskDetails extends Equatable {
  final Assignment task;
  final AssignmentSubmission? submission;

  const ClinicalTaskDetails({
    required this.task,
    this.submission,
  });

  factory ClinicalTaskDetails.fromJson(Map<String, dynamic> rawJson) {
    final data = (rawJson['data'] is Map)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    final taskMap = data['task'] is Map
        ? Map<String, dynamic>.from(data['task'] as Map)
        : data;
    final task = Assignment.fromLaravelJson(taskMap);

    AssignmentSubmission? sub;
    if (data['submission'] is Map) {
      sub = AssignmentSubmission.fromLaravelJson(
        Map<String, dynamic>.from(data['submission'] as Map),
      );
    }

    return ClinicalTaskDetails(task: task, submission: sub);
  }

  @override
  List<Object?> get props => [task, submission];
}

/// إحصائيات تقييمات الطالب من GET /student/grades
class StudentGradesStats extends Equatable {
  final int totalSubmissions;
  final int gradedCount;
  final int pendingCount;
  final int passedCount;
  final double averageScore;

  const StudentGradesStats({
    this.totalSubmissions = 0,
    this.gradedCount = 0,
    this.pendingCount = 0,
    this.passedCount = 0,
    this.averageScore = 0.0,
  });

  factory StudentGradesStats.fromJson(Map<String, dynamic> json) {
    return StudentGradesStats(
      totalSubmissions: (json['total_submissions'] is num)
          ? (json['total_submissions'] as num).toInt()
          : 0,
      gradedCount: (json['graded_count'] is num)
          ? (json['graded_count'] as num).toInt()
          : 0,
      pendingCount: (json['pending_count'] is num)
          ? (json['pending_count'] as num).toInt()
          : 0,
      passedCount: (json['passed_count'] is num)
          ? (json['passed_count'] as num).toInt()
          : 0,
      averageScore: (json['average_score'] is num)
          ? (json['average_score'] as num).toDouble()
          : 0.0,
    );
  }

  @override
  List<Object?> get props => [
        totalSubmissions,
        gradedCount,
        pendingCount,
        passedCount,
        averageScore,
      ];
}

/// ملخص درجات الطالب وتسليماته من GET /student/grades
class StudentGradesData extends Equatable {
  final StudentGradesStats stats;
  final List<AssignmentSubmission> submissions;

  const StudentGradesData({
    this.stats = const StudentGradesStats(),
    this.submissions = const [],
  });

  factory StudentGradesData.fromJson(Map<String, dynamic> rawJson) {
    final data = (rawJson['data'] is Map)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    final statsMap = data['stats'] is Map
        ? Map<String, dynamic>.from(data['stats'] as Map)
        : const <String, dynamic>{};
    final stats = StudentGradesStats.fromJson(statsMap);

    final rawSubs = data['submissions'] as List? ?? const [];
    final submissions = rawSubs
        .whereType<Map>()
        .map((m) => AssignmentSubmission.fromLaravelJson(Map<String, dynamic>.from(m)))
        .toList();

    return StudentGradesData(stats: stats, submissions: submissions);
  }

  @override
  List<Object?> get props => [stats, submissions];
}
