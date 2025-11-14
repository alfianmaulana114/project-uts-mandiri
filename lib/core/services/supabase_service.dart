import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../../features/auth/services/auth_service.dart';

/// Service untuk berkomunikasi dengan Supabase REST API
/// Menggunakan HTTP requests langsung (tanpa package khusus)
class SupabaseService {
  final AuthService _authService = AuthService();
  
  /// Headers yang diperlukan untuk semua request ke Supabase
  /// Menggunakan access token dari AuthService jika user sudah login
  Map<String, String> get _headers {
    final accessToken = _authService.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      // Gunakan access token untuk authenticated requests
      return {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation', // Supabase akan return data setelah insert/update
      };
    } else {
      // Fallback ke anon key jika belum login
      return {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };
    }
  }

  /// GET request - Mengambil data dari table
  /// [url] adalah endpoint Supabase (misalnya: todosUrl)
  /// [filters] adalah query parameters untuk filter (misalnya: {'user_id': 'eq.123'})
  Future<List<Map<String, dynamic>>> get(
    String url, {
    Map<String, String>? filters,
  }) async {
    try {
      Uri uri = Uri.parse(url);
      if (filters != null && filters.isNotEmpty) {
        // Build query string untuk Supabase PostgREST syntax
        final queryParams = <String, String>{};
        filters.forEach((key, value) {
          // Supabase menggunakan format: ?column=operator.value
          // Contoh: ?user_id=eq.123 atau ?id=eq.abc
          queryParams[key] = value;
        });
        uri = uri.replace(queryParameters: queryParams);
      }

      print('📥 GET from: $uri');
      final response = await http.get(uri, headers: _headers);
      print('📥 GET Response status: ${response.statusCode}');
      print('📥 GET Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('⚠️ Response body is empty');
          return [];
        }
        final decoded = json.decode(response.body);
        print('📥 Decoded type: ${decoded.runtimeType}');
        
        if (decoded is List) {
          print('✅ Decoded is List with ${decoded.length} items');
          if (decoded.isNotEmpty) {
            print('📥 First item: ${decoded.first}');
          }
          return decoded.map((item) => item as Map<String, dynamic>).toList();
        }
        print('⚠️ Decoded is not a List, returning empty');
        return [];
      } else {
        print('❌ Supabase GET Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Supabase GET Exception: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  /// POST request - Menambahkan data baru
  /// [url] adalah endpoint Supabase
  /// [data] adalah data yang akan di-insert (dalam bentuk Map)
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> data) async {
    try {
      // Remove null values untuk menghindari error dari Supabase
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.removeWhere((key, value) => value == null);
      
      print('📤 POST to: $url');
      print('📤 Headers: ${_headers.keys.toList()}');
      print('📤 Has access token: ${_authService.accessToken != null}');
      print('📤 Data: ${json.encode(cleanData)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(cleanData),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout saat menyimpan data.');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final decoded = json.decode(response.body);
          if (decoded is List && decoded.isNotEmpty) {
            return decoded.first as Map<String, dynamic>;
          } else if (decoded is Map) {
            return decoded as Map<String, dynamic>;
          }
        }
        return cleanData;
      } else {
        final errorBody = response.body;
        print('❌ Supabase POST Error: ${response.statusCode}');
        print('❌ Error body: $errorBody');
        
        // Parse error untuk pesan yang lebih jelas
        try {
          final errorJson = json.decode(errorBody);
          final errorMsg = errorJson['message'] ?? errorBody;
          final errorCode = errorJson['code'] ?? '';
          
          if (errorCode == '42501' || errorMsg.toString().contains('row-level security')) {
            final userId = _authService.userId;
            final hasToken = _authService.accessToken != null;
            throw Exception('Gagal menyimpan: Policy keamanan Supabase belum dikonfigurasi dengan benar.\n\n'
                'Pastikan:\n'
                '1. Jalankan SQL script ADD_USER_ID_COLUMN.sql di Supabase SQL Editor\n'
                '2. Kolom user_id sudah ditambahkan ke semua tabel\n'
                '3. RLS policies sudah diaktifkan dan dikonfigurasi dengan benar\n'
                '4. Logout dan login kembali di aplikasi\n\n'
                'Debug info:\n'
                '- User ID: ${userId ?? "null"}\n'
                '- Has token: $hasToken');
          }
          
          throw Exception('Gagal menyimpan data: $errorMsg');
        } catch (e) {
          if (e.toString().contains('Policy keamanan') || e.toString().contains('row-level security')) {
            rethrow;
          }
          throw Exception('Gagal menyimpan data: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('❌ Supabase POST Exception: $e');
      rethrow;
    }
  }

  /// PATCH request - Update data
  /// [url] adalah endpoint Supabase dengan id di query (misalnya: todosUrl?id=eq.123)
  /// [data] adalah data yang akan di-update
  Future<List<Map<String, dynamic>>> patch(
    String url,
    Map<String, dynamic> data,
  ) async {
    try {
      // Remove null values untuk menghindari error dari Supabase
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.removeWhere((key, value) => value == null);
      
      final response = await http.patch(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(cleanData),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) {
          return [cleanData]; // Return data yang di-update jika Supabase tidak return
        }
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((item) => item as Map<String, dynamic>).toList();
        } else if (decoded is Map) {
          return [decoded as Map<String, dynamic>];
        }
        return [cleanData];
      } else {
        final errorBody = response.body;
        print('❌ Supabase PATCH Error: ${response.statusCode} - $errorBody');
        throw Exception('Failed to update data: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('❌ Supabase PATCH Exception: $e');
      rethrow;
    }
  }

  /// DELETE request - Menghapus data
  /// [url] adalah endpoint Supabase dengan id di query (misalnya: todosUrl?id=eq.123)
  Future<void> delete(String url) async {
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting data: $e');
    }
  }
}
