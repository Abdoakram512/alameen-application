import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/registered_student.dart';
import 'package:secure_admin_app/models/watch_log_entry.dart';
import 'package:secure_admin_app/screens/dashboard/tabs/analytics_widgets/admin_analytics_painters.dart';
import 'package:secure_admin_app/services/student_provisioning_service.dart';

void main() {
  group('Admin Provisioning & Analytics Studio Tests', () {
    test('generateStrongPassword builds non-ambiguous strong credentials', () {
      for (var i = 0; i < 10; i++) {
        final pwd = StudentProvisioningService.generateStrongPassword(
          length: 10,
        );
        expect(pwd.length, equals(10));
        expect(RegExp(r'[A-Z]').hasMatch(pwd), isTrue);
        expect(RegExp(r'[a-z]').hasMatch(pwd), isTrue);
        expect(RegExp(r'[2-9]').hasMatch(pwd), isTrue);
      }
    });

    test(
      'AdminAnalyticsCalculator computes active enrollments revenue & donut distribution',
      () {
        const courses = [
          Course(
            id: 'c1',
            title: 'تأهيل التخاطب الشامل',
            description: 'وصف',
            instructor: 'د. أحمد',
            category: 'تخاطب',
            thumbnailUrl: '',
            levels: [],
            price: 1200,
          ),
          Course(
            id: 'c2',
            title: 'تنمية المهارات اللغوية',
            description: 'وصف',
            instructor: 'د. منى',
            category: 'مهارات',
            thumbnailUrl: '',
            levels: [],
            price: 800,
          ),
        ];

        final students = [
          RegisteredStudent(
            id: 'u1',
            name: 'سارة علي',
            email: 'sara@example.com',
            joinedAt: DateTime(2026, 5, 1),
            enrolledCourseIds: ['c1', 'c2'],
            completedLessonIds: {'l1', 'l2'},
            totalWatchSeconds: 3600,
          ),
          RegisteredStudent(
            id: 'u2',
            name: 'محمد حسن',
            email: 'mohamed@example.com',
            joinedAt: DateTime(2026, 5, 2),
            enrolledCourseIds: ['c1'],
            completedLessonIds: {'l1'},
            totalWatchSeconds: 1800,
          ),
        ];

        final revenue =
            AdminAnalyticsCalculator.calculateActiveEnrollmentsValue(
              courses: courses,
              students: students,
            );
        expect(revenue, equals(3200.0)); // (1200 + 800) + 1200

        final segments =
            AdminAnalyticsCalculator.buildCourseEnrollmentDistribution(
              courses: courses,
              students: students,
            );
        expect(segments.length, equals(2));
        expect(segments.first.label, equals('تأهيل التخاطب الشامل'));
        expect(segments.first.value, equals(2.0));
      },
    );

    testWidgets(
      'AdminTrendAreaPainter, DistributionDonutPainter, and StudentMasteryRingPainter render cleanly',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 300,
                    height: 130,
                    child: CustomPaint(
                      painter: AdminTrendAreaPainter(
                        values: [12, 25, 0, 40, 32, 50, 65],
                        highlightedIndex: 6,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: DistributionDonutPainter(
                        segments: [
                          DonutSegmentData(
                            label: 'دورة 1',
                            value: 10,
                            colorHex: 0xFF012383,
                          ),
                          DonutSegmentData(
                            label: 'دورة 2',
                            value: 5,
                            colorHex: 0xFF10B981,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: StudentMasteryRingPainter(progress: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
