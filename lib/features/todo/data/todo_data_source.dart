import 'dart:convert';
import '../models/todo_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/auth/services/auth_service.dart';

/// Data source untuk Todo
/// Menggunakan Supabase REST API sebagai backend
/// Mengikuti prinsip SOLID - Single Responsibility Principle
class TodoDataSource {
  final SupabaseService _supabase = SupabaseService();
  final AuthService _authService = AuthService();

  /// Mengambil semua todos dari Supabase (hanya milik user yang login)
  /// RLS policy akan otomatis filter berdasarkan auth.uid()
  Future<List<TodoModel>> getAllTodos() async {
    try {
      // Pastikan user_id sesuai dengan auth.uid() dari token
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        print('⚠️ User not logged in, returning empty todos');
        return [];
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        print('⚠️ User ID not found, returning empty todos');
        return [];
      }

      print('📥 Fetching todos from Supabase for user: $userId');
      // Tidak perlu filter di query karena RLS policy sudah otomatis filter
      // Tapi kita tetap filter sebagai double-check
      final data = await _supabase.get(
        SupabaseConfig.todosUrl,
        filters: {'user_id': 'eq.$userId'},
      );
      print('📥 Received ${data.length} todos from Supabase');
      print('📥 Data: $data');
      
      final todos = data.map((json) {
        try {
          return _fromSupabaseJson(json);
        } catch (e) {
          print('❌ Error parsing todo JSON: $json');
          print('❌ Error: $e');
          rethrow;
        }
      }).toList();
      
      print('✅ Successfully parsed ${todos.length} todos');
      return todos;
    } catch (e) {
      print('❌ Error fetching todos: $e');
      // Jika error, return empty list
      return [];
    }
  }

  /// Menambahkan todo baru ke Supabase
  Future<void> addTodo(TodoModel todo) async {
    String? userId;
    try {
      // Pastikan user_id sesuai dengan auth.uid() dari token
      // Ambil dari getCurrentUser() untuk memastikan sesuai dengan token
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      print('📝 Adding todo: ${todo.title} for user: $userId');
      final json = _toSupabaseJson(todo, userId);
      print('📝 JSON to send: ${json.toString()}');
      print('📝 Access token available: ${_authService.accessToken != null}');
      print('📝 User ID from token: $userId');
      
      final result = await _supabase.post(SupabaseConfig.todosUrl, json);
      print('✅ Todo added successfully: $result');
    } catch (e) {
      print('❌ Error adding todo: $e');
      print('❌ User ID: ${userId ?? "null"}');
      final accessToken = _authService.accessToken;
      print('❌ Access token: ${accessToken != null ? accessToken.substring(0, accessToken.length > 30 ? 30 : accessToken.length) : "null"}...');
      // Handle error jika perlu
      rethrow;
    }
  }

  /// Menghapus todo dari Supabase (hanya milik user yang login)
  Future<void> deleteTodo(String id) async {
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
      await _supabase.delete('${SupabaseConfig.todosUrl}?id=eq.$id&user_id=eq.$userId');
    } catch (e) {
      // Handle error jika perlu
      rethrow;
    }
  }

  /// Toggle status completed todo di Supabase
  Future<void> toggleTodoStatus(String id) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      // Ambil todo terlebih dahulu (sudah filter berdasarkan user_id)
      final todos = await getAllTodos();
      final todo = todos.firstWhere((t) => t.id == id);
      
      // Update status
      await _supabase.patch(
        '${SupabaseConfig.todosUrl}?id=eq.$id&user_id=eq.$userId',
        _toSupabaseJson(todo.copyWith(isCompleted: !todo.isCompleted), userId),
      );
    } catch (e) {
      // Handle error jika perlu
      rethrow;
    }
  }

  /// Update todo di Supabase (hanya milik user yang login)
  Future<void> updateTodo(TodoModel todo) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User tidak login atau token tidak valid. Silakan login ulang.');
      }
      
      final userId = currentUser['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      // Filter berdasarkan user_id untuk memastikan hanya bisa update milik sendiri
      await _supabase.patch(
        '${SupabaseConfig.todosUrl}?id=eq.${todo.id}&user_id=eq.$userId',
        _toSupabaseJson(todo, userId),
      );
    } catch (e) {
      // Handle error jika perlu
      rethrow;
    }
  }

  /// Mendapatkan list kategori yang tersedia
  List<String> getAvailableCategories() {
    return List.from(AppConstants.todoCategories);
  }

  /// Konversi dari JSON Supabase (snake_case) ke TodoModel (camelCase)
  TodoModel _fromSupabaseJson(Map<String, dynamic> json) {
    // Handle id yang bisa berupa int atau String dari Supabase
    final idValue = json['id'];
    final id = idValue is int ? idValue.toString() : idValue as String;
    
    return TodoModel(
      id: id,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      // Konversi waktu dari Supabase ke local timezone agar konsisten di UI
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'] as String).toLocal()
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String).toLocal()
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      imagePath: json['image_path'] as String?,
    );
  }

  /// Konversi dari TodoModel (camelCase) ke JSON Supabase (snake_case)
  Map<String, dynamic> _toSupabaseJson(TodoModel todo, String userId) {
    final json = {
      'id': todo.id,
      'user_id': userId,
      'title': todo.title,
      'description': todo.description,
      'category': todo.category,
      // Simpan dalam UTC untuk konsistensi server-side
      'created_at': todo.createdAt.toUtc().toIso8601String(),
      'is_completed': todo.isCompleted,
    };

    // Hanya tambahkan field yang nullable jika ada nilainya
    if (todo.reminderDate != null) {
      json['reminder_date'] = todo.reminderDate!.toUtc().toIso8601String();
    }
    if (todo.deadline != null) {
      json['deadline'] = todo.deadline!.toUtc().toIso8601String();
    }
    if (todo.imagePath != null && todo.imagePath!.isNotEmpty) {
      json['image_path'] = todo.imagePath as String;
    }

    return json;
  }
}