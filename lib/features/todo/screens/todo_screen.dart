import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/widgets/common_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/todo_model.dart';
import 'todo_add_edit_screen.dart';
import 'todo_archive_screen.dart';

// Conditional import untuk File
import 'file_helper.dart' if (dart.library.io) 'file_helper_io.dart' as file_helper;

/// Halaman untuk menampilkan dan mengelola daftar tugas
/// Desain mirip Notion dengan transisi smooth dan tema light
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _repository = RepositoryProvider().todoRepository;
  List<TodoModel> _todos = [];
  String _selectedCategory = 'Semua';
  List<String> _categories = ['Semua'];
  bool _isLoading = false;
  Timer? _uiTickTimer;

  // Helper: Jakarta time (WIB, UTC+7)
  DateTime _jakartaNow() {
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.add(const Duration(hours: 7));
  }

  DateTime _toJakarta(DateTime dt) {
    final utc = dt.toUtc();
    return utc.add(const Duration(hours: 7));
  }

  /// Memuat data tugas dari repository
  /// Dipanggil saat screen pertama kali dibuat
  @override
  void initState() {
    super.initState();
    _loadTodos();
    // Jadwalkan refresh UI berbasis deadline terdekat agar warna berubah tepat saat waktu lewat
    _scheduleDeadlineTick();
  }

  @override
  void dispose() {
    _uiTickTimer?.cancel();
    super.dispose();
  }

  /// Menjadwalkan refresh UI tepat ketika melewati deadline terdekat
  void _scheduleDeadlineTick() {
    _uiTickTimer?.cancel();
    if (!mounted) return;
    final now = DateTime.now();
    final deadlines = _todos
        .where((t) => !t.isCompleted && t.deadline != null)
        .map((t) => t.deadline!)
        .where((d) => d.isAfter(now))
        .toList();
    deadlines.sort((a, b) => a.compareTo(b));

    Duration wait;
    if (deadlines.isNotEmpty) {
      final next = deadlines.first;
      final diff = next.difference(now);
      wait = diff + const Duration(milliseconds: 300);
    } else {
      wait = const Duration(seconds: 30);
    }

    _uiTickTimer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _scheduleDeadlineTick();
    });
  }

  /// Mengambil semua tugas dan kategori dari repository
  Future<void> _loadTodos() async {
    if (mounted) {
    setState(() {
        _isLoading = true;
      });
    }

    try {
      print('🔄 Loading todos...');
      final todos = await _repository.getAllTodos();
      final categories = _repository.getAvailableCategories();
      
      print('✅ Loaded ${todos.length} todos');
      
      if (mounted) {
        setState(() {
          _todos = todos;
          _categories = ['Semua', ...categories];
          _isLoading = false;
        });
        // Setelah data ter-update, jadwalkan tick refresh berdasar deadline terbaru
        _scheduleDeadlineTick();
      }
    } catch (e) {
      print('❌ Error loading todos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat data: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  /// Navigate ke screen untuk menambahkan tugas baru
  Future<void> _navigateToAddTodo() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const TodoAddEditScreen(),
      ),
    );
    if (result == true) {
      // Tambah delay kecil untuk memastikan data sudah tersimpan di Supabase
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadTodos();
    }
  }

  /// Navigate ke screen untuk mengedit tugas
  Future<void> _navigateToEditTodo(TodoModel todo) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TodoAddEditScreen(todo: todo),
      ),
    );
    if (result == true) {
      // Tambah delay kecil untuk memastikan data sudah tersimpan di Supabase
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadTodos();
    }
  }

  /// Mengubah status selesai/belum selesai dari tugas
  /// [todo] adalah TodoModel yang akan diubah statusnya
  Future<void> _toggleTodoStatus(TodoModel todo) async {
    final willComplete = !todo.isCompleted;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          willComplete ? 'Selesaikan tugas?' : 'Batalkan selesai?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          willComplete
              ? 'Apakah Anda yakin ingin menandai tugas ini sebagai selesai?'
              : 'Apakah Anda yakin ingin membatalkan status selesai tugas ini?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya', style: TextStyle(color: AppTheme.accentBlue)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.toggleTodoStatus(todo.id);
      // Tambah delay kecil untuk memastikan data sudah tersimpan di Supabase
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadTodos();
    }
  }

  /// Check apakah image path tersedia (untuk web compatibility)
  bool _isImageAvailable(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;
    // Jika path adalah URL (dari Supabase Storage), selalu return true
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return true;
    }
    if (kIsWeb) {
      // Di web, asumsikan image path adalah URL atau path yang valid
      return imagePath.isNotEmpty;
    } else {
      // Di mobile, check apakah file exists
      return file_helper.isFileAvailable(imagePath);
    }
  }

  /// Build image widget untuk file (menggunakan helper untuk web compatibility)
  Widget _buildFileImage(String path, {double? height}) {
    // Jika path adalah URL (dari Supabase Storage), gunakan Image.network
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: height == null ? double.infinity : null,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: height == null ? double.infinity : null,
            height: height ?? 200,
            color: AppTheme.surface,
            child: const Center(
              child: Icon(Icons.broken_image, color: AppTheme.textSecondary),
            ),
          );
        },
      );
    }
    // Untuk path lokal, gunakan helper
    return file_helper.buildImageWidget(
      path,
      width: height == null ? double.infinity : null,
      height: height,
    );
  }

  /// Menghapus tugas
  /// [todo] adalah TodoModel yang akan dihapus
  Future<void> _deleteTodo(TodoModel todo) async {
    await _repository.deleteTodo(todo.id);
    // Tambah delay kecil untuk memastikan data sudah terhapus di Supabase
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadTodos();
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tugas berhasil dihapus'),
        backgroundColor: AppTheme.divider,
        behavior: SnackBarBehavior.floating,
      ),
    );
    }
  }

  /// Menampilkan informasi detail tugas
  /// [todo] adalah TodoModel yang akan ditampilkan detailnya
  void _showTodoDetails(TodoModel todo) {
    final isOverdue = todo.deadline != null &&
        _toJakarta(todo.deadline!).isBefore(_jakartaNow()) &&
        !todo.isCompleted;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.divider,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: todo.isCompleted
                            ? AppTheme.accentBlue.withOpacity(0.15)
                            : isOverdue
                                ? AppTheme.red.withOpacity(0.15)
                                : AppTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        todo.isCompleted
                            ? Icons.check_circle
                            : Icons.task_alt,
                        color: todo.isCompleted
                            ? AppTheme.accentBlue
                            : isOverdue
                                ? AppTheme.red
                                : AppTheme.accentBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.title,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              todo.category,
                              style: const TextStyle(
                                color: AppTheme.accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (todo.description.isNotEmpty) ...[
                        const Text(
                          'Deskripsi',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.divider,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            todo.description,
                            style: TextStyle(
                              color: todo.isCompleted
                                  ? AppTheme.textTertiary
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.5,
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Image
                      if (todo.imagePath != null && _isImageAvailable(todo.imagePath!)) ...[
                        const Text(
                          'Gambar',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildFileImage(todo.imagePath!),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Information cards
                      // Deadline
                      if (todo.deadline != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOverdue ? AppTheme.red : AppTheme.divider,
                              width: isOverdue ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: isOverdue ? AppTheme.red : AppTheme.accentBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tenggat Waktu',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy, HH:mm').format(_toJakarta(todo.deadline!)),
                                      style: TextStyle(
                                        color: isOverdue ? AppTheme.red : AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Reminder
                      if (todo.reminderDate != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications,
                                color: AppTheme.accentBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pengingat',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy, HH:mm').format(todo.reminderDate!),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Created Date
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: AppTheme.textTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm').format(_toJakarta(todo.createdAt))}',
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.divider,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _toggleTodoStatus(todo);
                        },
                        icon: Icon(
                          todo.isCompleted
                              ? Icons.undo
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: Text(todo.isCompleted ? 'Batalkan' : 'Selesai'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentBlue,
                          side: const BorderSide(color: AppTheme.accentBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToEditTodo(todo);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(color: AppTheme.divider),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteTodo(todo);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.red,
                          side: const BorderSide(color: AppTheme.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membuat widget untuk menampilkan satu item tugas
  /// [todo] adalah TodoModel yang akan ditampilkan
  /// Menggunakan animasi halus dan kartu glass ringan
  Widget _buildTodoItem(TodoModel todo) {
    final isOverdue = !todo.isCompleted &&
        todo.deadline != null &&
        _toJakarta(todo.deadline!).isBefore(_jakartaNow());

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _showTodoDetails(todo),
        child: _GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: isOverdue
              ? AppTheme.red.withOpacity(0.08)
              : AppTheme.surface.withOpacity(0.65),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) => _toggleTodoStatus(todo),
                  activeColor: AppTheme.accentBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (todo.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        todo.description,
                        style: TextStyle(
                          color: todo.isCompleted
                              ? AppTheme.textTertiary
                              : AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (todo.imagePath != null && _isImageAvailable(todo.imagePath!)) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildFileImage(todo.imagePath!, height: 90),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            todo.category,
                            style: const TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (todo.deadline != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? AppTheme.red.withOpacity(0.2)
                                  : AppTheme.accentBlue.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event,
                                  color: isOverdue ? AppTheme.red : AppTheme.accentBlue,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  DateFormat('dd MMM').format(_toJakarta(todo.deadline!)),
                                  style: TextStyle(
                                    color: isOverdue ? AppTheme.red : AppTheme.accentBlue,
                                    fontSize: 12,
                                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (todo.reminderDate != null)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active,
                              color: AppTheme.accentBlue,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _deleteTodo(todo),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter tugas berdasarkan kategori yang dipilih
    List<TodoModel> filteredTodos = _todos;
    if (_selectedCategory != 'Semua') {
      filteredTodos = _todos
          .where((todo) => todo.category == _selectedCategory)
          .toList();
    }

    // Urutkan: yang belum selesai di atas, tenggat terdekat, lalu yang selesai di bawah
    filteredTodos.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        }
        if (a.deadline != null) return -1;
        if (b.deadline != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      }
      return a.isCompleted ? 1 : -1;
    });

    return Scaffold(
      body: Column(
        children: [
          CommonHeader(
            title: 'Daftar Tugas',
            actions: [
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TodoArchiveScreen(),
                          ),
                        );
                      },
                      tooltip: 'Arsip Tugas Selesai',
                      color: AppTheme.textSecondary,
                    ),
                  ],
          ),
          // Filter kategori (horizontal scrollable)
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentBlue
                          : AppTheme.surface.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentBlue : AppTheme.divider,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Daftar tugas dengan pull-to-refresh
          Expanded(
            child: _isLoading && _todos.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentBlue,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTodos,
                    color: AppTheme.accentBlue,
                    child: filteredTodos.isEmpty
                        ? EmptyState(
                            icon: Icons.task_alt,
                            message: 'Tidak ada tugas',
                            actionLabel: 'Refresh',
                            onAction: _loadTodos,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, index) {
                      return _buildTodoItem(filteredTodos[index]);
                    },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTodo,
        backgroundColor: AppTheme.accentBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Kartu glass reusable untuk konsistensi dan kesan halus
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const _GlassCard({
    required this.child,
    this.margin,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (backgroundColor ?? AppTheme.surface.withOpacity(0.65)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
