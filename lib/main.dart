import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 1. Import foundation to access kIsWeb
import 'package:flutter/foundation.dart';

// Import the Cart Provider logic we created
import 'core/providers/cart_provider.dart';

// Import your Splash Screen
import 'features/onboarding/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY');
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // 2. Wrap Stripe initialization in a check
  // This ensures it only runs on Android/iOS and skips it on Web (preventing the crash)
  if (!kIsWeb) {
    Stripe.publishableKey =
        "pk_test_51SW1114GlwNcKAYEd8fCjAcBf8rzZxRCCsdMW3pyrnSUceIIXlLpPbbp5n1mhQ7zVRM9nyNDjLbr56ElkYZ2YQNs00rZwbUIGV";
  }

  runApp(
    // WRAP THE APP IN MULTI-PROVIDER
    // This enables the "Cart" state to live globally
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CartProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeKit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
        // This ensures the iOS-style Time Picker looks correct on Android
        // Uses your primary Maroon color (#89273B)
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF89273B)),
      ),
      home: const SplashScreen(),
    );
  }
}
