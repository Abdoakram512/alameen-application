import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/repositories/auth_repository.dart';
import 'package:secure_admin_app/repositories/impl/auth_repository_impl.dart';

void main() {
  group('MVVM Repository Tests', () {
    test('AuthRepositoryImpl correctly implements AuthRepository contract', () async {
      final AuthRepository repo = AuthRepositoryImpl();
      expect(await repo.isAuthorizedAdmin(null), isFalse);
      expect(await repo.isAuthorizedAdmin(''), isFalse);
    });
  });
}

