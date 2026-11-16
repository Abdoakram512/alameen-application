class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'حدث خطأ في الخادم']);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'غير مصرح بالوصول لهذا الحساب']);

  @override
  String toString() => message;
}

class UploadException implements Exception {
  final String message;
  const UploadException([this.message = 'فشل رفع الملف']);

  @override
  String toString() => message;
}

