import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/user_profile.dart';

/// Structured result wrapper returned by authentication endpoints.
class AuthResult {
  final String status; // 'authenticated', 'pending', 'suspended'
  final String? token;
  final String? tokenType;
  final String? message;
  final UserModel? user;

  const AuthResult({
    required this.status,
    this.token,
    this.tokenType,
    this.message,
    this.user,
  });

  bool get isAuthenticated => status == 'authenticated' && token != null;
  bool get isPending => status == 'pending';
  bool get isSuspended => status == 'suspended';

  @override
  String toString() => 'AuthResult(status: $status, token: ${token != null ? '***' : 'null'}, message: $message)';
}

/// Abstract contract for authentication remote communication with Laravel REST API.
abstract class AuthRemoteDataSource {
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? country,
    String? city,
    String? address,
    String? locale,
    String? deviceName,
  });

  Future<AuthResult> login({
    required String email,
    required String password,
    bool remember = true,
    String? deviceName,
  });

  Future<AuthResult> loginWithGoogleToken({
    required String accessToken,
    String? deviceName,
  });

  Future<AuthResult> loginWithFirebaseIdToken({
    required String idToken,
    bool remember = true,
    String? deviceName,
  });

  Future<UserModel> getMe();

  Future<void> logout({bool allDevices = false});

  Future<String> forgotPassword({required String email});

  Future<bool> verifyOtp({required String email, required String otp});

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
    String? deviceName,
  });

  Future<UserModel> getProfile();

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? bio,
    String? locale,
    String? avatarFilePath,
  });

  Future<bool> deleteAccount({required String currentPassword});

  /// Update password (PUT /student/settings/password)
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });
}

/// Implementation of [AuthRemoteDataSource] using [ApiClient] and multipart/form-data.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? country,
    String? city,
    String? address,
    String? locale,
    String? deviceName,
  }) async {
    final formMap = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
      'locale': locale ?? 'ar',
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (country != null && country.trim().isNotEmpty) 'country': country.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (deviceName != null && deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
    };

    final formData = FormData.fromMap(formMap);

    final response = await _apiClient.postMultipart(
      '/auth/register',
      formData: formData,
      options: Options(extra: {'skipAuth': true}),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final String status = (data['status']?.toString() ?? 'pending').toLowerCase();
      final String message = data['message']?.toString() ??
          'تم إنشاء حسابك بنجاح وهو الآن قيد المراجعة من قِبل إدارة المنصة.';

      UserModel? user;
      if (data['data'] is Map && (data['data'] as Map)['user'] is Map) {
        user = UserModel.fromLaravelJson(
          Map<String, dynamic>.from((data['data'] as Map)['user'] as Map),
        );
      }

      return AuthResult(
        status: status,
        message: message,
        user: user,
      );
    }

    return const AuthResult(
      status: 'pending',
      message: 'تم إنشاء حسابك بنجاح وهو الآن قيد المراجعة من قِبل إدارة المنصة.',
    );
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
    bool remember = true,
    String? deviceName,
  }) async {
    final formMap = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'remember': remember ? '1' : '0',
      if (deviceName != null && deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
    };

    final formData = FormData.fromMap(formMap);

    try {
      final response = await _apiClient.postMultipart(
        '/auth/login',
        formData: formData,
        options: Options(extra: {'skipAuth': true}),
      );

      return _parseAuthTokenResponse(response.data);
    } on ForbiddenException catch (e) {
      final raw = e.rawResponse;
      if (raw is Map<String, dynamic>) {
        final status = (raw['status']?.toString() ?? 'pending').toLowerCase();
        return AuthResult(
          status: status,
          message: e.message,
        );
      }
      return AuthResult(
        status: 'pending',
        message: e.message,
      );
    }
  }

  @override
  Future<AuthResult> loginWithGoogleToken({
    required String accessToken,
    String? deviceName,
  }) async {
    final formMap = <String, dynamic>{
      'access_token': accessToken.trim(),
      if (deviceName != null && deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
    };

    final formData = FormData.fromMap(formMap);

    try {
      final response = await _apiClient.postMultipart(
        '/auth/google/token',
        formData: formData,
        options: Options(extra: {'skipAuth': true}),
      );

      return _parseAuthTokenResponse(response.data);
    } on ForbiddenException catch (e) {
      final raw = e.rawResponse;
      if (raw is Map<String, dynamic>) {
        final status = (raw['status']?.toString() ?? 'pending').toLowerCase();
        return AuthResult(
          status: status,
          message: e.message,
        );
      }
      return AuthResult(
        status: 'pending',
        message: e.message,
      );
    }
  }

  @override
  Future<AuthResult> loginWithFirebaseIdToken({
    required String idToken,
    bool remember = true,
    String? deviceName,
  }) async {
    final formMap = <String, dynamic>{
      'id_token': idToken.trim(),
      'remember': remember ? '1' : '0',
      if (deviceName != null && deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
    };

    final formData = FormData.fromMap(formMap);

    try {
      final response = await _apiClient.postMultipart(
        '/auth/firebase',
        formData: formData,
        options: Options(extra: {'skipAuth': true}),
      );

      return _parseAuthTokenResponse(response.data);
    } on ForbiddenException catch (e) {
      return AuthResult(
        status: 'pending',
        message: e.message,
      );
    }
  }

  @override
  Future<UserModel> getMe() async {
    final response = await _apiClient.get('/auth/me');
    final data = response.data;

    if (data is Map<String, dynamic>) {
      dynamic userPayload;
      if (data.containsKey('data') && data['data'] is Map && (data['data'] as Map).containsKey('user')) {
        userPayload = (data['data'] as Map)['user'];
      } else if (data.containsKey('data') && data['data'] is Map) {
        userPayload = data['data'];
      } else if (data.containsKey('user') && data['user'] is Map) {
        userPayload = data['user'];
      } else {
        userPayload = data;
      }

      return UserModel.fromLaravelJson(Map<String, dynamic>.from(userPayload as Map));
    }

    throw const ApiException('تعذر فك بيانات المستخدم من الخادم.');
  }

  @override
  Future<void> logout({bool allDevices = false}) async {
    try {
      final formData = FormData.fromMap({
        'all_devices': allDevices ? '1' : '0',
      });
      await _apiClient.postMultipart('/auth/logout', formData: formData);
    } catch (_) {
      // Best-effort logout on the server; client storage will be purged regardless
    }
  }

  @override
  Future<String> forgotPassword({required String email}) async {
    final formData = FormData.fromMap({
      'email': email.trim(),
    });

    final response = await _apiClient.postMultipart(
      '/auth/forgot-password',
      formData: formData,
      options: Options(extra: {'skipAuth': true}),
    );

    final data = response.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'تم إرسال رمز التحقق إلى بريدك الإلكتروني بنجاح.';
  }

  @override
  Future<bool> verifyOtp({required String email, required String otp}) async {
    final formData = FormData.fromMap({
      'email': email.trim(),
      'otp': otp.trim(),
    });

    final response = await _apiClient.postMultipart(
      '/auth/verify-otp',
      formData: formData,
      options: Options(extra: {'skipAuth': true}),
    );

    final data = response.data;
    if (data is Map && data['valid'] != null) {
      return data['valid'] == true;
    }
    return response.statusCode == 200;
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
    String? deviceName,
  }) async {
    final formData = FormData.fromMap({
      'email': email.trim(),
      'otp': otp.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (deviceName != null && deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
    });

    final response = await _apiClient.postMultipart(
      '/auth/reset-password',
      formData: formData,
      options: Options(extra: {'skipAuth': true}),
    );

    final data = response.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'تمت إعادة تعيين كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول.';
  }

  /// Helper to unpack standard Laravel AuthTokenResponse envelopes
  AuthResult _parseAuthTokenResponse(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      throw const ApiException('استجابة غير متوقعة من خادم المصادقة.');
    }

    final String status = (responseData['status']?.toString() ?? 'authenticated').toLowerCase();
    final String? message = responseData['message']?.toString();

    // If account status is pending or suspended
    if (status == 'pending' || status == 'suspended') {
      return AuthResult(
        status: status,
        message: message ??
            (status == 'pending'
                ? 'حسابك قيد المراجعة من قِبل إدارة المنصة.'
                : 'تم تعطيل هذا الحساب.'),
      );
    }

    // Extract payload from either root or nested 'data' map
    final Map<String, dynamic> dataMap = responseData.containsKey('data') && responseData['data'] is Map
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : responseData;

    final String? token = dataMap['token']?.toString();
    final String tokenType = dataMap['token_type']?.toString() ?? 'Bearer';

    UserModel? user;
    if (dataMap.containsKey('user') && dataMap['user'] is Map) {
      user = UserModel.fromLaravelJson(Map<String, dynamic>.from(dataMap['user'] as Map));
    } else if (responseData.containsKey('user') && responseData['user'] is Map) {
      user = UserModel.fromLaravelJson(Map<String, dynamic>.from(responseData['user'] as Map));
    }

    if (user != null && (user.isPending || user.isSuspendedAccount)) {
      return AuthResult(
        status: user.isPending ? 'pending' : 'suspended',
        message: message ??
            (user.isPending
                ? 'حسابك قيد المراجعة من قِبل إدارة المنصة.'
                : 'تم تعطيل هذا الحساب.'),
        user: user,
      );
    }

    return AuthResult(
      status: status,
      token: token,
      tokenType: tokenType,
      message: message,
      user: user,
    );
  }

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.get('/student/settings/profile');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        final innerData = data['data'];
        final userMap = (innerData is Map && innerData['user'] is Map)
            ? innerData['user'] as Map
            : (innerData is Map ? innerData : <String, dynamic>{});
        return UserModel.fromLaravelJson(Map<String, dynamic>.from(userMap));
      }
      throw const ApiException('تعذر جلب بيانات الملف الشخصي.');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? bio,
    String? locale,
    String? avatarFilePath,
  }) async {
    try {
      final map = <String, dynamic>{
        'name': name.trim(),
        'phone': phone.trim(),
      };
      if (email != null && email.trim().isNotEmpty) {
        map['email'] = email.trim();
      }
      if (bio != null) {
        map['bio'] = bio;
      }
      if (locale != null) {
        map['locale'] = locale;
      }
      if (avatarFilePath != null && avatarFilePath.trim().isNotEmpty) {
        map['avatar'] = await MultipartFile.fromFile(avatarFilePath);
      }

      final formData = FormData.fromMap(map);
      final response = await _apiClient.postMultipart(
        '/student/settings/profile',
        formData: formData,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        final innerData = data['data'];
        final userMap = (innerData is Map && innerData['user'] is Map)
            ? innerData['user'] as Map
            : (innerData is Map ? innerData : <String, dynamic>{});
        return UserModel.fromLaravelJson(Map<String, dynamic>.from(userMap));
      }
      return await getMe();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<bool> deleteAccount({required String currentPassword}) async {
    try {
      final response = await _apiClient.delete(
        '/student/settings/profile',
        data: {'current_password': currentPassword},
      );
      final data = response.data;
      return (data is Map<String, dynamic> && data['success'] == true);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      await _apiClient.put(
        '/student/settings/password',
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPasswordConfirmation,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
