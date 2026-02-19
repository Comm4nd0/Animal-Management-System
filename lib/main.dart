import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'services/animal_provider.dart';
import 'utils/app_theme.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
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
import 'screens/custom_fields/custom_fields_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PedigreeManagerApp());
}

class PedigreeManagerApp extends StatelessWidget {
  const PedigreeManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnimalProvider()..loadAll(),
      child: MaterialApp(
        title: 'Pedigree Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        // Web: start on the public landing page
        // Mobile: start on the login screen
        initialRoute: kIsWeb ? '/' : '/login',
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ─── Public routes ────────────────────────────────────────
      case '/':
        // Web landing page; on mobile, redirect to login
        return MaterialPageRoute(
          builder: (_) =>
              kIsWeb ? const LandingScreen() : const LoginScreen(),
        );
      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case '/register':
        return MaterialPageRoute(
          builder: (_) => const RegistrationScreen(),
        );

      // ─── Authenticated routes (dashboard) ─────────────────────
      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case '/account':
        final profile = settings.arguments as UserProfile;
        return MaterialPageRoute(
          builder: (_) => AccountScreen(profile: profile),
        );
      case '/animals':
        return MaterialPageRoute(
          builder: (_) => const AnimalListScreen(),
        );
      case '/animal/detail':
        final animalId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => AnimalDetailScreen(animalId: animalId),
        );
      case '/animal/add':
        return MaterialPageRoute(
          builder: (_) => const AnimalFormScreen(),
        );
      case '/animal/edit':
        final animalId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => AnimalFormScreen(animalId: animalId),
        );
      case '/pedigree':
        final animalId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => PedigreeScreen(animalId: animalId),
        );
      case '/breeding':
        return MaterialPageRoute(
          builder: (_) => const BreedingScreen(),
        );
      case '/breeding/suggestions':
        final animalId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BreedingScreen(selectedAnimalId: animalId),
        );
      case '/health':
        final animalId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => HealthRecordsScreen(animalId: animalId),
        );
      case '/litters':
        return MaterialPageRoute(
          builder: (_) => const LitterListScreen(),
        );
      case '/custom-fields':
        return MaterialPageRoute(
          builder: (_) => const CustomFieldsScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              kIsWeb ? const LandingScreen() : const LoginScreen(),
        );
    }
  }
}
