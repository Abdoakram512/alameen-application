import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/network/auth_interceptor.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/payment_remote_data_source.dart';
import 'package:secure_screen_app/logic/access/access_cubit.dart';
import 'package:secure_screen_app/logic/access/access_state.dart';
import 'package:secure_screen_app/models/access_request.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/payment_receipt_model.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/impl/student_payment_repository_impl.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';

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

class InMemoryTokenStorage implements SecureTokenStorage {
  String? _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> deleteToken() async => _token = null;

  @override
  Future<bool> hasToken() async => _token != null;

  @override
  Future<void> saveUserData(Map<String, dynamic> data) async {}

  @override
  Future<Map<String, dynamic>?> getUserData() async => null;

  @override
  Future<void> deleteUserData() async {}

  @override
  Future<void> clearAll() async => _token = null;
}

class MockStudentPaymentRepository extends Mock implements StudentPaymentRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P4 PaymentReceiptModel Tests', () {
    test('deserializes strictly matching OpenAPI PaymentReceipt schema', () {
      final json = {
        'id': 19,
        'user_id': 15,
        'course_id': 3,
        'payment_method': 'instapay',
        'payment_method_label': 'InstaPay',
        'sender_identifier': 'ahmed@instapay',
        'transaction_reference': 'TXN-9928374',
        'amount_paid': 1500,
        'receipt_image_url': 'https://alameen-center.online/storage/receipts/19.png',
        'status': 'pending',
        'admin_notes': null,
        'reviewed_at': null,
        'created_at': '2026-11-17T12:00:00Z',
        'updated_at': '2026-11-17T12:00:00Z',
        'course': {
          'id': 3,
          'title': 'دبلوم التخاطب السريري الشامل',
          'slug': 'comprehensive-speech-therapy-diploma',
        },
      };

      final model = PaymentReceiptModel.fromJson(json);

      expect(model.id, equals(19));
      expect(model.userId, equals(15));
      expect(model.courseId, equals(3));
      expect(model.paymentMethod, equals('instapay'));
      expect(model.paymentMethodLabel, equals('InstaPay'));
      expect(model.senderIdentifier, equals('ahmed@instapay'));
      expect(model.transactionReference, equals('TXN-9928374'));
      expect(model.amountPaid, equals(1500.0));
      expect(model.receiptImageUrl, equals('https://alameen-center.online/storage/receipts/19.png'));
      expect(model.status, equals(AccessStatus.pending));
      expect(model.adminNotes, isNull);
      expect(model.reviewedAt, isNull);
      expect(model.courseTitle, equals('دبلوم التخاطب السريري الشامل'));
      expect(model.courseSlug, equals('comprehensive-speech-therapy-diploma'));
    });

    test('deserializes approved receipt with admin notes and converts to CourseAccessRequest', () {
      final json = {
        'id': 20,
        'user_id': 15,
        'course_id': 5,
        'payment_method': 'vodafone_cash',
        'payment_method_label': 'فودافون كاش',
        'sender_identifier': '01012345678',
        'transaction_reference': null,
        'amount_paid': '750.50',
        'receipt_image_url': 'https://alameen-center.online/storage/receipts/20.jpg',
        'status': 'approved',
        'admin_notes': 'تم التحقق من المعاملة بنجاح',
        'reviewed_at': '2026-11-17T14:30:00Z',
        'created_at': '2026-11-17T10:00:00Z',
      };

      final model = PaymentReceiptModel.fromJson(json);
      expect(model.status, equals(AccessStatus.approved));
      expect(model.amountPaid, equals(750.50));

      final accessReq = model.toCourseAccessRequest(fallbackCourseTitle: 'دورة النطق والتخاطب');
      expect(accessReq.id, equals('20'));
      expect(accessReq.courseId, equals('5'));
      expect(accessReq.courseTitle, equals('دورة النطق والتخاطب'));
      expect(accessReq.status, equals(AccessStatus.approved));
      expect(accessReq.adminNotes, equals('تم التحقق من المعاملة بنجاح'));
      expect(accessReq.receiptUrl, equals('https://alameen-center.online/storage/receipts/20.jpg'));
    });

    test('serializes to JSON matching backend expectation', () {
      final model = PaymentReceiptModel(
        id: 42,
        userId: 10,
        courseId: 7,
        paymentMethod: 'instapay',
        paymentMethodLabel: 'InstaPay',
        senderIdentifier: 'user@instapay',
        amountPaid: 2000.0,
        createdAt: DateTime.parse('2026-11-17T12:00:00Z'),
        status: AccessStatus.pending,
      );

      final json = model.toJson();
      expect(json['id'], equals(42));
      expect(json['user_id'], equals(10));
      expect(json['course_id'], equals(7));
      expect(json['payment_method'], equals('instapay'));
      expect(json['amount_paid'], equals(2000.0));
      expect(json['status'], equals('pending'));
    });
  });

  group('P4 PaymentRemoteDataSource Tests', () {
    late Dio dio;
    late ApiClient apiClient;
    late PaymentRemoteDataSource dataSource;
    late File tempReceiptFile;

    setUp(() async {
      dio = Dio(BaseOptions(baseUrl: 'https://alameen-center.online/api/v1'));
      final tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveToken('test_sanctum_token_123');
      final authInterceptor = AuthInterceptor(tokenStorage: tokenStorage);
      apiClient = ApiClient(dio: dio, authInterceptor: authInterceptor);
      dataSource = PaymentRemoteDataSourceImpl(apiClient: apiClient);

      tempReceiptFile = File('${Directory.systemTemp.path}/test_receipt_p4.png');
      await tempReceiptFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    });

    tearDown(() async {
      if (await tempReceiptFile.exists()) {
        await tempReceiptFile.delete();
      }
    });

    test('submitCourseReceipt builds valid multipart request and parses 201 response', () async {
      final responsePayload = {
        'success': true,
        'message': 'Payment receipt submitted successfully',
        'data': {
          'receipt': {
            'id': 101,
            'user_id': 50,
            'course_id': 12,
            'payment_method': 'instapay',
            'payment_method_label': 'InstaPay',
            'sender_identifier': 'student@instapay',
            'transaction_reference': 'REF9988',
            'amount_paid': 1200.0,
            'receipt_image_url': 'https://alameen-center.online/storage/receipts/101.png',
            'status': 'pending',
            'admin_notes': null,
            'reviewed_at': null,
            'created_at': '2026-11-17T15:00:00Z',
          }
        }
      };

      RequestOptions? capturedOptions;
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(responsePayload),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await dataSource.submitCourseReceipt(
        courseSlug: 'speech-diploma',
        paymentMethod: 'إنستاباي (InstaPay)',
        senderName: 'محمد أحمد',
        senderAccount: 'student@instapay',
        amount: 1200.0,
        receiptFilePath: tempReceiptFile.path,
        transactionReference: 'REF9988',
      );

      expect(result.id, equals(101));
      expect(result.courseId, equals(12));
      expect(result.paymentMethod, equals('instapay'));
      expect(result.status, equals(AccessStatus.pending));

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, equals('/student/courses/speech-diploma/receipt'));
      expect(capturedOptions!.method, equals('POST'));

      final formData = capturedOptions!.data as FormData;
      expect(formData.fields.firstWhere((f) => f.key == 'payment_method').value, equals('instapay'));
      expect(formData.fields.firstWhere((f) => f.key == 'sender_name').value, equals('محمد أحمد'));
      expect(formData.fields.firstWhere((f) => f.key == 'sender_account').value, equals('student@instapay'));
      expect(formData.fields.firstWhere((f) => f.key == 'amount').value, equals('1200.0'));
      expect(formData.fields.firstWhere((f) => f.key == 'transaction_reference').value, equals('REF9988'));
      expect(formData.files.any((f) => f.key == 'receipt_image'), isTrue);
    });

    test('submitCourseReceipt throws ApiException if file does not exist', () async {
      expect(
        () => dataSource.submitCourseReceipt(
          courseSlug: 'speech-diploma',
          paymentMethod: 'vodafone_cash',
          senderName: 'أحمد',
          senderAccount: '01011111111',
          amount: 500.0,
          receiptFilePath: 'non_existent_path_123.jpg',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('getStudentReceipts retrieves receipts and maps query parameter cleanly', () async {
      final listPayload = {
        'success': true,
        'data': {
          'receipts': [
            {
              'id': 1,
              'course_id': 10,
              'payment_method': 'vodafone_cash',
              'sender_identifier': '01012345678',
              'amount_paid': 500,
              'status': 'pending',
              'created_at': '2026-11-17T12:00:00Z',
            },
            {
              'id': 2,
              'course_id': 11,
              'payment_method': 'instapay',
              'sender_identifier': 'user@instapay',
              'amount_paid': 1000,
              'status': 'approved',
              'created_at': '2026-11-17T13:00:00Z',
            }
          ]
        }
      };

      RequestOptions? capturedOptions;
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(listPayload),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final receipts = await dataSource.getStudentReceipts(courseId: 10);

      expect(receipts.length, equals(2));
      expect(receipts[0].id, equals(1));
      expect(receipts[0].status, equals(AccessStatus.pending));
      expect(receipts[1].id, equals(2));
      expect(receipts[1].status, equals(AccessStatus.approved));

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, equals('/student/receipts'));
      expect(capturedOptions!.queryParameters, equals({'course_id': 10}));
    });
  });

  group('P4 StudentPaymentRepositoryImpl Tests', () {
    late Dio dio;
    late ApiClient apiClient;
    late PaymentRemoteDataSource remoteDataSource;
    late StudentPaymentRepository repository;
    late File tempFile;

    setUp(() async {
      dio = Dio(BaseOptions(baseUrl: 'https://alameen-center.online/api/v1'));
      final tokenStorage = InMemoryTokenStorage();
      final authInterceptor = AuthInterceptor(tokenStorage: tokenStorage);
      apiClient = ApiClient(dio: dio, authInterceptor: authInterceptor);
      remoteDataSource = PaymentRemoteDataSourceImpl(apiClient: apiClient);
      repository = StudentPaymentRepositoryImpl(remoteDataSource: remoteDataSource);

      tempFile = File('${Directory.systemTemp.path}/repo_test_receipt.jpg');
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('submitCourseReceipt delegates correctly to data source', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'receipt': {
                'id': 555,
                'course_id': 88,
                'payment_method': 'vodafone_cash',
                'sender_identifier': '01099998888',
                'amount_paid': 600.0,
                'status': 'pending',
                'created_at': '2026-11-17T15:00:00Z',
              }
            }
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final receipt = await repository.submitCourseReceipt(
        courseSlug: 'speech-course',
        paymentMethod: 'vodafone_cash',
        senderName: 'عمرو خالد',
        senderAccount: '01099998888',
        amount: 600.0,
        receiptFilePath: tempFile.path,
      );

      expect(receipt.id, equals(555));
      expect(receipt.amountPaid, equals(600.0));
    });
  });

  group('P4 AccessCubit State & Lifecycle Tests', () {
    late MockStudentPaymentRepository mockPaymentRepo;
    late AccessCubit cubit;
    late File tempFile;

    setUp(() async {
      mockPaymentRepo = MockStudentPaymentRepository();
      cubit = AccessCubit(paymentRepository: mockPaymentRepo);
      tempFile = File('${Directory.systemTemp.path}/receipt_cubit_test.jpg');
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
    });

    tearDown(() async {
      await cubit.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      AccessCubit.clearCache();
    });

    test('initial state is AccessInitial', () {
      expect(cubit.state, equals(AccessInitial()));
    });

    test('loadStudentReceipts fetches receipts, maps statuses, and emits AccessLoaded', () async {
      final receipt = PaymentReceiptModel(
        id: 77,
        userId: 25,
        courseId: 300,
        paymentMethod: 'vodafone_cash',
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01000000000',
        amountPaid: 800.0,
        status: AccessStatus.pending,
        createdAt: DateTime.now(),
      );

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => [receipt]);

      final expectedStates = [
        isA<AccessLoading>(),
        isA<AccessLoaded>().having(
          (s) => s.getStatus('300'),
          'status for course 300',
          equals(AccessStatus.pending),
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadStudentReceipts();

      final state = cubit.state as AccessLoaded;
      expect(state.courseStatuses['300'], equals(AccessStatus.pending));
      expect(state.requestsByCourse['300']?.id, equals('77'));
    });

    test('submitCourseReceipt posts data, updates state, and emits AccessActionSuccess', () async {
      final newReceipt = PaymentReceiptModel(
        id: 88,
        userId: 25,
        courseId: 400,
        paymentMethod: 'instapay',
        paymentMethodLabel: 'InstaPay',
        senderIdentifier: 'student@instapay',
        amountPaid: 1500.0,
        status: AccessStatus.pending,
        createdAt: DateTime.now(),
        courseTitle: 'دبلوم التخاطب',
      );

      when(() => mockPaymentRepo.submitCourseReceipt(
        courseSlug: any(named: 'courseSlug'),
        paymentMethod: any(named: 'paymentMethod'),
        senderName: any(named: 'senderName'),
        senderAccount: any(named: 'senderAccount'),
        amount: any(named: 'amount'),
        receiptFilePath: any(named: 'receiptFilePath'),
        transactionReference: any(named: 'transactionReference'),
      )).thenAnswer((_) async => newReceipt);

      final expectedStates = [
        isA<AccessLoading>(),
        isA<AccessActionSuccess>().having(
          (s) => s.getStatus('400'),
          'status for course 400',
          equals(AccessStatus.pending),
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.submitCourseReceipt(
        courseSlug: 'speech-course',
        courseId: '400',
        courseTitle: 'دبلوم التخاطب',
        paymentMethod: 'instapay',
        senderName: 'محمد أحمد',
        senderAccount: 'student@instapay',
        amount: 1500.0,
        receiptFilePath: tempFile.path,
        transactionReference: 'TXN-1234',
      );

      final state = cubit.state as AccessActionSuccess;
      expect(state.message, contains('تم إرسال إيصال السداد للمراجعة بنجاح'));
      expect(state.courseStatuses['400'], equals(AccessStatus.pending));
    });

    test('sendRequest requires receiptFile and returns Arabic error if missing', () async {
      final dummyCourse = const Course(
        id: '99',
        title: 'دورة تجريبية',
        description: 'وصف تجريبي للدورة',
        instructor: 'د. الأمين',
        category: 'تخاطب سريري',
        thumbnailUrl: '',
        levels: [],
        price: 200.0,
      );
      final dummyUser = UserModel(
        uid: 'user_1',
        email: 'test@example.com',
        displayName: 'طالب سنتر الأمين',
        photoUrl: '',
        createdAt: DateTime.now(),
      );

      expectLater(
        cubit.stream,
        emits(isA<AccessError>().having(
          (e) => e.message,
          'message',
          contains('يرجى إرفاق صورة واضحة لإيصال السداد'),
        )),
      );

      await cubit.sendRequest(
        course: dummyCourse,
        user: dummyUser,
        receiptFile: null,
      );
    });

    test('enrollInOpenCourse grants immediate access and emits AccessActionSuccess', () async {
      final dummyCourse = const Course(
        id: '100',
        title: 'دورة مجانية مفتوحة',
        description: 'وصف الدورة المفتوحة',
        instructor: 'د. الأمين',
        category: 'تخاطب سريري',
        thumbnailUrl: '',
        levels: [],
        price: 0.0,
      );

      final expectedStates = [
        isA<AccessLoading>(),
        isA<AccessActionSuccess>().having(
          (s) => s.getStatus('100'),
          'status for course 100',
          equals(AccessStatus.approved),
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.enrollInOpenCourse(
        uid: 'user_1',
        course: dummyCourse,
      );

      final state = cubit.state as AccessActionSuccess;
      expect(state.getStatus('100'), equals(AccessStatus.approved));
      expect(state.message, contains('تم تسجيلك في دورة "دورة مجانية مفتوحة" بنجاح'));
    });

    test('clearCache and clear reset state and caches', () {
      AccessCubit.clearCache();
      cubit.clear();
      expect(cubit.state, equals(AccessInitial()));
    });
  });
}
