import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class IpInfo {
  final String ip;
  final String networkType;
  final String devicePlatform;
  final DateTime fetchedAt;

  const IpInfo({
    required this.ip,
    required this.networkType,
    required this.devicePlatform,
    required this.fetchedAt,
  });

  bool get isExpired => DateTime.now().difference(fetchedAt).inMinutes > 30;

  Map<String, dynamic> toMap() => {
        'ip': ip,
        'networkType': networkType,
        'devicePlatform': devicePlatform,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}

/// Service to resolve client IP, network connection, and platform information
class IpService {
  static final IpService _instance = IpService._internal();
  factory IpService() => _instance;
  IpService._internal();

  IpInfo? _cachedInfo;
  Future<IpInfo>? _inFlight;

  Future<IpInfo> getClientIpInfo() {
    if (_cachedInfo != null && !_cachedInfo!.isExpired) {
      return Future.value(_cachedInfo);
    }
    if (_inFlight != null) return _inFlight!;

    final future = _fetchIpInfo();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<IpInfo> _fetchIpInfo() async {
    String resolvedIp = '0.0.0.0';

    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        resolvedIp = (data['ip'] as String?)?.trim() ?? resolvedIp;
      }
    } catch (_) {
      try {
        final fallback = await http
            .get(Uri.parse('https://api64.ipify.org?format=json'))
            .timeout(const Duration(seconds: 4));
        if (fallback.statusCode == 200) {
          final data = jsonDecode(fallback.body);
          resolvedIp = (data['ip'] as String?)?.trim() ?? resolvedIp;
        }
      } catch (_) {
        resolvedIp = 'محلي / غير متوفر';
      }
    }

    String networkType = 'غير محدد';
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        networkType = 'WiFi';
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        networkType = 'بيانات الهاتف (4G/5G)';
      } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        networkType = 'شبكة سلكية (LAN)';
      }
    } catch (_) {}

    String platformDesc = 'جهاز ذكي';
    try {
      if (Platform.isAndroid) {
        platformDesc = 'Android';
      } else if (Platform.isIOS) {
        platformDesc = 'iOS';
      } else if (Platform.isWindows) {
        platformDesc = 'Windows';
      }
    } catch (_) {}

    final info = IpInfo(
      ip: resolvedIp,
      networkType: networkType,
      devicePlatform: platformDesc,
      fetchedAt: DateTime.now(),
    );

    _cachedInfo = info;
    return info;
  }
}

