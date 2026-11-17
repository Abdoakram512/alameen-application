import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/di/injection_container.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/screens/debug/debug_api_test_screen.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
    if (sl.isRegistered<ApiClient>()) {
      sl.unregister<ApiClient>();
    }
    sl.registerSingleton<ApiClient>(mockApiClient);
  });

  tearDown(() {
    if (sl.isRegistered<ApiClient>()) {
      sl.unregister<ApiClient>();
    }
  });

  testWidgets('DebugApiTestScreen renders all 9 target endpoints and executes smoke tests cleanly', (tester) async {
    when(() => mockApiClient.get('/auth/me')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/auth/me'),
        statusCode: 200,
        data: {
          'success': true,
          'data': {
            'user': {
              'id': 15,
              'name': 'طالب تجريبي',
              'email': 'student@alameen.com',
              'status': 'active',
            },
          },
        },
      ),
    );

    when(() => mockApiClient.get('/student/dashboard')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/student/dashboard'),
        statusCode: 200,
        data: {
          'success': true,
          'data': {
            'enrolled_courses': [],
            'pending_courses': [],
            'available_courses': [],
            'total_watched_videos': 5,
            'total_watch_seconds': 1200,
          },
        },
      ),
    );

    when(() => mockApiClient.get(any(that: isNot(isIn(['/auth/me', '/student/dashboard']))))).thenAnswer(
      (inv) async => Response(
        requestOptions: RequestOptions(path: inv.positionalArguments.first.toString()),
        statusCode: 200,
        data: {
          'success': true,
          'data': {},
        },
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DebugApiTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial layout
    expect(find.text('فحص تكامل Laravel API الموثق'), findsOneWidget);
    expect(find.text('GET /auth/me'), findsOneWidget);
    expect(find.text('GET /student/dashboard'), findsOneWidget);
    expect(find.text('GET /student/courses'), findsOneWidget);
    expect(find.text('GET /student/settings/profile'), findsOneWidget);
    expect(find.text('GET /student/receipts'), findsOneWidget);
    expect(find.text('GET /student/assignments'), findsOneWidget);
    expect(find.text('GET /student/grades'), findsOneWidget);
    expect(find.text('GET /student/certificates'), findsOneWidget);
    expect(find.text('GET /student/notifications'), findsOneWidget);

    // Tap run tests
    await tester.tap(find.text('بدء فحص كافة المسارات الآن'));
    await tester.pumpAndSettle();

    // Verify calls
    verify(() => mockApiClient.get('/auth/me')).called(1);
    verify(() => mockApiClient.get('/student/dashboard')).called(1);

    // Verify success indicators
    expect(find.text('تم التحقق من هوية الطالب (الحالة: active) بنجاح'), findsOneWidget);
  });
}
