import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/network/auth_interceptor.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';

class InMemoryTokenStorage implements SecureTokenStorage {
  String? _token;
  Map<String, dynamic>? _user;

  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> getToken() async => _token;
  @override
  Future<void> deleteToken() async => _token = null;
  @override
  Future<bool> hasToken() async => _token != null && _token!.isNotEmpty;
  @override
  Future<void> saveUserData(Map<String, dynamic> user) async => _user = user;
  @override
  Future<Map<String, dynamic>?> getUserData() async => _user;
  @override
  Future<void> deleteUserData() async => _user = null;
  @override
  Future<void> clearAll() async {
    _token = null;
    _user = null;
  }
}

class MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) _handler;
  MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late ApiClient apiClient;
  late CoursesRemoteDataSource coursesRemoteDataSource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://api.elameen.test/api/v1'));
    apiClient = ApiClient(
      dio: dio,
      authInterceptor: AuthInterceptor(tokenStorage: InMemoryTokenStorage()),
    );
    coursesRemoteDataSource = CoursesRemoteDataSourceImpl(apiClient: apiClient);
  });

  ResponseBody jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  group('CoursesRemoteDataSource Contract Tests (P3)', () {
    test('getPublicCourses() sends GET /public/courses and parses course list correctly', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/public/courses'));
        expect(options.method, equals('GET'));
        return jsonResponse({
          'success': true,
          'data': {
            'courses': [
              {
                'id': 1,
                'slug': 'comprehensive-speech-therapy-diploma',
                'title': 'الدبلوم السريري الشامل في أمراض التخاطب والنطق',
                'price': 1500,
                'currency_symbol': 'ج.م',
                'currency_name': 'جنيه مصري',
                'access_duration_days': 365,
                'thumbnail': '/assets/images/course-1.png',
                'videos_count': 24,
                'is_published': true,
              },
              {
                'id': 2,
                'slug': 'articulation-disorders-mastery',
                'title': 'ماستري عيوب النطق ومخارج الحروف',
                'price': 800,
                'currency_symbol': 'ج.م',
                'videos_count': 12,
                'is_published': true,
              }
            ]
          }
        });
      });

      final courses = await coursesRemoteDataSource.getPublicCourses();
      expect(courses.length, equals(2));
      expect(courses[0].id, equals('1'));
      expect(courses[0].slug, equals('comprehensive-speech-therapy-diploma'));
      expect(courses[0].title, contains('الدبلوم السريري الشامل'));
      expect(courses[0].price, equals(1500.0));
      expect(courses[0].totalLessonsCount, equals(24));
      expect(courses[1].price, equals(800.0));
    });

    test('getPublicCourses(search) passes search query parameter', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/public/courses'));
        expect(options.queryParameters['search'], equals('تخاطب'));
        return jsonResponse({
          'success': true,
          'data': {
            'courses': [
              {
                'id': 1,
                'slug': 'comprehensive-speech-therapy-diploma',
                'title': 'الدبلوم السريري الشامل',
                'price': 1500,
              }
            ]
          }
        });
      });

      final courses = await coursesRemoteDataSource.getPublicCourses(search: 'تخاطب');
      expect(courses.length, equals(1));
      expect(courses.first.title, contains('الدبلوم السريري'));
    });

    test('getPublicCourseBySlug() sends GET /public/courses/{slug} and parses levels & lessons', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/public/courses/speech-diploma'));
        return jsonResponse({
          'success': true,
          'data': {
            'course': {
              'id': 10,
              'slug': 'speech-diploma',
              'title': 'دبلوم التخاطب العملي',
              'price': 2000,
              'videos_count': 10,
            },
            'has_enrolled': false,
            'total_videos': 10,
            'levels': [
              {
                'id': 101,
                'title': 'المستوى الأول: التشخيص التخاطبي',
                'sort_order': 1,
                'videos': [
                  {
                    'id': 1001,
                    'slug': 'lesson-1',
                    'title': 'المقابلة الإكلينيكية الأولى',
                    'duration_minutes': 35,
                    'duration_seconds': 2100,
                    'is_free_preview': true,
                    'sort_order': 1,
                  },
                  {
                    'id': 1002,
                    'slug': 'lesson-2',
                    'title': 'تطبيق اختبار النطق المصور',
                    'duration_minutes': 45,
                    'duration_seconds': 2700,
                    'is_free_preview': false,
                    'sort_order': 2,
                  }
                ]
              }
            ]
          }
        });
      });

      final course = await coursesRemoteDataSource.getPublicCourseBySlug('speech-diploma');
      expect(course.id, equals('10'));
      expect(course.title, equals('دبلوم التخاطب العملي'));
      expect(course.levels.length, equals(1));
      expect(course.levels.first.title, contains('المستوى الأول'));
      expect(course.levels.first.lessons.length, equals(2));
      expect(course.levels.first.lessons.first.isFreePreview, isTrue);
      expect(course.levels.first.lessons.first.duration, contains('35 دقيقة'));
      expect(course.levels.first.lessons.last.isFreePreview, isFalse);
    });

    test('getPublicCourseBySlug() throws ApiException on 404', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return jsonResponse({
          'success': false,
          'message': 'المورد المطلوب غير موجود.',
        }, statusCode: 404);
      });

      await expectLater(
        () => coursesRemoteDataSource.getPublicCourseBySlug('non-existent'),
        throwsA(isA<ApiException>()),
      );
    });

    test('getStudentDashboard() sends GET /student/dashboard and parses stats and resume', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/student/dashboard'));
        return jsonResponse({
          'success': true,
          'data': {
            'enrolled_courses': [
              {
                'id': 1,
                'slug': 'course-1',
                'title': 'دورة التخاطب الشاملة',
                'price': 1500,
              }
            ],
            'pending_courses': [],
            'available_courses': [],
            'total_watched_videos': 12,
            'total_watch_seconds': 18000,
            'total_watch_hours': 5.0,
            'average_progress': 65,
            'resume_course': {
              'id': 1,
              'slug': 'course-1',
              'title': 'دورة التخاطب الشاملة',
            },
            'resume_video': {
              'id': 105,
              'slug': 'stuttering-therapy-intro',
              'title': 'مدخل لعلاج التلعثم والتأتأة',
              'duration_minutes': 25,
            }
          }
        });
      });

      final dashboard = await coursesRemoteDataSource.getStudentDashboard();
      expect(dashboard.enrolledCourses.length, equals(1));
      expect(dashboard.totalWatchedVideos, equals(12));
      expect(dashboard.totalWatchHours, equals(5.0));
      expect(dashboard.averageProgress, equals(65));
      expect(dashboard.resumeCourse?.title, contains('دورة التخاطب'));
      expect(dashboard.resumeVideo?.title, contains('علاج التلعثم'));
    });

    test('getStudentCourses() sends GET /student/courses and parses stats & enrolled courses', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/student/courses'));
        return jsonResponse({
          'success': true,
          'data': {
            'stats': {
              'enrolled_count': 3,
              'completed_count': 1,
              'in_progress_count': 2,
              'certificates_count': 1,
            },
            'enrolled_course_ids': [1, 2, 3],
            'enrolled_courses': [
              {
                'course': {
                  'id': 1,
                  'slug': 'course-1',
                  'title': 'الدبلوم السريري',
                  'videos_count': 20,
                },
                'progress': {
                  'completed_count': 10,
                  'total_count': 20,
                  'percentage': 50,
                  'last_watched_at': '2026-11-17T10:00:00Z',
                }
              }
            ]
          }
        });
      });

      final studentCourses = await coursesRemoteDataSource.getStudentCourses();
      expect(studentCourses.enrolledCount, equals(3));
      expect(studentCourses.completedCount, equals(1));
      expect(studentCourses.inProgressCount, equals(2));
      expect(studentCourses.certificatesCount, equals(1));
      expect(studentCourses.enrolledCourseIds, equals([1, 2, 3]));
      expect(studentCourses.enrolledCourses.length, equals(1));
      expect(studentCourses.enrolledCourses.first.percentage, equals(50));
      expect(studentCourses.enrolledCourses.first.completedCount, equals(10));
    });

    test('getBootstrapConfig() sends GET /public/bootstrap and parses platform configuration', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/public/bootstrap'));
        return jsonResponse({
          'success': true,
          'data': {
            'branding': {
              'site_name': 'أكاديمية الأمين للتخاطب السريري',
              'site_tagline': 'المنصة الأولى المعتمدة في الشرق الأوسط',
              'logo_url': 'http://example.com/logo.png',
            },
            'currency': {
              'symbol': 'ج.م',
              'name': 'جنيه مصري',
            },
            'features': {
              'student_dashboard': true,
              'courses': true,
            }
          }
        });
      });

      final bootstrap = await coursesRemoteDataSource.getBootstrapConfig();
      expect(bootstrap.siteName, equals('أكاديمية الأمين للتخاطب السريري'));
      expect(bootstrap.currencySymbol, equals('ج.م'));
      expect(bootstrap.features['student_dashboard'], isTrue);
    });

    test('getContactInfo() sends GET /public/contact and parses channels correctly', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/public/contact'));
        return jsonResponse({
          'success': true,
          'data': {
            'email': 'support@alameen.com',
            'phone': '+201012345678',
            'whatsapp': 'https://wa.me/201012345678',
            'address': 'القاهرة، جمهورية مصر العربية',
          }
        });
      });

      final contact = await coursesRemoteDataSource.getContactInfo();
      expect(contact.email, equals('support@alameen.com'));
      expect(contact.phone, equals('+201012345678'));
      expect(contact.whatsapp, contains('wa.me'));
    });
  });
}
