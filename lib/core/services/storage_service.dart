import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../features/auth/services/auth_service.dart';
import '../config/supabase_config.dart';

/// Service untuk upload file ke Supabase Storage
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _authService = AuthService();

  /// Upload file ke Supabase Storage
  /// [file] adalah path file lokal atau bytes
  /// [bucket] adalah nama bucket di Supabase Storage (default dari config)
  /// [folder] adalah folder di dalam bucket (opsional)
  /// Returns URL public dari file yang diupload
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
    String? bucket,
    String? folder,
  }) async {
    // Gunakan bucket dari config jika tidak di-specify
    final bucketName = bucket ?? SupabaseConfig.storageBucketName;
    try {
      if (!_authService.isLoggedIn) {
        throw Exception('User harus login untuk upload file');
      }

      var accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('Access token tidak tersedia');
      }

      // Baca file sebagai bytes
      List<int> fileBytes;
      if (kIsWeb) {
        // Di web, kita tidak bisa baca file langsung
        // File sudah harus berupa bytes atau URL
        throw Exception('Upload file di web belum didukung. Gunakan URL langsung.');
      } else {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan: $filePath');
        }
        fileBytes = await file.readAsBytes();
      }

      // Buat path untuk storage
      final userId = _authService.userId ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName);
      final baseName = path.basenameWithoutExtension(fileName);
      final storagePath = folder != null
          ? '$folder/$userId/$timestamp-$baseName$extension'
          : '$userId/$timestamp-$baseName$extension';

      // URL untuk upload ke Supabase Storage
      final uploadUrl = '${SupabaseConfig.supabaseUrl}/storage/v1/object/$bucketName/$storagePath';

      print('📤 Uploading file to: $uploadUrl');
      print('📤 File size: ${fileBytes.length} bytes');

      // Upload file
      var response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Content-Type': _getContentType(fileName),
          'x-upsert': 'true', // Supabase akan overwrite jika sudah ada
        },
        body: fileBytes,
      );

      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Dapatkan public URL
        final publicUrl = _getPublicUrl(bucketName, storagePath);
        print('✅ File uploaded successfully: $publicUrl');
        return publicUrl;
      } else {
        final errorBody = response.body;
        print('❌ Upload error: ${response.statusCode} - $errorBody');
        
        // Parse error untuk memberikan pesan yang lebih jelas
        try {
          final errorJson = json.decode(errorBody);
          final errorMessage = errorJson['message'] ?? errorJson['error'] ?? errorBody;
          final statusCode = errorJson['statusCode'] ?? response.statusCode;
          final errorMsgStr = errorMessage.toString().toLowerCase();
          
          // Check jika token expired (bisa dalam body error meskipun status code 400)
          if ((response.statusCode == 401 || response.statusCode == 403 || statusCode == 401 || statusCode == 403) ||
              errorMsgStr.contains('exp') || 
              errorMsgStr.contains('token') || 
              errorMsgStr.contains('unauthorized') ||
              errorMsgStr.contains('jwt')) {
            // Token expired, coba refresh dan retry sekali
            print('🔄 Token expired/unauthorized, attempting refresh...');
            final refreshed = await _authService.refreshToken();
            if (refreshed) {
              // Retry upload dengan token baru
              accessToken = _authService.accessToken;
              if (accessToken != null) {
                print('🔄 Retrying upload with new token...');
                final retryResponse = await http.put(
                  Uri.parse(uploadUrl),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'apikey': SupabaseConfig.supabaseAnonKey,
                    'Content-Type': _getContentType(fileName),
                    'x-upsert': 'true',
                  },
                  body: fileBytes,
                );
                
                if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
                  final publicUrl = _getPublicUrl(bucketName, storagePath);
                  print('✅ File uploaded successfully after token refresh: $publicUrl');
                  return publicUrl;
                } else {
                  throw Exception('Sesi Anda telah berakhir. Silakan logout dan login kembali untuk melanjutkan upload file.');
                }
              }
            }
            throw Exception('Sesi Anda telah berakhir. Silakan logout dan login kembali untuk melanjutkan upload file.');
          }
          
          if (errorMsgStr.contains('bucket not found')) {
            throw Exception(
              'Bucket "$bucketName" belum dibuat di Supabase Storage.\n\n'
              'Silakan buat bucket terlebih dahulu:\n'
              '1. Buka Supabase Dashboard → Storage\n'
              '2. Klik "New bucket"\n'
              '3. Nama: $bucketName\n'
              '4. Pilih "Public bucket"\n'
              '5. Klik "Create bucket"\n\n'
              'Atau ubah nama bucket di: lib/core/config/supabase_config.dart\n'
              'variabel: storageBucketName'
            );
          } else if (errorMsgStr.contains('row-level security') || 
                     errorMsgStr.contains('rls policy') ||
                     errorMsgStr.contains('violates row-level security')) {
            throw Exception(
              'Row Level Security (RLS) Policy belum diatur untuk bucket "$bucketName".\n\n'
              'Silakan atur RLS policy di Supabase:\n'
              '1. Buka Supabase Dashboard → Storage → Policies\n'
              '2. Pilih bucket "$bucketName"\n'
              '3. Klik "New Policy"\n'
              '4. Pilih "For full customization" atau gunakan template:\n'
              '   - Policy name: Allow authenticated upload\n'
              '   - Allowed operation: INSERT\n'
              '   - Target roles: authenticated\n'
              '   - USING expression: (auth.role() = \'authenticated\')\n'
              '   - WITH CHECK expression: (auth.role() = \'authenticated\')\n'
              '5. Buat policy lagi untuk SELECT:\n'
              '   - Policy name: Allow public read\n'
              '   - Allowed operation: SELECT\n'
              '   - Target roles: public\n'
              '   - USING expression: true\n'
              '6. Klik "Create policy" untuk masing-masing'
            );
          }
          
          throw Exception('Gagal upload file: $errorMessage');
        } catch (e) {
          // Jika bukan JSON atau sudah Exception, rethrow
          if (e is Exception) {
            rethrow;
          }
          throw Exception('Gagal upload file: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('❌ Upload exception: $e');
      rethrow;
    }
  }

  /// Upload file dari bytes (untuk web atau file yang sudah di-load)
  Future<String> uploadFileFromBytes({
    required List<int> bytes,
    required String fileName,
    String? bucket,
    String? folder,
  }) async {
    // Gunakan bucket dari config jika tidak di-specify
    final bucketName = bucket ?? SupabaseConfig.storageBucketName;
    try {
      if (!_authService.isLoggedIn) {
        throw Exception('User harus login untuk upload file');
      }

      var accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('Access token tidak tersedia');
      }

      // Buat path untuk storage
      final userId = _authService.userId ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName);
      final baseName = path.basenameWithoutExtension(fileName);
      final storagePath = folder != null
          ? '$folder/$userId/$timestamp-$baseName$extension'
          : '$userId/$timestamp-$baseName$extension';

      // URL untuk upload ke Supabase Storage
      final uploadUrl = '${SupabaseConfig.supabaseUrl}/storage/v1/object/$bucketName/$storagePath';

      print('📤 Uploading file to: $uploadUrl');
      print('📤 File size: ${bytes.length} bytes');

      // Upload file
      var response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Content-Type': _getContentType(fileName),
          'x-upsert': 'true',
        },
        body: bytes,
      );

      print('📥 Upload response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Dapatkan public URL
        final publicUrl = _getPublicUrl(bucketName, storagePath);
        print('✅ File uploaded successfully: $publicUrl');
        return publicUrl;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expired (401) atau unauthorized (403), coba refresh dan retry sekali
        print('🔄 Token expired/unauthorized (${response.statusCode}), attempting refresh...');
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          // Retry upload dengan token baru
          accessToken = _authService.accessToken;
          if (accessToken != null) {
            print('🔄 Retrying upload with new token...');
            response = await http.put(
              Uri.parse(uploadUrl),
              headers: {
                'Authorization': 'Bearer $accessToken',
                'apikey': SupabaseConfig.supabaseAnonKey,
                'Content-Type': _getContentType(fileName),
                'x-upsert': 'true',
              },
              body: bytes,
            );
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              final publicUrl = _getPublicUrl(bucketName, storagePath);
              print('✅ File uploaded successfully after token refresh: $publicUrl');
              return publicUrl;
            }
          }
        }
        throw Exception('Sesi Anda telah berakhir. Silakan logout dan login kembali untuk melanjutkan upload file.');
      } else {
        final errorBody = response.body;
        print('❌ Upload error: ${response.statusCode} - $errorBody');
        
        // Parse error untuk memberikan pesan yang lebih jelas
        try {
          final errorJson = json.decode(errorBody);
          final errorMessage = errorJson['message'] ?? errorJson['error'] ?? errorBody;
          final errorMsgStr = errorMessage.toString().toLowerCase();
          
              if (errorMsgStr.contains('bucket not found')) {
            throw Exception(
              'Bucket "$bucketName" belum dibuat di Supabase Storage.\n\n'
              'Silakan buat bucket terlebih dahulu:\n'
              '1. Buka Supabase Dashboard → Storage\n'
              '2. Klik "New bucket"\n'
              '3. Nama: $bucketName\n'
              '4. Pilih "Public bucket"\n'
              '5. Klik "Create bucket"\n\n'
              'Atau ubah nama bucket di: lib/core/config/supabase_config.dart\n'
              'variabel: storageBucketName'
            );
          } else if (errorMsgStr.contains('row-level security') || 
                     errorMsgStr.contains('rls policy') ||
                     errorMsgStr.contains('violates row-level security')) {
            throw Exception(
              'Row Level Security (RLS) Policy belum diatur untuk bucket "$bucketName".\n\n'
              'Silakan atur RLS policy di Supabase:\n'
              '1. Buka Supabase Dashboard → Storage → Policies\n'
              '2. Pilih bucket "$bucketName"\n'
              '3. Klik "New Policy"\n'
              '4. Pilih "For full customization" atau gunakan template:\n'
              '   - Policy name: Allow authenticated upload\n'
              '   - Allowed operation: INSERT\n'
              '   - Target roles: authenticated\n'
              '   - USING expression: (auth.role() = \'authenticated\')\n'
              '   - WITH CHECK expression: (auth.role() = \'authenticated\')\n'
              '5. Buat policy lagi untuk SELECT:\n'
              '   - Policy name: Allow public read\n'
              '   - Allowed operation: SELECT\n'
              '   - Target roles: public\n'
              '   - USING expression: true\n'
              '6. Klik "Create policy" untuk masing-masing'
            );
          }
          
          throw Exception('Gagal upload file: $errorMessage');
        } catch (e) {
          // Jika bukan JSON atau sudah Exception, rethrow
          if (e is Exception) {
            rethrow;
          }
          throw Exception('Gagal upload file: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('❌ Upload exception: $e');
      rethrow;
    }
  }

  /// Delete file dari Supabase Storage
  Future<void> deleteFile({
    required String fileUrl,
    String? bucket,
  }) async {
    // Gunakan bucket dari config jika tidak di-specify
    final bucketName = bucket ?? SupabaseConfig.storageBucketName;
    try {
      if (!_authService.isLoggedIn) {
        throw Exception('User harus login untuk delete file');
      }

      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('Access token tidak tersedia');
      }

      // Extract storage path dari URL
      final storagePath = _extractPathFromUrl(fileUrl, bucketName);
      if (storagePath == null) {
        throw Exception('Tidak bisa extract path dari URL: $fileUrl');
      }

      // URL untuk delete dari Supabase Storage
      final deleteUrl = '${SupabaseConfig.supabaseUrl}/storage/v1/object/$bucketName/$storagePath';

      print('🗑️ Deleting file from: $deleteUrl');

      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'apikey': SupabaseConfig.supabaseAnonKey,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ File deleted successfully');
      } else {
        print('⚠️ Delete response: ${response.statusCode} - ${response.body}');
        // Tidak throw error karena file mungkin sudah dihapus
      }
    } catch (e) {
      print('❌ Delete exception: $e');
      // Tidak rethrow karena file mungkin sudah dihapus atau tidak ada
    }
  }

  /// Mendapatkan public URL dari file di storage
  String _getPublicUrl(String bucket, String storagePath) {
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/$bucket/$storagePath';
  }

  /// Extract storage path dari public URL
  String? _extractPathFromUrl(String url, String bucket) {
    try {
      final publicUrlPattern = '/storage/v1/object/public/$bucket/';
      final index = url.indexOf(publicUrlPattern);
      if (index != -1) {
        return url.substring(index + publicUrlPattern.length);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mendapatkan Content-Type berdasarkan extension file
  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
