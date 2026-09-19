import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'screens/login_screen.dart';
import 'widgets/shell_scaffold.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.loadSession();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACTIV Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00B892),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF0F1E2E), elevation: 0, surfaceTintColor: Colors.white),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)), side: BorderSide(color: Color(0xFFE4E9EF)))),
      ),
      home: ApiClient.isLoggedIn ? const ShellScaffold(body: DashboardScreen()) : const LoginScreen(),
    );
  }
}