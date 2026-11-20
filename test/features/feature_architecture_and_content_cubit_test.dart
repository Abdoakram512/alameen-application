import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/di/injection_container.dart';
import 'package:secure_screen_app/features/features.dart';
import 'package:secure_screen_app/models/bootstrap_data.dart';

class MockStudentContentRepository implements StudentContentRepository {
  final Map<String, String>? aboutUsData;
  final List<Map<String, String>>? faqsData;
  final Map<String, String>? privacyData;
  final bool shouldFail;

  MockStudentContentRepository({
    this.aboutUsData,
    this.faqsData,
    this.privacyData,
    this.shouldFail = false,
  });

  @override
  Future<BootstrapData?> getBootstrapConfig() async => null;

  @override
  Future<Map<String, dynamic>?> getLandingPageData() async => null;

  @override
  Future<Map<String, String>> getAboutUs() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (shouldFail) throw Exception('Network simulated failure');
    return aboutUsData ??
        {
          'title': 'مركز الأمين التجريبي',
          'content': 'محتوى تجريبي عن مركز الأمين.',
        };
  }

  @override
  Future<List<Map<String, String>>> getFaqs() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (shouldFail) throw Exception('Network simulated failure');
    return faqsData ??
        [
          {'question': 'سؤال تجريبي؟', 'answer': 'إجابة تجريبية.'},
        ];
  }

  @override
  Future<Map<String, String>> getPrivacyPolicy() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (shouldFail) throw Exception('Network simulated failure');
    return privacyData ??
        {
          'title': 'سياسة الخصوصية التجريبية',
          'content': 'نص سياسة الخصوصية التجريبي.',
        };
  }

  @override
  Future<ContactInfoData?> getContactInfo() async {
    if (shouldFail) throw Exception('Network simulated failure');
    return null;
  }
}

void main() {
  group('Feature-First Architecture Barrel Verification', () {
    test('All 11 feature modules export properly from features.dart', () {
      expect(StudentLoginScreen, isNotNull);
      expect(StudentRegisterScreen, isNotNull);
      expect(StudentHomeScreen, isNotNull);
      expect(CourseDetailsScreen, isNotNull);
      expect(VideoPlayerScreen, isNotNull);
      expect(RequestAccessSheet, isNotNull);
      expect(StudentAssignmentsScreen, isNotNull);
      expect(StudentCertificatesScreen, isNotNull);
      expect(StudentNotificationsScreen, isNotNull);
      expect(StudentSupportTicketsScreen, isNotNull);
      expect(StudentProfileScreen, isNotNull);
      expect(AboutUsScreen, isNotNull);
      expect(FaqsScreen, isNotNull);
      expect(PrivacyPolicyScreen, isNotNull);
    });
  });

  group('ContentCubit State Machine Tests', () {
    test('loadAboutUs emits [ContentLoading, ContentAboutLoaded] on success',
        () async {
      final repo = MockStudentContentRepository(
        aboutUsData: {'title': 'مركز الأمين', 'content': 'تفاصيل المركز'},
      );
      final cubit = ContentCubit(repository: repo);

      final states = <ContentState>[];
      cubit.stream.listen(states.add);

      await cubit.loadAboutUs();
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<ContentLoading>());
      expect(states[1], isA<ContentAboutLoaded>());
      final loaded = states[1] as ContentAboutLoaded;
      expect(loaded.title, 'مركز الأمين');
      expect(loaded.content, 'تفاصيل المركز');

      await cubit.close();
    });

    test('loadAboutUs emits [ContentLoading, ContentError] on failure',
        () async {
      final repo = MockStudentContentRepository(shouldFail: true);
      final cubit = ContentCubit(repository: repo);

      final states = <ContentState>[];
      cubit.stream.listen(states.add);

      await cubit.loadAboutUs();
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<ContentLoading>());
      expect(states[1], isA<ContentError>());

      await cubit.close();
    });

    test('loadFaqs emits [ContentLoading, ContentFaqsLoaded] on success',
        () async {
      final repo = MockStudentContentRepository(
        faqsData: [
          {'question': 'سؤال 1', 'answer': 'إجابة 1'},
          {'question': 'سؤال 2', 'answer': 'إجابة 2'},
        ],
      );
      final cubit = ContentCubit(repository: repo);

      final states = <ContentState>[];
      cubit.stream.listen(states.add);

      await cubit.loadFaqs();
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<ContentLoading>());
      expect(states[1], isA<ContentFaqsLoaded>());
      final loaded = states[1] as ContentFaqsLoaded;
      expect(loaded.faqs.length, 2);
      expect(loaded.faqs[0]['question'], 'سؤال 1');

      await cubit.close();
    });

    test(
        'loadPrivacyPolicy emits [ContentLoading, ContentPrivacyLoaded] on success',
        () async {
      final repo = MockStudentContentRepository(
        privacyData: {'title': 'سياسة الأمان', 'content': 'بنود الخصوصية'},
      );
      final cubit = ContentCubit(repository: repo);

      final states = <ContentState>[];
      cubit.stream.listen(states.add);

      await cubit.loadPrivacyPolicy();
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<ContentLoading>());
      expect(states[1], isA<ContentPrivacyLoaded>());
      final loaded = states[1] as ContentPrivacyLoaded;
      expect(loaded.title, 'سياسة الأمان');

      await cubit.close();
    });
  });

  group('Info Screens Widget Tests with ContentCubit', () {
    testWidgets('AboutUsScreen renders content loaded from ContentCubit',
        (tester) async {
      final repo = MockStudentContentRepository(
        aboutUsData: {
          'title': 'مركز الأمين التخصصي',
          'content': 'نص تفصيلي عن الرؤية والأهداف.',
        },
      );
      final cubit = ContentCubit(repository: repo);
      if (sl.isRegistered<ContentCubit>()) {
        sl.unregister<ContentCubit>();
      }
      sl.registerSingleton<ContentCubit>(cubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AboutUsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('about_us.title'.tr()), findsOneWidget);
      expect(find.text('مركز الأمين التخصصي'), findsOneWidget);
      expect(find.text('نص تفصيلي عن الرؤية والأهداف.'), findsOneWidget);

      await cubit.close();
      if (sl.isRegistered<ContentCubit>()) {
        sl.unregister<ContentCubit>();
      }
    });

    testWidgets('FaqsScreen renders FAQ items loaded from ContentCubit',
        (tester) async {
      final repo = MockStudentContentRepository(
        faqsData: [
          {'question': 'كيف أسجل في دورة؟', 'answer': 'عبر اختيار الدورة وسداد الرسوم.'},
        ],
      );
      final cubit = ContentCubit(repository: repo);
      if (sl.isRegistered<ContentCubit>()) {
        sl.unregister<ContentCubit>();
      }
      sl.registerSingleton<ContentCubit>(cubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FaqsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('faqs.title'.tr()), findsOneWidget);
      expect(find.text('كيف أسجل في دورة؟'), findsOneWidget);

      await cubit.close();
      if (sl.isRegistered<ContentCubit>()) {
        sl.unregister<ContentCubit>();
      }
    });

    testWidgets('PrivacyPolicyScreen renders policy loaded from ContentCubit',
        (tester) async {
      final repo = MockStudentContentRepository(
        privacyData: {
          'title': 'بنود الخصوصية والحماية',
          'content': 'تفاصيل حماية بيانات المتدربين.',
        },
      );
      final cubit = ContentCubit(repository: repo);
      if (sl.isRegistered<ContentCubit>()) {
        sl.unregister<ContentCubit>();
      }
      sl.registerSingleton<ContentCubit>(cubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PrivacyPolicyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('privacy_policy.title'.tr()), findsOneWidget);
      expect(find.text('بنود الخصوصية والحماية'), findsOneWidget);
      expect(find.text('تفاصيل حماية بيانات المتدربين.'), findsOneWidget);

      await cubit.close();
      if (sl.isRegistered<ContentCubit>()) {
        sl.unregister<ContentCubit>();
      }
    });
  });
}
