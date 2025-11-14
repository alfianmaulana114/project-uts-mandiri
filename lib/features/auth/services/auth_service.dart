import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/supabase_config.dart';

/// Service untuk handle authentication via Supabase Auth REST API
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Token untuk authentication
  String? _accessToken;
  String? _refreshToken;
  String? _userId;

  // Keys untuk SharedPreferences
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'auth_user_id';

  bool _isInitialized = false;

  /// Headers untuk auth requests
  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Content-Type': 'application/json',
      };

  /// Headers dengan authentication token
  Map<String, String> get _authHeaders => {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  /// Getter untuk access token
  String? get accessToken => _accessToken;

  /// Getter untuk user ID
  String? get userId => _userId;

  /// Check apakah user sudah login
  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;

  /// Inisialisasi AuthService - load token dari storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_keyAccessToken);
      _refreshToken = prefs.getString(_keyRefreshToken);
      _userId = prefs.getString(_keyUserId);

      // Verify token masih valid dengan getCurrentUser (non-blocking)
      // Jika token invalid, kita clear tapi tidak block login manual
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        try {
          final user = await getCurrentUser();
          if (user == null) {
            // Token invalid atau expired, clear storage
            print('⚠️ Token invalid or expired, clearing storage');
            await _clearStorage();
            _accessToken = null;
            _refreshToken = null;
            _userId = null;
          } else {
            // Pastikan user_id sudah diupdate dari getCurrentUser
            _userId = user['id'] as String?;
            if (_userId != null) {
              await _saveTokens();
            }
            print('✅ Restored session for user: ${user['email']} (ID: $_userId)');
          }
        } catch (e) {
          // Jika error saat verify, clear token dan biarkan user login manual
          print('⚠️ Error verifying token: $e - Clearing storage');
          await _clearStorage();
          _accessToken = null;
          _refreshToken = null;
          _userId = null;
        }
      }

      _isInitialized = true;
      print('✅ AuthService initialized');
    } catch (e) {
      print('❌ Error initializing AuthService: $e');
      // Clear tokens jika ada error saat initialize
      try {
        await _clearStorage();
        _accessToken = null;
        _refreshToken = null;
        _userId = null;
      } catch (_) {}
      _isInitialized = true; // Set true anyway untuk avoid infinite loop
    }
  }

  /// Save token ke local storage
  Future<void> _saveTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString(_keyAccessToken, _accessToken!);
      }
      if (_refreshToken != null) {
        await prefs.setString(_keyRefreshToken, _refreshToken!);
      }
      if (_userId != null) {
        await prefs.setString(_keyUserId, _userId!);
      }
      print('✅ Tokens saved to storage');
    } catch (e) {
      print('❌ Error saving tokens: $e');
    }
  }

  /// Clear token dari local storage
  Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyUserId);
      print('✅ Tokens cleared from storage');
    } catch (e) {
      print('❌ Error clearing storage: $e');
    }
  }

  /// Register user baru
  /// [email] adalah email user
  /// [password] adalah password user
  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      print('📝 Registering user: $email');
      
      final url = '${SupabaseConfig.supabaseUrl}/auth/v1/signup';
      
      // Supabase signup bisa menggunakan JSON atau URL-encoded
      // Kita gunakan JSON untuk konsistensi
      final body = json.encode({
        'email': email,
        'password': password,
        'data': {}, // Optional user metadata
      });

      print('📤 POST to: $url');
      print('📤 Body: $body');
      
      // Tambahkan timeout 30 detik
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Koneksi timeout. Pastikan koneksi internet stabil.');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Jika email confirmation ON, access_token mungkin null
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        _userId = data['user']?['id'] as String?;
        
        // Check apakah user perlu konfirmasi email
        final user = data['user'] as Map<String, dynamic>?;
        final emailConfirmed = user?['email_confirmed_at'] != null;
        
        print('✅ User registered successfully');
        print('✅ Email confirmed: $emailConfirmed');
        
        if (_accessToken != null) {
          print('✅ Access token available - user can login immediately');
          // Save tokens to storage
          await _saveTokens();
        } else {
          print('⚠️ No access token - user needs to confirm email first');
        }
        
        return {
          'success': true, 
          'user': data,
          'emailConfirmed': emailConfirmed,
          'needsConfirmation': !emailConfirmed && _accessToken == null,
        };
      } else {
        final errorBody = response.body;
        Map<String, dynamic> error;
        
        try {
          error = json.decode(errorBody);
        } catch (e) {
          throw Exception('Registration failed: ${response.statusCode} - $errorBody');
        }
        
        final errorMsg = error['error_description'] ?? error['message'] ?? error['msg'] ?? 'Registration failed';
        print('❌ Register Error: $errorMsg');
        
        // Handle specific errors
        if (errorMsg.toString().toLowerCase().contains('already registered') ||
            errorMsg.toString().toLowerCase().contains('email already exists')) {
          throw Exception('Email sudah terdaftar. Silakan login atau gunakan email lain.');
        }
        
        throw Exception(errorMsg.toString());
      }
    } catch (e) {
      print('❌ Register Exception: $e');
      rethrow;
    }
  }

  /// Login user
  /// [email] adalah email user
  /// [password] adalah password user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔐 Logging in user: $email');
      
      // Clear token lama sebelum login untuk menghindari konflik
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      
      // Supabase Auth API endpoint berbeda - coba kedua format
      // Pertama coba dengan JSON format
      final url = '${SupabaseConfig.supabaseUrl}/auth/v1/token?grant_type=password';
      
      final body = json.encode({
        'email': email,
        'password': password,
      });

      print('📤 POST to: $url');
      print('📤 Body (JSON): {"email":"$email","password":"***"}');
      
      // Tambahkan timeout 30 detik untuk menghindari hang
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Koneksi timeout. Pastikan koneksi internet stabil.');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body length: ${response.body.length} chars');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        _userId = data['user']?['id'] as String?;
        
        // Pastikan token tidak null
        if (_accessToken == null || _accessToken!.isEmpty) {
          throw Exception('Token tidak diterima dari server. Silakan coba lagi.');
        }
        
        // Save tokens to storage untuk persistensi login
        await _saveTokens();
        
        print('✅ User logged in successfully');
        print('✅ User ID: $_userId');
        print('✅ Access token: ${_accessToken?.substring(0, 20)}...');
        return {'success': true, 'user': data};
      } else {
        final errorBody = response.body;
        Map<String, dynamic> error;
        
        try {
          error = json.decode(errorBody);
        } catch (e) {
          print('❌ Failed to parse error response: $errorBody');
          throw Exception('Login gagal dengan status ${response.statusCode}. Silakan cek koneksi internet atau coba lagi.');
        }
        
        final errorMsg = error['error_description'] ?? error['message'] ?? error['error'] ?? 'Login failed';
        print('❌ Login Error: $errorMsg');
        print('❌ Full error: $error');
        
        // Handle specific error cases dengan pesan yang lebih jelas
        final errorLower = errorMsg.toString().toLowerCase();
        if (errorLower.contains('email not confirmed') ||
            errorLower.contains('email not verified') ||
            errorLower.contains('email_not_confirmed')) {
          throw Exception('Email belum dikonfirmasi. Silakan cek email Anda dan klik link konfirmasi. Atau nonaktifkan email confirmation di Supabase dashboard untuk development.');
        } else if (errorLower.contains('invalid login') ||
                   errorLower.contains('invalid credentials') ||
                   errorLower.contains('invalid password') ||
                   errorLower.contains('invalid email')) {
          throw Exception('Email atau password salah. Pastikan:\n- Email sudah dikonfirmasi\n- Password benar\n- Email confirmation sudah OFF di Supabase (untuk development)');
        } else if (errorLower.contains('user not found')) {
          throw Exception('User tidak ditemukan. Silakan daftar terlebih dahulu.');
        }
        
        throw Exception('Login gagal: $errorMsg');
      }
    } catch (e) {
      print('❌ Login Exception: $e');
      // Pastikan token di-clear jika login gagal
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      if (_refreshToken != null) {
        final url = '${SupabaseConfig.supabaseUrl}/auth/v1/logout';
        await http.post(
          Uri.parse(url),
          headers: _authHeaders,
          body: json.encode({'refresh_token': _refreshToken}),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⚠️ Logout timeout');
            throw Exception('Logout timeout');
          },
        );
      }
    } catch (e) {
      print('⚠️ Logout error: $e');
    } finally {
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      // Clear tokens from storage
      await _clearStorage();
      print('✅ User logged out');
    }
  }

  /// Refresh access token menggunakan refresh token
  Future<bool> refreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      print('⚠️ No refresh token available');
      return false;
    }

    try {
      final url = '${SupabaseConfig.supabaseUrl}/auth/v1/token?grant_type=refresh_token';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refresh_token': _refreshToken,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Koneksi timeout saat refresh token.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        
        // Save tokens baru
        await _saveTokens();
        
        print('✅ Token refreshed successfully');
        return true;
      } else {
        print('❌ Refresh token failed: ${response.statusCode} - ${response.body}');
        // Token refresh failed, clear tokens
        _accessToken = null;
        _refreshToken = null;
        _userId = null;
        await _clearStorage();
        return false;
      }
    } catch (e) {
      print('❌ Refresh token exception: $e');
      // Clear tokens jika refresh gagal
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      await _clearStorage();
      return false;
    }
  }

  /// Get current user info
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!isLoggedIn) return null;
    
    try {
      final url = '${SupabaseConfig.supabaseUrl}/auth/v1/user';
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Koneksi timeout saat mengambil data user.');
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body) as Map<String, dynamic>;
        // Update user_id dari response untuk memastikan sesuai dengan token
        _userId = userData['id'] as String?;
        if (_userId != null) {
          await _saveTokens();
        }
        return userData;
      } else if (response.statusCode == 401) {
        // Token expired, coba refresh
        final refreshed = await refreshToken();
        if (refreshed) {
          // Retry dengan token baru
          final retryResponse = await http.get(
            Uri.parse(url),
            headers: _authHeaders,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Koneksi timeout saat retry get user.');
            },
          );
          if (retryResponse.statusCode == 200) {
            final userData = json.decode(retryResponse.body) as Map<String, dynamic>;
            // Update user_id dari response
            _userId = userData['id'] as String?;
            if (_userId != null) {
              await _saveTokens();
            }
            return userData;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Get user error: $e');
      return null;
    }
  }
}

