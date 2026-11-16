import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/access_request.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/course_level.dart';
import 'package:secure_admin_app/models/lesson.dart';
import 'package:secure_admin_app/models/registered_student.dart';
import 'package:secure_admin_app/services/auth_service.dart';

void main() {
  group('1. AdminAuthService Tests', () {
    test('Invalid or empty emails are rejected by AdminAuthService', () async {
      final authService = AdminAuthService();
      expect(await authService.isAuthorizedAdmin(null), isFalse);
      expect(await authService.isAuthorizedAdmin(''), isFalse);
      expect(await authService.isAuthorizedAdmin('   '), isFalse);
    });
  });

  group('2. Course, Level & Lesson Model Lifecycle Tests', () {
    test('Course creation with levels and lessons parses correctly', () {
      const lesson1 = Lesson(
        id: 'l1',
        title: 'مقدمة فلاتر',
        description: 'شرح تمهيدي',
        duration: '10:00 دقيقة',
        muxPlaybackId: 'mux_play_1',
        order: 1,
        isFreePreview: true,
      );

      const lesson2 = Lesson(
        id: 'l2',
        title: 'بناء الواجهات',
        description: 'شرح Widgets',
        duration: '15:00 دقيقة',
        muxPlaybackId: 'mux_play_2',
        order: 2,
        isFreePreview: false,
      );

      const level1 = CourseLevel(
        id: 'lvl_1',
        title: 'المستوى الأول',
        description: 'أساسيات',
        order: 1,
        lessons: [lesson1, lesson2],
      );

      const course = Course(
        id: 'c_test_1',
        title: 'دورة فلاتر المتقدمة',
        description: 'شرح عملي',
        instructor: 'الأمين سنتر (Elameen Center)',
        category: 'برمجة',
        thumbnailUrl: '',
        price: 450.0,
        enrolledCount: 5,
        levels: [level1],
      );

      expect(course.totalLessonsCount, 2);
      expect(course.allLessonIds, ['l1', 'l2']);
      expect(level1.totalLessons, 2);
      expect(course.price, 450.0);
      expect(course.priceFormatted, '450 ج.م');

      // اختبار التحويل لـ Map والعودة من Map (Serialization/Deserialization)
      final map = course.toMap();
      expect(map['price'], 450.0);
      final reconstructed = Course.fromMap(map);

      expect(reconstructed.id, 'c_test_1');
      expect(reconstructed.title, 'دورة فلاتر المتقدمة');
      expect(reconstructed.price, 450.0);
      expect(reconstructed.priceFormatted, '450 ج.م');
      expect(reconstructed.levels.length, 1);
      expect(reconstructed.levels.first.lessons.length, 2);
      expect(reconstructed.levels.first.lessons.first.isFreePreview, isTrue);
      expect(reconstructed.levels.first.lessons.last.isFreePreview, isFalse);
      expect(reconstructed.levels.first.lessons.first.muxPlaybackId, 'mux_play_1');
    });

    test('Course price formatting handles free and fractional prices correctly', () {
      const freeCourse = Course(
        id: 'free_1',
        title: 'كورس مجاني',
        description: '',
        instructor: '',
        category: '',
        thumbnailUrl: '',
        price: 0,
        levels: [],
      );
      expect(freeCourse.priceFormatted, 'مجاني');

      final paidCourse = freeCourse.copyWith(price: 350.5);
      expect(paidCourse.price, 350.5);
      expect(paidCourse.priceFormatted, '350.50 ج.م');

      final integerPriceCourse = freeCourse.copyWith(price: 500.0);
      expect(integerPriceCourse.priceFormatted, '500 ج.م');
    });

    test('Adding and deleting levels updates course integrity', () {
      const initialLevel = CourseLevel(
        id: 'lvl_1',
        title: 'المستوى 1',
        description: '',
        order: 1,
        lessons: [],
      );

      var course = const Course(
        id: 'c1',
        title: 'Test',
        description: '',
        instructor: 'Elameen',
        category: 'Tech',
        thumbnailUrl: '',
        levels: [initialLevel],
      );

      expect(course.levels.length, 1);

      // إضافة مستوى 2
      const level2 = CourseLevel(
        id: 'lvl_2',
        title: 'المستوى 2',
        description: '',
        order: 2,
        lessons: [],
      );

      final updatedLevels = List<CourseLevel>.from(course.levels)..add(level2);
      course = course.copyWith(levels: updatedLevels);

      expect(course.levels.length, 2);
      expect(course.levels[1].id, 'lvl_2');

      // حذف المستوى 1
      final filteredLevels = course.levels.where((l) => l.id != 'lvl_1').toList();
      course = course.copyWith(levels: filteredLevels);

      expect(course.levels.length, 1);
      expect(course.levels.first.id, 'lvl_2');
    });

    test('Adding and deleting lessons updates level counts correctly', () {
      var level = const CourseLevel(
        id: 'lvl_1',
        title: 'المستوى 1',
        description: '',
        order: 1,
        lessons: [],
      );

      const les1 = Lesson(
        id: 'les_1',
        title: 'الدرس الأول',
        description: '',
        duration: '10:00',
        muxPlaybackId: 'mux_1',
      );

      const les2 = Lesson(
        id: 'les_2',
        title: 'الدرس الثاني',
        description: '',
        duration: '12:00',
        muxPlaybackId: 'mux_2',
      );

      // إضافة درسين
      level = level.copyWith(lessons: [les1, les2]);
      expect(level.lessons.length, 2);
      expect(level.totalLessons, 2);

      // حذف الدرس الأول
      final remainingLessons = level.lessons.where((l) => l.id != 'les_1').toList();
      level = level.copyWith(lessons: remainingLessons);

      expect(level.lessons.length, 1);
      expect(level.lessons.first.id, 'les_2');
    });
  });

  group('3. RegisteredStudent & AccessRequest Tests', () {
    test('RegisteredStudent course enrollment and watch time formatting', () {
      final student = RegisteredStudent(
        id: 'std_100',
        name: 'عبدالرحمن',
        email: 'abdo@gmail.com',
        avatarUrl: '',
        joinedAt: DateTime(2026, 1, 1),
        enrolledCourseIds: ['c1'],
        completedLessonIds: {'l1', 'l2'},
        totalWatchSeconds: 3660, // 1 hour and 1 minute
      );

      expect(student.isEnrolled('c1'), isTrue);
      expect(student.isEnrolled('c2'), isFalse);
      expect(student.isLessonCompleted('l1'), isTrue);
      expect(student.isLessonCompleted('l3'), isFalse);
      expect(student.watchTimeFormatted, '1 س و 1 د');

      student.grantAccess('c2');
      expect(student.isEnrolled('c2'), isTrue);

      student.revokeAccess('c1');
      expect(student.isEnrolled('c1'), isFalse);
    });

    test('CourseAccessRequest parsing and status verification', () {
      final req = CourseAccessRequest(
        id: 'req_1',
        studentId: 'std_1',
        studentName: 'محمد',
        studentEmail: 'mohamed@gmail.com',
        courseId: 'c1',
        courseTitle: 'فلاتر',
        requestedAt: DateTime.now(),
        status: AccessStatus.pending,
      );

      expect(req.status, AccessStatus.pending);

      final json = req.toJson();
      expect(json['status'], 'pending');

      final parsed = CourseAccessRequest.fromJson(json);
      expect(parsed.id, 'req_1');
      expect(parsed.studentName, 'محمد');
      expect(parsed.status, AccessStatus.pending);
    });
  });
}
