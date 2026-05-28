// lib/data/repositories/device_token_repository.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/api/api_client.dart';

class DeviceTokenRepository {
  final ApiClient apiClient;

  DeviceTokenRepository({required this.apiClient});

  String get _platform {
    if (kIsWeb) return 'web';
    if (!kIsWeb && Platform.isIOS) return 'ios';
    return 'android';
  }

  Future<void> register(String token, {String? deviceName}) async {
    try {
      await apiClient.post('/auth/device-token', data: {
        'token':       token,
        'platform':    _platform,
        'device_name': ?deviceName,
      });
    } catch (_) {
      // Token registration failures are non-fatal — app works without push
    }
  }

  Future<void> unregister(String token) async {
    try {
      await apiClient.delete('/auth/device-token', data: {'token': token});
    } catch (_) {}
  }
}
