import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'core/api/api_client.dart';
import 'core/database/local_database.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/organization_repository.dart';
import 'data/repositories/patient_repository.dart';         // Phase 2
import 'data/repositories/subscription_repository.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/organization_provider.dart';
import 'data/providers/patient_provider.dart';              // Phase 2
import 'data/providers/subscription_provider.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/dashboard/screens/provider_dashboard_screen.dart';

void main() async {
  // Required before any async work in main()
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.printConfig();

  // Phase 2: Warm up the SQLite database so the first screen doesn't stutter
  await LocalDatabase.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared infrastructure
    final apiClient = ApiClient();
    final localDatabase = LocalDatabase.instance;

    // Repositories
    final authRepository = AuthRepository(apiClient: apiClient);
    final organizationRepository =
        OrganizationRepository(apiClient: apiClient);
    final patientRepository = PatientRepository(       // Phase 2
      apiClient: apiClient,
      localDatabase: localDatabase,
    );
    final subscriptionRepository =
        SubscriptionRepository(apiClient: apiClient);

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
        // Phase 2: Patient state management
        ChangeNotifierProvider(
          create: (_) => PatientProvider(repository: patientRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              SubscriptionProvider(repository: subscriptionRepository),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isAuthenticated
            ? const ProviderDashboardScreen()
            : const LoginScreen();
      },
    );
  }
}