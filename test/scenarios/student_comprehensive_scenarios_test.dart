import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/screens/student/course_details/widgets/course_enrollment_status_card.dart';
import 'package:secure_screen_app/screens/student/home/widgets/course_search_filter_bar.dart';
import 'package:secure_screen_app/screens/student/home/widgets/student_course_card.dart';
import 'package:secure_screen_app/screens/student/home/widgets/student_welcome_banner.dart';
import 'package:secure_screen_app/screens/student/profile/widgets/student_profile_header_card.dart';
import 'package:secure_screen_app/screens/student/profile/widgets/student_stats_grid.dart';
import 'package:secure_screen_app/screens/student/video_player/widgets/video_watermark_overlay.dart';
import '../test_localization_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestLocalization();
  });
  group('Student Scenario Suite 1: Home Catalog, Welcome Banner & Search Filter', () {
    testWidgets('Scenario 1.1: StudentWelcomeBanner displays total courses and enrolled count', (tester) async {
      await tester.pumpWidget(
        testAppWrapper(
          child: const StudentWelcomeBanner(
            totalCourses: 14,
            enrolledCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StudentWelcomeBanner), findsOneWidget);
      expect(find.text('14 دورة متاحة'), findsOneWidget);
      expect(find.text('3 مشترك بها'), findsOneWidget);
      expect(find.text('مركز الأمين للتخاطب'), findsOneWidget);

      expect(find.text('14 دورة متاحة'), findsOneWidget);
      expect(find.text('3 مشترك بها'), findsOneWidget);
      expect(find.text('مركز الأمين للتخاطب'), findsOneWidget);
    });

    testWidgets('Scenario 1.2: CourseSearchFilterBar filters by category query and triggers callback', (tester) async {
      String searchQuery = '';
      String selectedCategory = 'الكل';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseSearchFilterBar(
                selectedCategory: selectedCategory,
                categories: const ['الكل', 'تخاطب', 'صوت', 'توحد', 'سمعيات'],
                onSearchChanged: (q) => searchQuery = q,
                onCategorySelected: (cat) => selectedCategory = cat,
              ),
            ),
          ),
        ),
      );

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('تخاطب'), findsOneWidget);
      expect(find.text('صوت'), findsOneWidget);
      expect(find.text('توحد'), findsOneWidget);

      // Tap 'توحد'
      await tester.tap(find.text('توحد'));
      await tester.pump();
      expect(selectedCategory, equals('توحد'));

      // Enter search text
      await tester.enterText(find.byType(TextField), 'علاج التلعثم');
      expect(searchQuery, equals('علاج التلعثم'));
    });

    testWidgets('Scenario 1.3: StudentCourseCard baseline alignment without ellipsis and enrolled badge', (tester) async {
      final sampleCourse = Course(
        id: 'c_course_01',
        title: 'دورة تأهيل النطق والتخاطب المتقدمة للأطفال وضعاف السمع بمحافظات الصعيد',
        description: 'شرح متكامل وشامل لتمارين التخاطب السريرية',
        instructor: 'د. سمير الأمين',
        category: 'تخاطب',
        price: 650,
        thumbnailUrl: '',
        levels: [
          CourseLevel(
            id: 'lvl_1',
            title: 'المستوى الأول',
            description: '',
            order: 1,
            lessons: [
              Lesson(
                id: 'l_1',
                title: 'مقدمة في أعضاء النطق',
                description: '',
                duration: '20:00',
                muxPlaybackId: 'mux_play_123',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: StudentCourseCard(
                  course: sampleCourse,
                  isEnrolled: true,
                  progress: 0.65,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify course title wraps cleanly without clipping
      expect(find.text(sampleCourse.title), findsOneWidget);
      expect(find.text('د. سمير الأمين'), findsOneWidget);
      expect(find.text('مشترك ومفعّل'), findsOneWidget);
    });
  });

  group('Student Scenario Suite 2: Course Details & Enrollment Status Card', () {
    final sampleCourse = Course(
      id: 'c_course_02',
      title: 'كورس علاج التلعثم واللجلجة الشامل',
      description: 'برنامج علاجي متكامل للتغلب على التلعثم عند الأطفال والبالغين',
      instructor: 'د. هند النجار',
      category: 'تلعثم',
      price: 800,
      thumbnailUrl: '',
      levels: [
        CourseLevel(
          id: 'lvl_1',
          title: 'المستوى الأول: التشخيص والتقييم',
          description: '',
          order: 1,
          lessons: [
            Lesson(
              id: 'l_1',
              title: 'مقياس شدة التلعثم SSI-4',
              description: '',
              duration: '35:00',
              muxPlaybackId: 'mux_ssi',
            ),
          ],
        ),
      ],
    );

    testWidgets('Scenario 2.1: CourseEnrollmentStatusCard renders enrolled state with action button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseEnrollmentStatusCard(
                course: sampleCourse,
                isEnrolled: true,
                progress: 0.8,
                completedLessonsCount: 4,
                accessRequest: null,
                isSubmittingRequest: false,
                onRequestAccess: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('تقدمك في هذه الدورة'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('Scenario 2.2: CourseEnrollmentStatusCard renders un-enrolled state with request access button', (tester) async {
      bool requestTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseEnrollmentStatusCard(
                course: sampleCourse,
                isEnrolled: false,
                progress: 0.0,
                completedLessonsCount: 0,
                accessRequest: null,
                isSubmittingRequest: false,
                onRequestAccess: () => requestTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('طلب الاشتراك وإرفاق إيصال السداد'), findsOneWidget);
      await tester.tap(find.text('طلب الاشتراك وإرفاق إيصال السداد'));
      expect(requestTapped, isTrue);
    });
  });

  group('Student Scenario Suite 3: Security & Video Watermark Overlay', () {
    testWidgets('Scenario 3.1: VideoWatermarkOverlay displays masked student identification tag cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SizedBox(width: 400, height: 250),
                VideoWatermarkOverlay(
                  alignment: Alignment.center,
                  studentName: 'محمود عبد السلام',
                  studentEmail: 'mahmoud@gmail.com',
                  studentUid: 'std_9921',
                  studentIp: '197.34.56.78',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VideoWatermarkOverlay), findsOneWidget);
      expect(find.textContaining('محمود عبد السلام'), findsWidgets);
      expect(find.textContaining('197.34.56.78'), findsWidgets);
    });
  });

  group('Student Scenario Suite 4: Student Profile Hub & Stats Grid', () {
    testWidgets('Scenario 4.1: StudentProfileHeaderCard renders student name, email, phone and edit button', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: StudentProfileHeaderCard(
                  displayName: 'عمر خالد الألفي',
                  email: 'omar.alfy@example.com',
                  phone: '01234567890',
                  avatarUrl: '',
                  onEditTap: () => editTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('عمر خالد الألفي'), findsOneWidget);
      expect(find.text('omar.alfy@example.com'), findsOneWidget);
      expect(find.text('01234567890'), findsOneWidget);
      expect(find.text('تعديل بياناتي'), findsOneWidget);

      await tester.tap(find.text('تعديل بياناتي'));
      expect(editTapped, isTrue);
    });

    testWidgets('Scenario 4.2: StudentStatsGrid displays watch time, completed lessons, and enrolled courses', (tester) async {
      await tester.pumpWidget(
        testAppWrapper(
          wrapInScaffold: false,
          child: const Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: StudentStatsGrid(
                enrolledCount: 3,
                completedLessonsCount: 8,
                watchTimeFormatted: '4 ساعات و15 دقيقة',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('دورات مشترك بها'), findsOneWidget);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('محاضرة مكتملة'), findsOneWidget);

      expect(find.text('4 ساعات و15 دقيقة'), findsOneWidget);
      expect(find.text('وقت التعلم المسجل'), findsOneWidget);
    });
  });
}
