import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../api/api_client.dart';

/// The server's answer to a sync request, whatever its status.
class TransportResponse {
  final int status;
  final Map<String, dynamic>? json;
  const TransportResponse(this.status, this.json);

  bool get ok => status >= 200 && status < 300;

  /// The `error.code` of a Laravel error body, when present.
  String? get errorCode => (json?['error'] as Map?)?['code'] as String?;

  String get message => (json?['message'] as String?) ?? 'HTTP $status';
}

/// No usable network (no route, DNS failure, timeout). Distinct from an HTTP
/// error: the request may or may not have reached the server, so a push must be
/// retried with the same bytes.
class TransportUnavailable implements Exception {
  final String reason;
  const TransportUnavailable(this.reason);

  @override
  String toString() => 'TransportUnavailable($reason)';
}

/// The only seam between the sync engine and HTTP. Everything above it is
/// plain Dart that can be driven by a fake server in tests.
abstract class SyncTransport {
  Future<TransportResponse> register(String clientId, {String? appVersion, String? platform});

  /// [rawBody] is sent byte for byte.
  Future<TransportResponse> push(String rawBody);

  Future<TransportResponse> pull({
    required String clientId,
    required int cursor,
    required int limit,
    required List<String> ackRemoved,
  });
}

class ApiSyncTransport implements SyncTransport {
  final ApiClient _api;
  ApiSyncTransport(this._api);

  @override
  Future<TransportResponse> register(String clientId, {String? appVersion, String? platform}) {
    final body = '{"client_id":"$clientId","device_type":"mobile"'
        '${platform != null ? ',"platform":"$platform"' : ''}'
        '${appVersion != null ? ',"app_version":"$appVersion"' : ''}}';
    return _send('POST', '/sync/register', body: body);
  }

  @override
  Future<TransportResponse> push(String rawBody) => _send('POST', '/sync/push', body: rawBody);

  @override
  Future<TransportResponse> pull({
    required String clientId,
    required int cursor,
    required int limit,
    required List<String> ackRemoved,
  }) {
    return _send('GET', '/sync/pull', query: {
      'client_id': clientId,
      'cursor': cursor,
      'limit': limit,
      if (ackRemoved.isNotEmpty) 'ack_removed': ackRemoved,
    });
  }

  Future<TransportResponse> _send(String method, String path, {String? body, Map<String, dynamic>? query}) async {
    try {
      final r = await _api.sendRaw(method, path, body: body, queryParameters: query);
      return TransportResponse(r.statusCode, r.json);
    } on DioException catch (e) {
      throw TransportUnavailable(e.type.name);
    } on SocketException catch (e) {
      throw TransportUnavailable(e.message);
    }
  }
}
