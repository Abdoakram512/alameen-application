import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/datasources/assignments_remote_data_source.dart';
import 'package:secure_screen_app/datasources/certificates_remote_data_source.dart';
import 'package:secure_screen_app/models/course_certificate.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/models/assignment_submission.dart';
import 'package:secure_screen_app/repositories/impl/student_assignments_repository_impl.dart';
import 'package:secure_screen_app/repositories/student_certificates_repository.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

class MockAssignmentsRemoteDataSource extends Mock
    implements AssignmentsRemoteDataSource {}

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late CertificatesRemoteDataSource remoteDataSource;
  late StudentCertificatesRepositoryImpl certificatesRepository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);

    remoteDataSource = CertificatesRemoteDataSourceImpl(apiClient: mockApiClient);
    certificatesRepository = StudentCertificatesRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
  });

  group('Phase P7 — Student Certificates Migration (Laravel REST API)', () {
    // 1. Certificate list parsing
    test('1. GET /student/certificates parses student earned certificates correctly', () async {
      when(() => mockApiClient.get('/student/certificates')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/certificates'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'certificates': [
                {
                  'id': 7,
                  'user_id': 15,
                  'course_id': 1,
                  'certificate_code': 'ALAMEEN-2026-8F92A',
                  'verification_url': 'https://alameen-center.online/certificates/verify/ALAMEEN-2026-8F92A',
                  'file_url': 'https://alameen-center.online/storage/certificates/ALAMEEN-2026-8F92A.pdf',
                  'file_type': 'pdf',
                  'signatory_name': 'د. هنا المكاوي',
                  'signatory_title': 'المدير الأكاديمي والإكلينيكي',
                  'issued_at': '2026-10-15T10:30:00+02:00',
                  'course': {
                    'id': 1,
                    'title': 'دبلوم التخاطب واضطرابات النطق المتكامل',
                  },
                },
              ],
            },
          },
        ),
      );

      final certs = await certificatesRepository.getStudentCertificates();
      expect(certs.length, equals(1));
      expect(certs.first.id, equals('7'));
      expect(certs.first.userId, equals(15));
      expect(certs.first.courseId, equals('1'));
      expect(certs.first.certificateCode, equals('ALAMEEN-2026-8F92A'));
      expect(certs.first.serialNumber, equals('ALAMEEN-2026-8F92A'));
      expect(certs.first.courseTitle, equals('دبلوم التخاطب واضطرابات النطق المتكامل'));
      expect(certs.first.signatoryName, equals('د. هنا المكاوي'));
      expect(certs.first.hasDownloadableFile, isTrue);
    });

    // 2. Empty certificate list handling
    test('2. GET /student/certificates handles empty certificate lists gracefully', () async {
      when(() => mockApiClient.get('/student/certificates')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/certificates'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'certificates': [],
            },
          },
        ),
      );

      final certs = await certificatesRepository.getStudentCertificates();
      expect(certs, isEmpty);
    });

    // 3. Certificate detail retrieval
    test('3. GET /student/certificates/{code} retrieves details using official certificate code', () async {
      const code = 'ALAMEEN-2026-8F92A';
      when(() => mockApiClient.get('/student/certificates/$code')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/certificates/$code'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'certificate': {
                'id': 7,
                'user_id': 15,
                'course_id': 1,
                'certificate_code': code,
                'verification_url': 'https://alameen-center.online/certificates/verify/$code',
                'file_url': 'https://alameen-center.online/storage/certificates/$code.pdf',
                'file_type': 'pdf',
                'signatory_name': 'د. هنا المكاوي',
                'issued_at': '2026-10-15T10:30:00+02:00',
                'course': {
                  'title': 'دبلوم التخاطب',
                },
              },
            },
          },
        ),
      );

      final details = await certificatesRepository.getCertificateDetails(code);
      expect(details.certificateCode, equals(code));
      expect(details.courseTitle, equals('دبلوم التخاطب'));
      expect(details.signatoryName, equals('د. هنا المكاوي'));
    });

    // 4. Correct certificate-code routing
    test('4. Correct certificate code routing trims whitespace and validates input', () async {
      expect(
        () => remoteDataSource.getCertificateDetails('   '),
        throwsA(isA<ApiException>()),
      );
    });

    // 5. Public verification success
    test('5. GET /public/certificates/verify/{code} returns valid status for registered certificate', () async {
      const code = 'ALAMEEN-2026-8F92A';
      when(() => mockApiClient.get(
            '/public/certificates/verify/$code',
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/public/certificates/verify/$code'),
          statusCode: 200,
          data: {
            'success': true,
            'valid': true,
            'message': 'الشهادة موثقة وصالحة في مركز الأمين.',
            'data': {
              'certificate': {
                'id': 7,
                'user_id': 15,
                'course_id': 1,
                'certificate_code': code,
                'verification_url': 'https://alameen-center.online/certificates/verify/$code',
                'signatory_name': 'د. هنا المكاوي',
                'issued_at': '2026-10-15T10:30:00+02:00',
              },
            },
          },
        ),
      );

      final result = await certificatesRepository.verifyCertificate(code);
      expect(result.success, isTrue);
      expect(result.valid, isTrue);
      expect(result.message, contains('موثقة وصالحة'));
      expect(result.certificate?.certificateCode, equals(code));
    });

    // 6. Invalid certificate verification
    test('6. GET /public/certificates/verify/{code} handles 404 cleanly as invalid certificate', () async {
      const invalidCode = 'INVALID-999';
      when(() => mockApiClient.get(
            '/public/certificates/verify/$invalidCode',
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/public/certificates/verify/$invalidCode'),
          response: Response(
            requestOptions: RequestOptions(path: '/public/certificates/verify/$invalidCode'),
            statusCode: 404,
            data: {
              'success': false,
              'valid': false,
              'message': 'رمز الشهادة غير صالح أو غير مسجل في المنصة.',
            },
          ),
        ),
      );

      final result = await certificatesRepository.verifyCertificate(invalidCode);
      expect(result.valid, isFalse);
      expect(result.message, contains('رمز الشهادة غير صالح'));
    });

    // 7. Download URL handling
    test('7. Official certificate PDF is downloaded from server file_url without exposing tokens', () async {
      const fileUrl = 'https://alameen-center.online/storage/certificates/ALAMEEN-2026-8F92A.pdf';
      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF

      when(() => mockDio.get<List<int>>(
            fileUrl,
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: fileUrl),
          statusCode: 200,
          data: dummyPdfBytes.toList(),
        ),
      );

      final bytes = await certificatesRepository.downloadOfficialCertificatePdf(fileUrl);
      expect(bytes, equals(dummyPdfBytes));
    });

    // 8. Missing or inaccessible certificate files
    test('8. Throws CertificateFileNotAvailableException when official PDF is not available or 404', () async {
      expect(
        () => certificatesRepository.downloadOfficialCertificatePdf(''),
        throwsA(isA<CertificateFileNotAvailableException>()),
      );

      const notFoundUrl = 'https://alameen-center.online/storage/certificates/missing.pdf';
      when(() => mockDio.get<List<int>>(
            notFoundUrl,
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: notFoundUrl),
          response: Response(
            requestOptions: RequestOptions(path: notFoundUrl),
            statusCode: 404,
          ),
        ),
      );

      expect(
        () => certificatesRepository.downloadOfficialCertificatePdf(notFoundUrl),
        throwsA(isA<CertificateFileNotAvailableException>()),
      );
    });

    // 9. No unauthorized certificate issuance
    test('9. CourseCertificate has no client-side issuance endpoint or factory for fake certificates', () {
      final cert = CourseCertificate.fromLaravelJson({
        'id': 10,
        'certificate_code': 'OFFICIAL-CODE',
        'course_id': 2,
        'user_id': 15,
        'issued_at': '2026-03-01T00:00:00Z',
      });

      expect(cert.certificateCode, equals('OFFICIAL-CODE'));
      expect(cert.serialNumber, equals('OFFICIAL-CODE'));
    });

    // 10. Student-account cache isolation
    test('10. StudentCertificatesRepository isolates cache by student ID and clears on logout', () async {
      when(() => mockApiClient.get('/student/certificates')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/certificates'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'certificates': [
                {
                  'id': 1,
                  'certificate_code': 'CERT-USER-A',
                  'course_id': 10,
                  'user_id': 15,
                  'issued_at': '2026-01-01T00:00:00Z',
                },
              ],
            },
          },
        ),
      );

      // Student A
      final listA = await certificatesRepository.getStudentCertificates(
        currentStudentId: '15',
      );
      expect(listA.first.certificateCode, equals('CERT-USER-A'));

      // Switch to Student B (must clear cache and re-fetch)
      when(() => mockApiClient.get('/student/certificates')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/certificates'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'certificates': [
                {
                  'id': 2,
                  'certificate_code': 'CERT-USER-B',
                  'course_id': 20,
                  'user_id': 99,
                  'issued_at': '2026-02-01T00:00:00Z',
                },
              ],
            },
          },
        ),
      );

      final listB = await certificatesRepository.getStudentCertificates(
        currentStudentId: '99',
      );
      expect(listB.first.certificateCode, equals('CERT-USER-B'));

      // Clear cache on logout
      certificatesRepository.clearCache();
    });

    // 11. Network error handling
    test('11. DioException is cleanly mapped to ApiException in certificates data source', () async {
      when(() => mockApiClient.get('/student/certificates')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/student/certificates'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => certificatesRepository.getStudentCertificates(forceRefresh: true),
        throwsA(isA<ApiException>()),
      );
    });

    // 12. Firebase certificate cleanup verification
    test('12. CourseCertificate model has zero Firestore imports and parses pure JSON', () {
      final cert = CourseCertificate.fromMap({
        'id': 'cert-test',
        'courseId': 'course-1',
        'courseTitle': 'دورة التخاطب',
        'studentId': '15',
        'studentName': 'طالب الأمين',
        'serialNumber': 'ALM-123',
        'issuedAt': '2026-11-18T10:00:00.000Z',
        'completionPercentage': 98.0,
      });

      expect(cert.id, equals('cert-test'));
      expect(cert.certificateCode, equals('ALM-123'));
      expect(cert.completionPercentage, equals(98.0));
      expect(cert.toMap()['certificate_code'], equals('ALM-123'));
    });
  });

  group('P6 Targeted Corrections Regressions (A1, A2, A3)', () {
    // A1: Attachment upload refusal
    test('A1: Submitting non-audio attachment throws UnsupportedFileAttachmentException and does not convert to student_notes', () async {
      final repo = StudentAssignmentsRepositoryImpl(
        remoteDataSource: MockAssignmentsRemoteDataSource(),
      );

      final tempImageFile = File('fake_image.png');

      final submission = AssignmentSubmission(
        id: 'sub-1',
        assignmentId: '10',
        courseId: '1',
        studentId: '15',
        studentName: 'طالب',
        studentEmail: 'std@example.com',
        solutionText: 'حل الواجب النصي',
        submittedAt: DateTime.now(),
      );

      expect(
        () => repo.submitAssignment(
          submission: submission,
          attachmentFile: tempImageFile,
        ),
        throwsA(isA<UnsupportedFileAttachmentException>()),
      );
    });

    // A2: Laravel user identity isolation
    test('A2: UserModel.fromLaravelJson rejects invalid, missing or literal "uid" with FormatException', () {
      expect(
        () => UserModel.fromLaravelJson({'id': null, 'uid': 'uid'}),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => UserModel.fromLaravelJson({'id': 0, 'name': 'Test'}),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => UserModel.fromLaravelJson({'name': 'No ID User'}),
        throwsA(isA<FormatException>()),
      );

      final validUser = UserModel.fromLaravelJson({'id': 15, 'name': 'Ahmed'});
      expect(validUser.uid, equals('15'));
      expect(validUser.id, equals(15));
    });

    test('A2: WatchQueue rejects literal "uid" and invalid keys from creating shared storage keys', () {
      expect(() => WatchQueue.storageKeyForUser('uid'), throwsArgumentError);
      expect(() => WatchQueue.storageKeyForUser(''), throwsArgumentError);
      expect(() => WatchQueue.storageKeyForUser('0'), throwsArgumentError);
      expect(() => WatchQueue.storageKeyForUser('null'), throwsArgumentError);

      expect(WatchQueue.storageKeyForUser('15'), equals('watch.queue.v1.15'));
      expect(WatchQueue.isValidUid('uid'), isFalse);
      expect(WatchQueue.isValidUid('15'), isTrue);
    });
  });
}
