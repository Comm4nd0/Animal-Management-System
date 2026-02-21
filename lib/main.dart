import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'services/animal_provider.dart';
import 'utils/app_theme.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/animals/animal_list_screen.dart';
import 'screens/animals/animal_detail_screen.dart';
import 'screens/animals/animal_form_screen.dart';
import 'screens/pedigree/pedigree_screen.dart';
import 'screens/breeding/breeding_screen.dart';
import 'screens/health/health_records_screen.dart';
import 'screens/litters/litter_list_screen.dart';
import 'screens/account/registration_screen.dart';
import 'screens/account/account_screen.dart';
import 'screens/account/user_management_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/genetics/coi_calculator_screen.dart';
import 'screens/genetics/stud_matcher_screen.dart';
import 'screens/data_audit/data_audit_screen.dart';
import 'screens/import_export/import_screen.dart';
import 'screens/import_export/export_screen.dart';
import 'screens/custom_fields/custom_fields_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/support/support_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use clean path URLs (no # fragment) on the web
  usePathUrlStrategy();

  // Initialize local notifications (no-op on web)
  try {
    await NotificationService().initialize();
  } catch (_) {
    // Notifications not available on this platform
  }

  runApp(const PedigreeManagerApp());
}

class PedigreeManagerApp extends StatelessWidget {
  const PedigreeManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnimalProvider()..loadAll(),
      child: Consumer<AnimalProvider>(
        builder: (context, provider, _) => MaterialApp(
          title: 'Pedigree Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.themeMode,
          // Web: start on the public landing page
          // Mobile: start on the login screen
          initialRoute: kIsWeb ? '/' : '/login',
          onGenerateRoute: _generateRoute,
        ),
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;

    // ─── Static routes ──────────────────────────────────────────
    // Try exact match first for routes without dynamic segments.
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              kIsWeb ? const LandingScreen() : const LoginScreen(),
        );
      case '/login':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case '/register':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RegistrationScreen(),
        );
      case '/forgot-password':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ForgotPasswordScreen(),
        );
      case '/reset-password':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResetPasswordScreen(),
        );
      case '/dashboard':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
      case '/account':
        final profile = settings.arguments as UserProfile;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AccountScreen(profile: profile),
        );
      case '/team':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const UserManagementScreen(),
        );
      case '/animals':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AnimalListScreen(),
        );
      case '/animals/new':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AnimalFormScreen(),
        );
      case '/breeding':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BreedingScreen(),
        );
      case '/litters':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LitterListScreen(),
        );
      case '/contacts':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ContactsScreen(),
        );
      case '/coi-calculator':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CoiCalculatorScreen(),
        );
      case '/stud-matcher':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudMatcherScreen(),
        );
      case '/custom-fields':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CustomFieldsScreen(),
        );
      case '/data-audit':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DataAuditScreen(),
        );
      case '/import':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ImportScreen(),
        );
      case '/export':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ExportScreen(),
        );
      case '/settings':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case '/support':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SupportScreen(),
        );
    }

    // ─── Dynamic routes (path contains an ID) ───────────────────
    // /animals/{id}       → animal detail
    // /animals/{id}/edit  → animal edit form
    // /pedigree/{id}      → pedigree tree
    // /health/{id}        → health records
    // /breeding/{id}      → breeding suggestions for animal
    // /stud-matcher/{id}  → stud matcher with preselected stud
    if (segments.length == 2 && segments[0] == 'animals' && segments[1] != 'new') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => AnimalDetailScreen(animalId: segments[1]),
      );
    }

    if (segments.length == 3 && segments[0] == 'animals' && segments[2] == 'edit') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => AnimalFormScreen(animalId: segments[1]),
      );
    }

    if (segments.length == 2 && segments[0] == 'pedigree') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => PedigreeScreen(animalId: segments[1]),
      );
    }

    if (segments.length == 2 && segments[0] == 'health') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => HealthRecordsScreen(animalId: segments[1]),
      );
    }

    if (segments.length == 2 && segments[0] == 'breeding') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => BreedingScreen(selectedAnimalId: segments[1]),
      );
    }

    if (segments.length == 2 && segments[0] == 'stud-matcher') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => StudMatcherScreen(preselectedStudId: segments[1]),
      );
    }

    // ─── Fallback ───────────────────────────────────────────────
    return MaterialPageRoute(
      settings: settings,
      builder: (_) =>
          kIsWeb ? const LandingScreen() : const LoginScreen(),
    );
  }
}
