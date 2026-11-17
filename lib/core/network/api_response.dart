/// Generic typed wrapper for Laravel REST API responses.
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? links;
  final Map<String, dynamic>? rawJson;

  const ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.meta,
    this.links,
    this.rawJson,
  });

  /// Factory to parse standard or customized Laravel envelopes.
  factory ApiResponse.fromJson(
    dynamic json, {
    T Function(dynamic data)? fromDataJson,
    bool isSuccess = true,
  }) {
    if (json is Map<String, dynamic>) {
      final bool inferredSuccess = json.containsKey('success')
          ? (json['success'] == true || json['success'] == 1)
          : isSuccess;

      final String? message = json['message'] as String?;

      final Map<String, dynamic>? meta = json['meta'] is Map<String, dynamic>
          ? json['meta'] as Map<String, dynamic>
          : null;

      final Map<String, dynamic>? links = json['links'] is Map<String, dynamic>
          ? json['links'] as Map<String, dynamic>
          : null;

      dynamic payload;
      if (json.containsKey('data')) {
        payload = json['data'];
      } else {
        // If there's no "data" key, the whole map may represent the payload
        // (excluding known metadata keys like message, success, errors)
        payload = json;
      }

      T? parsedData;
      if (payload != null) {
        if (fromDataJson != null) {
          parsedData = fromDataJson(payload);
        } else if (payload is T) {
          parsedData = payload;
        }
      }

      return ApiResponse<T>(
        success: inferredSuccess,
        message: message,
        data: parsedData,
        meta: meta,
        links: links,
        rawJson: json,
      );
    } else if (json is List) {
      T? parsedData;
      if (fromDataJson != null) {
        parsedData = fromDataJson(json);
      } else if (json is T) {
        parsedData = json as T;
      }

      return ApiResponse<T>(
        success: isSuccess,
        data: parsedData,
      );
    }

    return ApiResponse<T>(
      success: isSuccess,
      data: json is T ? json : null,
    );
  }

  /// Helper getter to check if response contains valid data
  bool get hasData => data != null;

  @override
  String toString() => 'ApiResponse(success: $success, message: $message, data: $data)';
}
