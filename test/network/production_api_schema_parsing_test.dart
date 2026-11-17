import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/config/app_config.dart';
import 'package:secure_screen_app/models/bootstrap_data.dart';
import 'package:secure_screen_app/models/contact_info_data.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/student_dashboard_data.dart';

void main() {
  group('P3 OpenAPI Schema Parsing and Media URL Resolution Tests', () {
    test('AppConfig resolves default production URL and origin correctly', () {
      expect(AppConfig.apiBaseUrl, equals('https://alameen.edu.sa/api/v1'));
      expect(AppConfig.baseOrigin, equals('https://alameen.edu.sa'));

      // Relative path resolution
      final resolved = AppConfig.resolveMediaUrl('/assets/images/course-topic-basics.png');
      expect(resolved, equals('https://alameen.edu.sa/assets/images/course-topic-basics.png'));

      // Absolute path unchanged
      final absolute = AppConfig.resolveMediaUrl('https://cdn.example.com/images/thumb.jpg');
      expect(absolute, equals('https://cdn.example.com/images/thumb.jpg'));

      // Empty or null returns empty string without crashing
      expect(AppConfig.resolveMediaUrl(null), equals(''));
      expect(AppConfig.resolveMediaUrl('   '), equals(''));
    });

    test('Course.fromLaravelSummaryJson correctly parses OpenAPI CourseSummary and resolves media', () {
      final summaryJson = {
        'id': 1,
        'slug': 'comprehensive-speech-therapy-diploma',
        'title': 'الدبلوم السريري الشامل في أمراض التخاطب والنطق',
        'description': 'دبلوم تدريبي عملي معتمد.',
        'price': 1500,
        'original_price': 2200,
        'currency_symbol': 'ج.م',
        'currency_name': 'جنيه مصري',
        'access_duration_days': 365,
        'thumbnail': '/assets/images/course-topic-basics.png',
        'promo_video_source': 'youtube',
        'videos_count': 24,
        'is_published': true,
      };

      final course = Course.fromLaravelSummaryJson(summaryJson);

      expect(course.id, equals('1'));
      expect(course.slug, equals('comprehensive-speech-therapy-diploma'));
      expect(course.title, contains('الدبلوم السريري الشامل'));
      expect(course.price, equals(1500.0));
      expect(course.originalPrice, equals(2200.0));
      expect(course.currencySymbol, equals('ج.م'));
      expect(course.validityDays, equals(365));
      expect(course.videosCount, equals(24));
      // Media URL must not be relative and must not contain localhost
      expect(course.thumbnailUrl, equals('https://alameen.edu.sa/assets/images/course-topic-basics.png'));
      expect(course.thumbnailUrl, isNot(contains('localhost')));
      expect(course.thumbnailUrl, isNot(contains('127.0.0.1')));
    });

    test('Course.fromLaravelDetailsJson correctly parses OpenAPI CourseDetailsResponse and levels', () {
      final detailsJson = {
        'course': {
          'id': 1,
          'slug': 'comprehensive-speech-therapy-diploma',
          'title': 'الدبلوم السريري الشامل',
          'price': 1500,
          'thumbnail': 'https://cdn.example.com/course-1.png',
        },
        'has_enrolled': true,
        'total_videos': 24,
        'completed_count': 12,
        'progress_percent': 50,
        'levels': [
          {
            'id': 101,
            'course_id': 1,
            'title': 'المستوى الأول: التقييم والتشخيص الإكلينيكي',
            'sort_order': 1,
            'is_published': true,
            'is_accessible': true,
            'videos': [
              {
                'id': 1001,
                'course_id': 1,
                'level_id': 101,
                'title': 'المحاضرة الأولى: دراسة الحالة',
                'video_source': 'bunny',
                'duration_seconds': 1800,
                'is_free_preview': true,
                'is_accessible': true,
                'is_completed': true,
              }
            ],
          }
        ],
      };

      final course = Course.fromLaravelDetailsJson(detailsJson);

      expect(course.id, equals('1'));
      expect(course.levels.length, equals(1));
      expect(course.levels.first.id, equals('101'));
      expect(course.levels.first.lessons.length, equals(1));
      expect(course.levels.first.lessons.first.id, equals('1001'));
      expect(course.levels.first.lessons.first.isCompleted, isTrue);
      expect(course.videosCount, equals(24));
    });

    test('BootstrapData correctly parses OpenAPI /public/bootstrap response and resolves logo', () {
      final bootstrapJson = {
        'branding': {
          'site_name': 'أكاديمية الأمين للتخاطب السريري',
          'site_tagline': 'منصة التميز في التأهيل السريري',
          'logo_url': '/assets/branding/logo.png',
        },
        'currency': {
          'symbol': 'ج.م',
          'name': 'جنيه مصري',
        },
        'theme': {'primary_color': '#0F172A'},
        'features': {'certificates_enabled': true},
        'contact': {'support_email': 'support@alameen.edu.sa'},
      };

      final bootstrap = BootstrapData.fromJson(bootstrapJson);

      expect(bootstrap.siteName, equals('أكاديمية الأمين للتخاطب السريري'));
      expect(bootstrap.currencySymbol, equals('ج.م'));
      expect(bootstrap.logoUrl, equals('https://alameen.edu.sa/assets/branding/logo.png'));
      expect(bootstrap.logoUrl, isNot(contains('localhost')));
    });

    test('ContactInfoData correctly parses OpenAPI /public/contact response', () {
      final contactJson = {
        'email': 'info@alameen.edu.sa',
        'phone': '+966500000000',
        'whatsapp': '+966500000000',
        'address': 'الرياض، المملكة العربية السعودية',
      };

      final contact = ContactInfoData.fromJson(contactJson);

      expect(contact.email, equals('info@alameen.edu.sa'));
      expect(contact.phone, equals('+966500000000'));
      expect(contact.whatsapp, equals('+966500000000'));
      expect(contact.address, contains('الرياض'));
    });

    test('StudentDashboardData correctly parses OpenAPI /student/dashboard response', () {
      final dashboardJson = {
        'enrolled_courses': [
          {
            'id': 1,
            'slug': 'course-1',
            'title': 'كورس 1',
            'price': 1000,
            'thumbnail': '/images/c1.png',
          }
        ],
        'total_watched_videos': 10,
        'total_watch_seconds': 3600,
        'total_watch_hours': 1.0,
        'average_progress': 45,
      };

      final dashboard = StudentDashboardData.fromJson(dashboardJson);

      expect(dashboard.enrolledCourses.length, equals(1));
      expect(dashboard.totalWatchedVideos, equals(10));
      expect(dashboard.totalWatchSeconds, equals(3600));
      expect(dashboard.totalWatchHours, equals(1.0));
      expect(dashboard.averageProgress, equals(45));
    });
  });
}
