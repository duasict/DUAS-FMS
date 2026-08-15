import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database_helper.dart';
import 'providers/app_provider.dart';
import 'providers/org_settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded(_boot, (error, stack) {
    debugPrint('[main] Uncaught zone error: $error\n$stack');
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  String? startupError;

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[main] Supabase init failed: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('[main] Notification init failed: $e');
  }

  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    startupError = e.toString();
    debugPrint('[main] Database init failed: $e');
  }

  runApp(startupError != null ? _ErrorApp(startupError) : const _FmsApp());
}

/// Shown only when the database cannot be initialised (e.g. Keystore failure).
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 56),
                const SizedBox(height: 24),
                const Text(
                  'Unable to start FMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'The app could not initialise its secure database on this device.\n\n'
                  'Try clearing app data (Settings → Apps → FMS → Clear Data) and '
                  'reopening the app.',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FmsApp extends StatelessWidget {
  const _FmsApp();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrgSettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => AppProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..load()),
      ],
      child: const FmsApp(),
    );
  }
}

class FmsApp extends StatelessWidget {
  const FmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode    = context.watch<ThemeProvider>().mode;
    final primaryColor = context.watch<OrgSettingsProvider>().primaryColor;
    return MaterialApp(
      title: 'FMS',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.lightTheme(primaryColor),
      darkTheme: AppTheme.darkTheme(primaryColor),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
