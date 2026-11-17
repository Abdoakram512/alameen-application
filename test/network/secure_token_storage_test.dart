import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late SecureTokenStorageImpl tokenStorage;
  final inMemoryMap = <String, String>{};

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    inMemoryMap.clear();

    when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) {
        inMemoryMap[key] = value;
      } else {
        inMemoryMap.remove(key);
      }
    });

    when(() => mockStorage.read(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      return inMemoryMap[key];
    });

    when(() => mockStorage.delete(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      inMemoryMap.remove(key);
    });

    tokenStorage = SecureTokenStorageImpl(storage: mockStorage);
  });

  group('SecureTokenStorage Tests', () {
    test('Token lifecycle: save, read, check, and delete', () async {
      expect(await tokenStorage.hasToken(), isFalse);
      expect(await tokenStorage.getToken(), isNull);

      await tokenStorage.saveToken('1|laravel_sanctum_mock_token_12345');

      expect(await tokenStorage.hasToken(), isTrue);
      expect(await tokenStorage.getToken(), equals('1|laravel_sanctum_mock_token_12345'));

      await tokenStorage.deleteToken();

      expect(await tokenStorage.hasToken(), isFalse);
      expect(await tokenStorage.getToken(), isNull);
    });

    test('User profile persistence: save, read, and delete', () async {
      final mockProfile = {
        'id': 42,
        'name': 'عبد الرحمن علي',
        'email': 'student@elameen.test',
        'status': 'active',
        'role': 'student',
      };

      expect(await tokenStorage.getUserData(), isNull);

      await tokenStorage.saveUserData(mockProfile);

      final loaded = await tokenStorage.getUserData();
      expect(loaded, isNotNull);
      expect(loaded!['id'], equals(42));
      expect(loaded['name'], equals('عبد الرحمن علي'));
      expect(loaded['status'], equals('active'));

      await tokenStorage.deleteUserData();
      expect(await tokenStorage.getUserData(), isNull);
    });

    test('clearAll removes both token and user profile data', () async {
      await tokenStorage.saveToken('token_abc');
      await tokenStorage.saveUserData({'id': 1, 'email': 'test@test.com'});

      expect(await tokenStorage.hasToken(), isTrue);
      expect(await tokenStorage.getUserData(), isNotNull);

      await tokenStorage.clearAll();

      expect(await tokenStorage.hasToken(), isFalse);
      expect(await tokenStorage.getUserData(), isNull);
    });

    test('Invalid or corrupted JSON in storage handles gracefully and deletes bad key', () async {
      inMemoryMap['alameen_user_profile'] = '{invalid_json...';

      final result = await tokenStorage.getUserData();
      expect(result, isNull);
      expect(inMemoryMap.containsKey('alameen_user_profile'), isFalse);
    });
  });
}
