import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/di/repository_provider.dart';
import 'core/services/notification_service.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';

/// Fungsi utama aplikasi
/// Menjalankan aplikasi Flutter dengan tema dark
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi data locale untuk intl (Bahasa Indonesia)
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';
  
  // Inisialisasi Notification Service
  await NotificationService().initialize();
  
  // Inisialisasi repository provider
  RepositoryProvider().init();
  
  // Inisialisasi AuthService dan load saved session
  await AuthService().initialize();
  
  runApp(const MyApp());
}

/// Widget utama aplikasi
/// Mengatur tema dan halaman awal aplikasi berdasarkan auth state
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return MaterialApp(
      title: 'Pengelolaan Tugas & Cuaca',
      // Menggunakan tema dark mirip Notion (paksa gelap saja)
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      // Menghilangkan banner debug di pojok kanan atas
      debugShowCheckedModeBanner: false,
      // Menampilkan LoginScreen jika belum login, HomeScreen jika sudah login
      home: authService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
