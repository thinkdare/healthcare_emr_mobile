import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'data/providers/access_grant_provider.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/clinical_provider.dart';
import 'data/providers/emergency_access_provider.dart';
import 'data/providers/organization_provider.dart';
import 'data/providers/patient_provider.dart';
import 'data/providers/reporting_provider.dart';
import 'data/providers/subscription_provider.dart';
import 'data/providers/sync_provider.dart';
import 'presentation/shell/android_shell.dart';
import 'presentation/shell/ios_shell.dart';

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

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Trigger sync each time the app returns to foreground
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              context.read<SyncProvider>().sync();
            } catch (_) {
              // SyncProvider may not yet be in context at first launch
            }
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
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
      ],
      // Platform branch: CupertinoApp on iOS, MaterialApp on Android.
      // Both shells read from the same MultiProvider tree above.
      child: kIsIOS ? const IOSShell() : const AndroidShell(),
    );
  }
}
