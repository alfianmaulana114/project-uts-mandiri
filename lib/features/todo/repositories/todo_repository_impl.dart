import '../models/todo_model.dart';
import '../data/todo_data_source.dart';
import '../repositories/todo_repository.dart';
import '../../../core/services/notification_service.dart';

/// Implementasi konkret dari TodoRepository
/// Menggunakan TodoDataSource sebagai sumber data
/// Mengikuti prinsip SOLID - Single Responsibility Principle
class TodoRepositoryImpl implements TodoRepository {
  final TodoDataSource _dataSource;
  final NotificationService _notificationService = NotificationService();

  TodoRepositoryImpl({TodoDataSource? dataSource})
      : _dataSource = dataSource ?? TodoDataSource();

  @override
  Future<List<TodoModel>> getAllTodos() async {
    final todos = await _dataSource.getAllTodos();
    // Check dan update todos yang deadline-nya sudah lewat
    await _checkAndMarkOverdueTodos(todos);
    return todos;
  }
  
  /// Check todos yang deadline-nya sudah lewat dan update visual indicator
  /// Catatan: Tidak mengubah status completed, hanya menandai sebagai overdue
  Future<void> _checkAndMarkOverdueTodos(List<TodoModel> todos) async {
    final now = DateTime.now();
    for (final todo in todos) {
      if (todo.deadline != null && 
          todo.deadline!.isBefore(now) && 
          !todo.isCompleted) {
        // Deadline sudah lewat, tapi tidak mengubah isCompleted
        // UI akan menampilkan indicator overdue
        print('⚠️ Todo overdue: ${todo.title} (deadline: ${todo.deadline})');
      }
    }
  }

  @override
  Future<TodoModel?> getTodoById(String id) async {
    final todos = await getAllTodos();
    try {
      return todos.firstWhere((todo) => todo.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addTodo(TodoModel todo) async {
    await _dataSource.addTodo(todo);
    
    // Schedule notifications jika todo punya deadline dan belum completed
    if (todo.deadline != null && !todo.isCompleted) {
      await _notificationService.scheduleDeadlineNotifications(
        todoId: todo.id,
        todoTitle: todo.title,
        deadline: todo.deadline!,
      );
    }
  }

  @override
  Future<void> updateTodo(TodoModel todo) async {
    await _dataSource.updateTodo(todo);
    
    // Update notifications jika deadline berubah
    if (todo.deadline != null && !todo.isCompleted) {
      // Cancel old notifications dan schedule new ones
      await _notificationService.cancelDeadlineNotifications(todo.id);
      await _notificationService.scheduleDeadlineNotifications(
        todoId: todo.id,
        todoTitle: todo.title,
        deadline: todo.deadline!,
      );
    } else {
      // Cancel notifications jika deadline dihapus atau todo completed
      await _notificationService.cancelDeadlineNotifications(todo.id);
    }
  }

  @override
  Future<void> deleteTodo(String id) async {
    // Cancel notifications sebelum delete
    await _notificationService.cancelDeadlineNotifications(id);
    await _dataSource.deleteTodo(id);
  }

  @override
  Future<void> toggleTodoStatus(String id) async {
    // Get todo untuk check status setelah toggle
    final todo = await getTodoById(id);
    if (todo == null) return;
    
    await _dataSource.toggleTodoStatus(id);
    
    // Jika todo jadi completed, cancel notifications
    // Jika todo jadi uncompleted dan punya deadline, schedule notifications
    if (todo.isCompleted) {
      // Akan jadi uncompleted setelah toggle
      if (todo.deadline != null) {
        await _notificationService.scheduleDeadlineNotifications(
          todoId: todo.id,
          todoTitle: todo.title,
          deadline: todo.deadline!,
        );
      }
    } else {
      // Akan jadi completed setelah toggle
      await _notificationService.cancelDeadlineNotifications(id);
    }
  }

  @override
  Future<List<TodoModel>> getTodosByCategory(String category) async {
    final todos = await getAllTodos();
    return todos.where((todo) => todo.category == category).toList();
  }

  @override
  Future<List<TodoModel>> getPendingTodos() async {
    final todos = await getAllTodos();
    return todos.where((todo) => !todo.isCompleted).toList();
  }

  @override
  Future<List<TodoModel>> getCompletedTodos() async {
    final todos = await getAllTodos();
    return todos.where((todo) => todo.isCompleted).toList();
  }

  @override
  List<String> getAvailableCategories() {
    return _dataSource.getAvailableCategories();
  }
}

