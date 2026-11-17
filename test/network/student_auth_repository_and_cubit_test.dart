import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/auth_remote_data_source.dart';
import 'package:secure_screen_app/logic/auth/auth_cubit.dart';
import 'package:secure_screen_app/logic/auth/auth_state.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/student_auth_repository.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}
class MockStudentAuthRepository extends Mock implements StudentAuthRepository {}

void main() {
  final testUser = UserModel(
    uid: '15',
    id: 15,
    displayName: 'د. أحمد محمد',
    email: 'student@example.com',
    photoUrl: '',
    status: 'active',
    createdAt: DateTime(2026, 1, 1),
  );

  group('StudentAuthRepository Tests', () {
    late MockAuthRemoteDataSource mockRemote;
    late MockSecureTokenStorage mockStorage;
    late StudentAuthRepositoryImpl repository;

    setUp(() {
      mockRemote = MockAuthRemoteDataSource();
      mockStorage = MockSecureTokenStorage();
      repository = StudentAuthRepositoryImpl(
        remoteDataSource: mockRemote,
        tokenStorage: mockStorage,
      );
    });

    test('register returns pending AuthResult and does NOT persist token', () async {
      when(() => mockRemote.register(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            passwordConfirmation: any(named: 'passwordConfirmation'),
            phone: any(named: 'phone'),
            country: any(named: 'country'),
            city: any(named: 'city'),
            address: any(named: 'address'),
            locale: any(named: 'locale'),
            deviceName: any(named: 'deviceName'),
          )).thenAnswer((_) async => const AuthResult(
            status: 'pending',
            message: 'تم إنشاء حسابك بنجاح وهو الآن قيد المراجعة من قِبل إدارة المنصة.',
          ));

      final result = await repository.register(
        name: 'د. أحمد محمد',
        email: 'ahmed@example.com',
        password: 'password123',
        passwordConfirmation: 'password123',
      );

      expect(result.isPending, isTrue);
      expect(result.token, isNull);
      verifyNever(() => mockStorage.saveToken(any()));
    });

    test('login on success persists Sanctum token and user profile', () async {
      when(() => mockRemote.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
            remember: any(named: 'remember'),
            deviceName: any(named: 'deviceName'),
          )).thenAnswer((_) async => AuthResult(
            status: 'authenticated',
            token: '1|sanctum_token_123',
            user: testUser,
          ));

      when(() => mockStorage.saveToken(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveUserData(any())).thenAnswer((_) async {});

      final result = await repository.login(
        email: 'student@example.com',
        password: 'password123',
      );

      expect(result.isAuthenticated, isTrue);
      verify(() => mockStorage.saveToken('1|sanctum_token_123')).called(1);
      verify(() => mockStorage.saveUserData(any())).called(1);
    });

    test('restoreSession returns user when token exists and getMe succeeds', () async {
      when(() => mockStorage.hasToken()).thenAnswer((_) async => true);
      when(() => mockRemote.getMe()).thenAnswer((_) async => testUser);
      when(() => mockStorage.saveUserData(any())).thenAnswer((_) async {});

      final user = await repository.restoreSession();

      expect(user, isNotNull);
      expect(user!.displayName, equals('د. أحمد محمد'));
      verify(() => mockRemote.getMe()).called(1);
    });

    test('restoreSession on 401 Unauthorized clears token and returns null', () async {
      when(() => mockStorage.hasToken()).thenAnswer((_) async => true);
      when(() => mockRemote.getMe()).thenThrow(
        const UnauthorizedException('Unauthenticated.', statusCode: 401),
      );
      when(() => mockStorage.clearAll()).thenAnswer((_) async {});

      final user = await repository.restoreSession();

      expect(user, isNull);
      verify(() => mockStorage.clearAll()).called(1);
    });

    test('restoreSession on offline NetworkTimeout loads cached user and PRESERVES token', () async {
      when(() => mockStorage.hasToken()).thenAnswer((_) async => true);
      when(() => mockRemote.getMe()).thenThrow(
        const NetworkTimeoutException('Network timeout'),
      );
      when(() => mockStorage.getUserData()).thenAnswer((_) async => testUser.toMap());

      final user = await repository.restoreSession();

      expect(user, isNotNull);
      expect(user!.displayName, equals('د. أحمد محمد'));
      // Must NOT clear token on network timeout!
      verifyNever(() => mockStorage.clearAll());
      verifyNever(() => mockStorage.deleteToken());
    });
  });

  group('AuthCubit State Machine Tests via blocTest', () {
    late MockStudentAuthRepository mockRepo;

    setUp(() {
      mockRepo = MockStudentAuthRepository();
    });

    blocTest<AuthCubit, AuthState>(
      'restoreSession emits [Authenticated] when session is valid',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => testUser);
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => [
        isA<Authenticated>().having(
          (s) => s.user.displayName,
          'displayName',
          equals('د. أحمد محمد'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'restoreSession emits [Unauthenticated] when no session exists',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => [
        isA<Unauthenticated>(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signUpWithEmailAndPassword always emits [AuthLoading, AuthPendingApproval]',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.register(
              name: any(named: 'name'),
              email: any(named: 'email'),
              password: any(named: 'password'),
              passwordConfirmation: any(named: 'passwordConfirmation'),
              phone: any(named: 'phone'),
              country: any(named: 'country'),
              city: any(named: 'city'),
              address: any(named: 'address'),
            )).thenAnswer((_) async => const AuthResult(
              status: 'pending',
              message: 'تم إنشاء حسابك بنجاح وهو الآن قيد المراجعة من قِبل إدارة المنصة.',
            ));
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.signUpWithEmailAndPassword(
        name: 'د. أحمد محمد',
        email: 'ahmed@example.com',
        password: 'password123',
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthPendingApproval>().having(
          (s) => s.message,
          'message',
          contains('قيد المراجعة'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithEmailAndPassword emits [AuthLoading, Authenticated] on success',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => AuthResult(
              status: 'authenticated',
              token: 'sanctum_token',
              user: testUser,
            ));
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.signInWithEmailAndPassword(
        email: 'student@example.com',
        password: 'password123',
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<Authenticated>().having(
          (s) => s.user.displayName,
          'displayName',
          equals('د. أحمد محمد'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithEmailAndPassword emits [AuthLoading, AuthPendingApproval] when pending',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => const AuthResult(
              status: 'pending',
              message: 'حسابك قيد المراجعة من قِبل إدارة المنصة.',
            ));
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.signInWithEmailAndPassword(
        email: 'pending@example.com',
        password: 'password123',
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthPendingApproval>().having(
          (s) => s.message,
          'message',
          contains('قيد المراجعة'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithEmailAndPassword emits [AuthLoading, AuthSuspended] when suspended',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => const AuthResult(
              status: 'suspended',
              message: 'تم تعطيل هذا الحساب من قِبل إدارة المنصة.',
            ));
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.signInWithEmailAndPassword(
        email: 'suspended@example.com',
        password: 'password123',
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthSuspended>().having(
          (s) => s.message,
          'message',
          contains('تعطيل'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithEmailAndPassword emits [AuthLoading, AuthError] on ValidationException (422)',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(
          const ValidationException(
            'بيانات الإدخال غير صالحة.',
            errors: {
              'email': ['بيانات الاعتماد هذه غير متطابقة مع سجلاتنا.'],
            },
          ),
        );
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.signInWithEmailAndPassword(
        email: 'wrong@example.com',
        password: 'wrongpassword',
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          contains('بيانات الاعتماد هذه غير متطابقة'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithGoogle emits [AuthLoading, Authenticated] on success',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.loginWithGoogle()).thenAnswer((_) async => AuthResult(
              status: 'authenticated',
              token: 'google_sanctum_token',
              user: testUser,
            ));
        return AuthCubit(authRepository: mockRepo);
      },
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => [
        isA<AuthLoading>(),
        isA<Authenticated>().having(
          (s) => s.user.email,
          'email',
          equals('student@example.com'),
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signOut calls repository logout and emits Unauthenticated',
      build: () {
        when(() => mockRepo.restoreSession()).thenAnswer((_) async => null);
        when(() => mockRepo.logout()).thenAnswer((_) async {});
        return AuthCubit(authRepository: mockRepo);
      },
      seed: () => Authenticated(testUser),
      act: (cubit) => cubit.signOut(),
      expect: () => [
        isA<Unauthenticated>(),
      ],
      verify: (_) {
        verify(() => mockRepo.logout()).called(1);
      },
    );
  });
}
