import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

// Provide at build time:
//   flutter build apk --dart-define TLS_CERT_PEM_B64=<base64(cert.pem)>
//
// For rotation resilience, pin your intermediate CA cert (e.g. Let's Encrypt R10)
// rather than the leaf cert. The base64 value is: base64 -w0 intermediate-ca.pem
//
// Absent or empty → no pinning (safe for dev; CI must provide the value for
// production builds).
const _kPinnedCertPemB64 = String.fromEnvironment('TLS_CERT_PEM_B64');

/// Applies TLS certificate pinning to [dio] on mobile/desktop release builds.
///
/// When [_kPinnedCertPemB64] is compiled in, the client trusts ONLY that
/// certificate (or CA chain). Any other cert — including a compromised CA —
/// will be rejected with a handshake error, preventing MITM.
///
/// No-ops in three safe cases: web builds (no dart:io HttpClient), debug
/// mode, and when the env var is absent (dev / CI without the secret).
void applyTlsPinning(Dio dio) {
  if (kIsWeb) return;
  if (kDebugMode) return;
  if (_kPinnedCertPemB64.isEmpty) return;

  final pemBytes = base64.decode(_kPinnedCertPemB64);

  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final sc = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(pemBytes);
    return HttpClient(context: sc);
  };
}
