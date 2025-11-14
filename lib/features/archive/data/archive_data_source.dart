import '../models/archive_model.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/auth/services/auth_service.dart';

/// Data source untuk Archive
/// Menggunakan Supabase REST API sebagai backend
class ArchiveDataSource {
  final SupabaseService _supabase = SupabaseService();
  final AuthService _authService = AuthService();

  /// Mengambil semua archives dari Supabase (hanya milik user yang login)
  Future<List<ArchiveModel>> getAllArchives() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        print('⚠️ User not logged in, returning empty archives');
        return [];
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        print('⚠️ User ID not found, returning empty archives');
        return [];
      }

      print('📥 Fetching archives from Supabase for user: $userId');
      // Filter berdasarkan user_id
      final data = await _supabase.get(
        SupabaseConfig.archivesUrl,
        filters: {'user_id': 'eq.$userId'},
      );
      print('📥 Received ${data.length} archives from Supabase');
      
      final archives = data.map((json) {
        try {
          return _fromSupabaseJson(json);
        } catch (e) {
          print('❌ Error parsing archive JSON: $json');
          print('❌ Error: $e');
          rethrow;
        }
      }).toList();
      
      print('✅ Successfully parsed ${archives.length} archives');
      return archives;
    } catch (e) {
      print('❌ Error fetching archives: $e');
      return [];
    }
  }

  /// Menambahkan archive baru ke Supabase
  Future<void> addArchive(ArchiveModel archive) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      await _supabase.post(SupabaseConfig.archivesUrl, _toSupabaseJson(archive, userId));
    } catch (e) {
      rethrow;
    }
  }

  /// Menghapus archive dari Supabase (hanya milik user yang login)
  Future<void> deleteArchive(String id) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      // Filter berdasarkan user_id untuk memastikan hanya bisa delete milik sendiri
      await _supabase.delete('${SupabaseConfig.archivesUrl}?id=eq.$id&user_id=eq.$userId');
    } catch (e) {
      rethrow;
    }
  }

  /// Update archive di Supabase (hanya milik user yang login)
  Future<void> updateArchive(ArchiveModel archive) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      final updatedArchive = archive.copyWith(updatedAt: DateTime.now());
      // Filter berdasarkan user_id untuk memastikan hanya bisa update milik sendiri
      await _supabase.patch(
        '${SupabaseConfig.archivesUrl}?id=eq.${archive.id}&user_id=eq.$userId',
        _toSupabaseJson(updatedArchive, userId),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Konversi dari JSON Supabase (snake_case) ke ArchiveModel (camelCase)
  ArchiveModel _fromSupabaseJson(Map<String, dynamic> json) {
    // Handle id yang bisa berupa int atau String dari Supabase
    final idValue = json['id'];
    final id = idValue is int ? idValue.toString() : idValue as String;
    
    return ArchiveModel(
      id: id,
      name: json['name'] as String,
      filePath: json['file_path'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      fileType: json['file_type'] as String? ?? 'file',
    );
  }

  /// Konversi dari ArchiveModel (camelCase) ke JSON Supabase (snake_case)
  Map<String, dynamic> _toSupabaseJson(ArchiveModel archive, String userId) {
    final json = <String, dynamic>{
      'id': archive.id,
      'user_id': userId,
      'name': archive.name,
      'created_at': archive.createdAt.toIso8601String(),
      'file_type': archive.fileType,
    };

    // Hanya tambahkan field yang nullable jika ada nilainya
    if (archive.filePath != null && archive.filePath!.isNotEmpty) {
      json['file_path'] = archive.filePath;
    }
    if (archive.description != null && archive.description!.isNotEmpty) {
      json['description'] = archive.description;
    }
    if (archive.updatedAt != null) {
      json['updated_at'] = archive.updatedAt!.toIso8601String();
    }

    return json;
  }
}