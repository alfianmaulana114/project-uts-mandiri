import '../models/todo_model.dart';

/// Abstraksi repository untuk pengelolaan data Todo
/// Mengikuti prinsip SOLID - Dependency Inversion Principle
/// UI bergantung pada abstraksi ini, bukan implementasi konkret
abstract class TodoRepository {
  /// Mengambil semua tugas
  Future<List<TodoModel>> getAllTodos();

  /// Mengambil tugas berdasarkan ID
  Future<TodoModel?> getTodoById(String id);

  /// Menambahkan tugas baru
  Future<void> addTodo(TodoModel todo);

  /// Mengupdate tugas yang sudah ada
  Future<void> updateTodo(TodoModel todo);

  /// Menghapus tugas berdasarkan ID
  Future<void> deleteTodo(String id);

  /// Mengubah status selesai/belum selesai dari tugas
  Future<void> toggleTodoStatus(String id);

  /// Mengambil tugas berdasarkan kategori
  Future<List<TodoModel>> getTodosByCategory(String category);

  /// Mengambil tugas yang belum selesai
  Future<List<TodoModel>> getPendingTodos();

  /// Mengambil tugas yang sudah selesai
  Future<List<TodoModel>> getCompletedTodos();

  /// Mengambil semua kategori yang tersedia
  List<String> getAvailableCategories();
}

