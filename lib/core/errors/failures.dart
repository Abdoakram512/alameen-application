import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'حدث خطأ في الاتصال بالخادم.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'فشل تسجيل الدخول أو غير مصرح به.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'البيانات المدخلة غير صحيحة.']);
}

class UploadFailure extends Failure {
  const UploadFailure([super.message = 'فشل رفع الملف أو الفيديو إلى السيرفر.']);
}

