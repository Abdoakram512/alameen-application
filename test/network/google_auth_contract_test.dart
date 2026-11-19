import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/auth_remote_data_source.dart';
import 'package:secure_screen_app/repositories/student_auth_repository.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}
class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRITICAL TASK A — Google OAuth Contract & Access Token Verification', () {
    late MockApiClient mockApiClient;
    late AuthRemoteDataSource remoteDataSource;

    setUp(() {
      mockApiClient = MockApiClient();
      remoteDataSource = AuthRemoteDataSourceImpl(apiClient: mockApiClient);
      registerFallbackValue(FormData());
      registerFallbackValue(Options());
    });

    test('1. RemoteDataSource sends multipart/form-data containing access_token to /auth/google/token with skipAuth', () async {
      FormData? recordedFormData;
      Options? recordedOptions;

      when(() => mockApiClient.postMultipart(
            '/auth/google/token',
            formData: any(named: 'formData'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        recordedFormData = invocation.namedArguments[#formData] as FormData;
        recordedOptions = invocation.namedArguments[#options] as Options?;

        return Response(
          requestOptions: RequestOptions(path: '/auth/google/token'),
          statusCode: 200,
          data: {
            'success': true,
            'status': 'authenticated',
            'message': 'تم تسجيل الدخول عبر Google بنجاح.',
            'data': {
              'token': '3|sanctum_session_token_from_laravel',
              'token_type': 'Bearer',
              'user': {
                'id': 15,
                'name': 'طالب تجريبي جوجل',
                'email': 'student.google@alameen.com',
                'status': 'active',
              },
            },
          },
        );
      });

      const testOAuthAccessToken = 'ya29.a0AfH6SMBx_sample_oauth2_access_token_xyz';

      final result = await remoteDataSource.loginWithGoogleToken(
        accessToken: testOAuthAccessToken,
        deviceName: 'Android Device',
      );

      // Verify endpoint and result
      expect(result.isAuthenticated, isTrue);
      expect(result.token, '3|sanctum_session_token_from_laravel');
      expect(result.user?.email, 'student.google@alameen.com');

      // Verify formData is multipart and contains access_token
      expect(recordedFormData, isNotNull);
      final fields = recordedFormData!.fields;

      final accessTokenField = fields.firstWhere(
        (f) => f.key == 'access_token',
        orElse: () => const MapEntry('', ''),
      );
      expect(accessTokenField.key, 'access_token');
      expect(accessTokenField.value, testOAuthAccessToken);

      // Ensure NO id_token field is sent
      final hasIdToken = fields.any((f) => f.key == 'id_token');
      expect(hasIdToken, isFalse, reason: 'Endpoint expects OAuth access_token, must not send id_token');

      // Verify device_name
      final deviceNameField = fields.firstWhere((f) => f.key == 'device_name');
      expect(deviceNameField.value, 'Android Device');

      // Verify skipAuth: true is passed so unauthenticated exchange succeeds without existing Bearer token
      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.extra?['skipAuth'], isTrue);
    });

    test('2. StudentAuthRepositoryImpl strictly passes googleAuth.accessToken to RemoteDataSource', () async {
      final mockGoogleSignIn = MockGoogleSignIn();
      final mockAccount = MockGoogleSignInAccount();
      final mockAuth = MockGoogleSignInAuthentication();
      final mockRemoteDataSource = MockAuthRemoteDataSource();
      final mockTokenStorage = MockSecureTokenStorage();

      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.authentication).thenAnswer((_) async => mockAuth);

      const fakeOAuthAccessToken = 'ya29.a0AfH6SMBx_valid_access_token_123';
      const fakeOidcIdToken = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.dummy_id_token';

      // Setup authentication mock: returns both accessToken and idToken
      when(() => mockAuth.accessToken).thenReturn(fakeOAuthAccessToken);
      when(() => mockAuth.idToken).thenReturn(fakeOidcIdToken);

      when(() => mockRemoteDataSource.loginWithGoogleToken(
            accessToken: fakeOAuthAccessToken,
            deviceName: any(named: 'deviceName'),
          )).thenAnswer(
        (_) async => AuthResult(
          status: 'authenticated',
          token: '3|token_abc',
        ),
      );

      when(() => mockTokenStorage.saveToken(any())).thenAnswer((_) async {});
      when(() => mockTokenStorage.saveUserData(any())).thenAnswer((_) async {});

      final repo = StudentAuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        tokenStorage: mockTokenStorage,
        googleSignIn: mockGoogleSignIn,
      );

      final authResult = await repo.loginWithGoogle();

      expect(authResult.isAuthenticated, isTrue);

      // PROOF: Verify remoteDataSource was called with fakeOAuthAccessToken (NOT fakeOidcIdToken)
      verify(() => mockRemoteDataSource.loginWithGoogleToken(
            accessToken: fakeOAuthAccessToken,
          )).called(1);

      verifyNever(() => mockRemoteDataSource.loginWithGoogleToken(
            accessToken: fakeOidcIdToken,
          ));
    });

    test('3. StudentAuthRepositoryImpl throws ApiException when Google does not issue an accessToken', () async {
      final mockGoogleSignIn = MockGoogleSignIn();
      final mockAccount = MockGoogleSignInAccount();
      final mockAuth = MockGoogleSignInAuthentication();
      final mockRemoteDataSource = MockAuthRemoteDataSource();
      final mockTokenStorage = MockSecureTokenStorage();

      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.authentication).thenAnswer((_) async => mockAuth);

      // OAuth accessToken is null (e.g. scope failure)
      when(() => mockAuth.accessToken).thenReturn(null);
      when(() => mockAuth.idToken).thenReturn('some_id_token');

      final repo = StudentAuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        tokenStorage: mockTokenStorage,
        googleSignIn: mockGoogleSignIn,
      );

      expect(
        () => repo.loginWithGoogle(),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('رمز الوصول (OAuth Access Token)'),
        )),
      );

      // Verify remote data source is NEVER called with null or invalid token
      verifyZeroInteractions(mockRemoteDataSource);
    });

    test('4. StudentAuthRepositoryImpl handles cancellation gracefully without calling backend', () async {
      final mockGoogleSignIn = MockGoogleSignIn();
      final mockRemoteDataSource = MockAuthRemoteDataSource();
      final mockTokenStorage = MockSecureTokenStorage();

      // User dismisses Google sign in dialog
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final repo = StudentAuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        tokenStorage: mockTokenStorage,
        googleSignIn: mockGoogleSignIn,
      );

      final result = await repo.loginWithGoogle();

      expect(result.status, 'cancelled');
      expect(result.isAuthenticated, isFalse);
      verifyZeroInteractions(mockRemoteDataSource);
    });
  });
}
