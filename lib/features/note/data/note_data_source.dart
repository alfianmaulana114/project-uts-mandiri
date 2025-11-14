import '../models/note_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/auth/services/auth_service.dart';

/// Data source untuk Note
/// Menggunakan Supabase REST API sebagai backend
class NoteDataSource {
  final SupabaseService _supabase = SupabaseService();
  final AuthService _authService = AuthService();

  /// Mengambil semua notes dari Supabase
  List<NoteModel> getAllNotes() {
    // Note: Karena method ini dipanggil secara sync di beberapa tempat,
    // kita buat async version terpisah untuk Supabase
    // Untuk sementara return empty list, akan di-fetch via async method
    return [];
  }

  /// Mengambil semua notes dari Supabase (async) - hanya milik user yang login
  Future<List<NoteModel>> getAllNotesAsync() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        print('⚠️ User not logged in, returning empty notes');
        return [];
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        print('⚠️ User ID not found, returning empty notes');
        return [];
      }

      print('📥 Fetching notes from Supabase for user: $userId');
      // Filter berdasarkan user_id
      final data = await _supabase.get(
        SupabaseConfig.notesUrl,
        filters: {'user_id': 'eq.$userId'},
      );
      print('📥 Received ${data.length} notes from Supabase');
      
      final notes = data.map((json) {
        try {
          return _fromSupabaseJson(json);
        } catch (e) {
          print('❌ Error parsing note JSON: $json');
          print('❌ Error: $e');
          rethrow;
        }
      }).toList();
      
      print('✅ Successfully parsed ${notes.length} notes');
      return notes;
    } catch (e) {
      print('❌ Error fetching notes: $e');
      return [];
    }
  }

  /// Menambahkan note baru ke Supabase
  Future<void> addNote(NoteModel note) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      await _supabase.post(SupabaseConfig.notesUrl, _toSupabaseJson(note, userId));
    } catch (e) {
      rethrow;
    }
  }

  /// Menghapus note dari Supabase (hanya milik user yang login)
  Future<void> deleteNote(String id) async {
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
      await _supabase.delete('${SupabaseConfig.notesUrl}?id=eq.$id&user_id=eq.$userId');
    } catch (e) {
      rethrow;
    }
  }

  /// Update note di Supabase (hanya milik user yang login)
  Future<void> updateNote(NoteModel note) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      // Filter berdasarkan user_id untuk memastikan hanya bisa update milik sendiri
      await _supabase.patch(
        '${SupabaseConfig.notesUrl}?id=eq.${note.id}&user_id=eq.$userId',
        _toSupabaseJson(updatedNote, userId),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Konversi dari JSON Supabase (snake_case) ke NoteModel (camelCase)
  NoteModel _fromSupabaseJson(Map<String, dynamic> json) {
    // Handle id yang bisa berupa int atau String dari Supabase
    final idValue = json['id'];
    final id = idValue is int ? idValue.toString() : idValue as String;
    
    return NoteModel(
      id: id,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      color: json['color'] as String? ?? AppConstants.defaultNoteColor,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((tag) => tag as String)
              .toList() ??
          [],
      imagePath: json['image_path'] as String?,
    );
  }

  /// Konversi dari NoteModel (camelCase) ke JSON Supabase (snake_case)
  Map<String, dynamic> _toSupabaseJson(NoteModel note, String userId) {
    // Note: kolom 'color' tidak ada di schema Supabase, jadi tidak kita kirim
    // Color akan tetap digunakan di aplikasi dengan default value
    final json = <String, dynamic>{
      'id': note.id,
      'user_id': userId,
      'title': note.title,
      'content': note.content,
      'created_at': note.createdAt.toIso8601String(),
      'tags': note.tags,
    };
    
    // Hanya tambahkan field yang nullable jika ada nilainya
    if (note.updatedAt != null) {
      json['updated_at'] = note.updatedAt!.toIso8601String();
    }
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      json['image_path'] = note.imagePath;
    }
    
    return json;
  }
}