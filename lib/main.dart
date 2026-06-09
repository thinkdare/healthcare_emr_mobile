import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart' show BuildContext, CircularProgressIndicator, MaterialApp, MaterialPageRoute, Navigator, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config/app_config.dart';
import 'core/api/api_client.dart';
import 'core/database/local_database.dart';
import 'core/platform.dart';
import 'data/repositories/access_grant_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/clinical_repository.dart';
import 'data/repositories/emergency_access_repository.dart';
import 'data/repositories/organization_repository.dart';
import 'data/repositories/patient_repository.dart';
import 'data/repositories/reporting_repository.dart';
import 'data/repositories/subscription_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'data/repositories/referral_repository.dart';
import 'data/providers/access_grant_provider.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/clinical_provider.dart';
import 'data/providers/emergency_access_provider.dart';
import 'data/providers/organization_provider.dart';
import 'data/providers/patient_provider.dart';
import 'data/providers/reporting_provider.dart';
import 'data/providers/subscription_provider.dart';
import 'data/providers/sync_provider.dart';
import 'data/providers/referral_provider.dart';
import 'core/biometric/biometric_provider.dart';
import 'core/biometric/biometric_service.dart';
import 'core/security/root_detection_provider.dart';
import 'core/notifications/push_notification_service.dart';
import 'data/providers/intra_grant_provider.dart';
import 'data/providers/intra_transfer_provider.dart';
import 'data/repositories/device_token_repository.dart';
import 'data/repositories/intra_grant_repository.dart';
import 'data/repositories/intra_transfer_repository.dart';
import 'presentation/shell/android_shell.dart';
import 'presentation/shell/clinical_web_shell.dart';
import 'presentation/shell/ios_shell.dart';
import 'presentation/shell/org_admin_web_shell.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/auth/screens/register_provider_screen.dart';
import 'presentation/subscription/screens/payment_return_screen.dart';

// Singleton shared between main() and _MyAppState~
final pushNotificationService = PushNotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && !Platform.isIOS && !Platform.isAndroid) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  AppConfig.printConfig();

  // Warm up SQLite so the first screen doesn't stutter
  await LocalDatabase.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _lifecycleListener;
  late final AppLinks _appLinks;
  DeviceTokenRepository? _deviceTokenRepo;
  StreamSubscription<Uri>? _deepLinkSub;
  StreamSubscription<Map<String, dynamic>>? _notifTapSub;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();

    // Initialize Firebase/FCM after runApp so the permission dialog can
    // be shown and method channel callbacks can be received.
    pushNotificationService.initialize().then((_) {
      if (mounted) _initPushNotifications();
    });

    _lifecycleListener = AppLifecycleListener(
      onInactive: () {
        // Record when the app left the foreground for lock-threshold calculation
        try { context.read<BiometricProvider>().recordBackground(); } catch (_) {}
      },
      onResume: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try { context.read<SyncProvider>().sync(); } catch (_) {}
          try { context.read<BiometricProvider>().checkResumeLock(); } catch (_) {}
        });
      },
    );

    // Lock on cold start if biometric is enabled and user is already authenticated.
    // We post-frame so the provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try { context.read<BiometricProvider>().lockIfEnabled(); } catch (_) {}
      }
    });

    _initDeepLinks();
  }

  void _initPushNotifications() {
    if (!pushNotificationService.isInitialized) return;

    // Register token when it refreshes
    _tokenRefreshSub = pushNotificationService.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    // Register the current token on init (best-effort, may be null before login)
    pushNotificationService.getToken().then((token) {
      if (token != null && mounted) _registerToken(token);
    });

    // Route notification taps to the relevant screen
    _notifTapSub = pushNotificationService.onNotificationTap.listen((data) {
      _routeNotification(data);
    });
  }

  void _registerToken(String token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final auth = context.read<AuthProvider>();
        if (!auth.isAuthenticated) return;
        _deviceTokenRepo?.register(token);
      } catch (_) {}
    });
  }

  void _routeNotification(Map<String, dynamic> data) {
    // Notification taps bring the app to the foreground automatically.
    // Detailed in-app routing (e.g. open AccessGrantsScreen) is handled by
    // the individual screens watching their providers for badge counts.
    // The notification type is available in `data['type']` for future routing.
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (_) {}, // ignore link errors silently
    );
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'voya') return;

    // voya://staff/register?token=<invitation_token>
    if (uri.host == 'staff' && uri.pathSegments.firstOrNull == 'register') {
      final token = uri.queryParameters['token'];
      if (token == null || token.isEmpty) return;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        kIsIOS
            ? CupertinoPageRoute<void>(
                builder: (_) => RegisterProviderScreen(initialToken: token))
            : MaterialPageRoute<void>(
                builder: (_) => RegisterProviderScreen(initialToken: token)),
      );
      return;
    }

    // voya://payment/return
    if (uri.host != 'payment') return;

    const validStatuses = {'success', 'cancelled', 'pending', 'failed', 'unknown'};
    const validGateways = {'paystack', 'stripe', 'flutterwave'};

    final status  = uri.queryParameters['status'] ?? 'unknown';
    final gateway = uri.queryParameters['gateway'];

    if (!validStatuses.contains(status)) return;
    if (gateway != null && !validGateways.contains(gateway)) return;

    final reference = uri.queryParameters['reference'];
    final txId      = uri.queryParameters['transaction_id'];
    final sessionId = uri.queryParameters['session_id'];

    if (!mounted) return;

    final screen = PaymentReturnScreen(
      status:        status,
      reference:     reference,
      gateway:       gateway,
      transactionId: txId,
      sessionId:     sessionId,
    );

    Navigator.of(context, rootNavigator: true).push(
      kIsIOS
          ? CupertinoPageRoute<void>(builder: (_) => screen)
          : MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _deepLinkSub?.cancel();
    _notifTapSub?.cancel();
    _tokenRefreshSub?.cancel();
    pushNotificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiClient     = ApiClient();
    final localDatabase = LocalDatabase.instance;

    final authRepository         = AuthRepository(apiClient: apiClient);
    final organizationRepository = OrganizationRepository(apiClient: apiClient);
    final patientRepository      = PatientRepository(
      apiClient: apiClient,
      localDatabase: localDatabase,
    );
    final subscriptionRepository    = SubscriptionRepository(apiClient: apiClient);
    final clinicalRepository        = ClinicalRepository(apiClient: apiClient);
    final accessGrantRepository     = AccessGrantRepository(apiClient: apiClient);
    final emergencyAccessRepository = EmergencyAccessRepository(apiClient: apiClient);
    final reportingRepository       = ReportingRepository(apiClient: apiClient);
    final syncRepository            = SyncRepository(apiClient: apiClient);
    final referralRepository        = ReferralRepository(apiClient: apiClient);
    final intraGrantRepository      = IntraGrantRepository(apiClient: apiClient);
    final intraTransferRepository   = IntraTransferRepository(apiClient: apiClient);
    final deviceTokenRepository     = DeviceTokenRepository(apiClient: apiClient);
    _deviceTokenRepo                = deviceTokenRepository; // for push token registration
    final biometricService          = BiometricService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(repository: authRepository)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              OrganizationProvider(repository: organizationRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => PatientProvider(repository: patientRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              SubscriptionProvider(repository: subscriptionRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ClinicalProvider(repository: clinicalRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AccessGrantProvider(repository: accessGrantRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => EmergencyAccessProvider(
              repository: emergencyAccessRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ReportingProvider(repository: reportingRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => SyncProvider(repository: syncRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ReferralProvider(repository: referralRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => IntraGrantProvider(repository: intraGrantRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => IntraTransferProvider(repository: intraTransferRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => BiometricProvider(service: biometricService),
        ),
        ChangeNotifierProvider(
          create: (_) => RootDetectionProvider(),
        ),
      ],
      // Platform branch: web → OrgAdminWebShell or ClinicalWebShell (by role)
      // iOS → IOSShell (branches internally on isOrgAdmin)
      // Android → AndroidShell (branches internally on isOrgAdmin)
      child: kIsWeb
          ? const _WebRoot()
          : kIsIOS
              ? const IOSShell()
              : const AndroidShell(),
    );
  }
}

/// Web root — MaterialApp with auth wrapper.
/// Org admins → OrgAdminWebShell. Clinical staff → ClinicalWebShell.
class _WebRoot extends StatelessWidget {
  const _WebRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthcare EMR',
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!auth.isAuthenticated) return const LoginScreen();
          if (auth.isOrgAdmin) return const OrgAdminWebShell();
          return const ClinicalWebShell();
        },
      ),
    );
  }
}