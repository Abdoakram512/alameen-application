import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/bootstrap_data.dart';
import '../models/contact_info_data.dart';
import '../models/course.dart';
import '../models/student_courses_data.dart';
import '../models/student_dashboard_data.dart';

/// Contract for courses and public content remote communication with Laravel REST API.
abstract class CoursesRemoteDataSource {
  /// Fetch all published courses from the public catalog.
  Future<List<Course>> getPublicCourses({String? search});

  /// Fetch public course details and curriculum structure by slug or ID.
  Future<Course> getPublicCourseBySlug(String slug);

  /// Fetch student learning dashboard data (enrolled, pending, stats, resume learning).
  Future<StudentDashboardData> getStudentDashboard();

  /// Fetch student enrolled courses list and progress breakdown.
  Future<StudentCoursesData> getStudentCourses();

  /// Fetch student-specific course details with progress and access permissions.
  Future<Course> getStudentCourseBySlug(String slug);

  /// Fetch platform bootstrap configuration (branding, currency, features).
  Future<BootstrapData> getBootstrapConfig();

  /// Fetch landing page CMS data.
  Future<Map<String, dynamic>> getLandingPageData();

  /// Fetch official contact and support channels.
  Future<ContactInfoData> getContactInfo();
}

/// Implementation of [CoursesRemoteDataSource] using [ApiClient].
class CoursesRemoteDataSourceImpl implements CoursesRemoteDataSource {
  final ApiClient _apiClient;

  CoursesRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<Course>> getPublicCourses({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        '/public/courses',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        final innerData = data['data'];
        final coursesList = (innerData is Map && innerData['courses'] is List)
            ? innerData['courses'] as List
            : (innerData is List ? innerData : <dynamic>[]);

        return coursesList
            .map((c) => Course.fromLaravelSummaryJson(Map<String, dynamic>.from(c as Map)))
            .toList();
      }

      return const [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<Course> getPublicCourseBySlug(String slug) async {
    try {
      final response = await _apiClient.get('/public/courses/$slug');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] != null) {
        final courseMap = Map<String, dynamic>.from(data['data'] as Map);
        return Course.fromLaravelDetailsJson(courseMap);
      }

      throw const ApiException(
        'الدورة التعليمية المطلوبة غير موجودة أو غير منشورة.',
        statusCode: 404,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<StudentDashboardData> getStudentDashboard() async {
    try {
      final response = await _apiClient.get('/student/dashboard');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] is Map) {
        return StudentDashboardData.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }

      return const StudentDashboardData(enrolledCourses: []);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<StudentCoursesData> getStudentCourses() async {
    try {
      final response = await _apiClient.get('/student/courses');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] is Map) {
        return StudentCoursesData.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }

      return const StudentCoursesData();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<Course> getStudentCourseBySlug(String slug) async {
    try {
      final response = await _apiClient.get('/student/courses/$slug');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] != null) {
        final courseMap = Map<String, dynamic>.from(data['data'] as Map);
        return Course.fromLaravelDetailsJson(courseMap);
      }

      throw const ApiException(
        'الدورة التعليمية المطلوبة غير متوفرة لحسابك حالياً.',
        statusCode: 404,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<BootstrapData> getBootstrapConfig() async {
    try {
      final response = await _apiClient.get('/public/bootstrap');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] is Map) {
        return BootstrapData.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }

      return const BootstrapData(
        siteName: 'أكاديمية الأمين للتخاطب السريري',
        siteTagline: '',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getLandingPageData() async {
    try {
      final response = await _apiClient.get('/public/home');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }

      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<ContactInfoData> getContactInfo() async {
    try {
      final response = await _apiClient.get('/public/contact');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] is Map) {
        return ContactInfoData.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }

      return const ContactInfoData();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
