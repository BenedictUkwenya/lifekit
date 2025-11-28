import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider package
import 'package:flutter_stripe/flutter_stripe.dart';
// Import the Cart Provider logic we created
import 'core/providers/cart_provider.dart';

// Import your Splash Screen
import 'features/onboarding/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey =
      "pk_test_51SW1114GlwNcKAYEd8fCjAcBf8rzZxRCCsdMW3pyrnSUceIIXlLpPbbp5n1mhQ7zVRM9nyNDjLbr56ElkYZ2YQNs00rZwbUIGV";
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
