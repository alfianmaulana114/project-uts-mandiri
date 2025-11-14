import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../weather/models/weather_model.dart';
import '../../todo/models/todo_model.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';

/// Halaman Home yang menampilkan greeting, cuaca, dan tugas dengan deadline
/// Desain mirip Notion dengan tema dark
class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({super.key});

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final _weatherRepository = RepositoryProvider().weatherRepository;
  final _todoRepository = RepositoryProvider().todoRepository;
  final _authService = AuthService();
  WeatherModel? _weather;
  bool _isLoadingWeather = false;
  List<TodoModel> _todosWithDeadline = [];
  String? _userName;
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

  /// Memuat data cuaca dan tugas saat screen pertama kali dibuat
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadWeather();
    _loadTodos();
    // Jadwalkan refresh UI berdasar deadline terdekat agar warna berubah tepat waktu
    _scheduleDeadlineTick();
  }

  @override
  void dispose() {
    _uiTickTimer?.cancel();
    super.dispose();
  }

  /// Menjadwalkan refresh UI tepat saat melewati deadline terdekat
  void _scheduleDeadlineTick() {
    _uiTickTimer?.cancel();
    if (!mounted) return;

    final now = DateTime.now();
    // Ambil semua deadline dari list saat ini
    final deadlines = _todosWithDeadline
        .where((t) => t.deadline != null && !t.isCompleted)
        .map((t) => t.deadline!)
        .where((d) => d.isAfter(now))
        .toList();

    deadlines.sort((a, b) => a.compareTo(b));

    Duration wait;
    if (deadlines.isNotEmpty) {
      final next = deadlines.first;
      final diff = next.difference(now);
      // Tambah sedikit buffer agar repaint terjadi setelah waktu benar-benar lewat
      wait = diff + const Duration(milliseconds: 300);
    } else {
      // Jika tidak ada deadline mendatang, tetap refresh periodik ringan
      wait = const Duration(seconds: 30);
    }

    _uiTickTimer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      // Jadwalkan ulang tick berikutnya
      _scheduleDeadlineTick();
    });
  }

  /// Memuat informasi user untuk menampilkan nama di greeting
  Future<void> _loadUserInfo() async {
    final userInfo = await _authService.getCurrentUser();
    if (userInfo != null && mounted) {
      // Ambil nama dari user_metadata atau email
      final userMetadata = userInfo['user_metadata'] as Map<String, dynamic>?;
      final name = userMetadata?['name'] ?? 
                   userMetadata?['full_name'] ?? 
                   userInfo['email']?.toString().split('@')[0] ??
                   'Pengguna';
      
      setState(() {
        _userName = name;
      });
    }
  }

  /// Memuat data cuaca untuk lokasi default
  Future<void> _loadWeather() async {
    setState(() {
      _isLoadingWeather = true;
    });

    final weather = await _weatherRepository.getWeather('Jakarta');
    
    if (mounted) {
      setState(() {
        _weather = weather;
        _isLoadingWeather = false;
      });
    }
  }

  /// Memuat tugas yang memiliki deadline
  Future<void> _loadTodos() async {
    final allTodos = await _todoRepository.getPendingTodos();
    // Filter hanya tugas yang memiliki deadline dan belum selesai
    final todosWithDeadline = allTodos
        .where((todo) => todo.deadline != null && !todo.isCompleted)
        .toList();
    // Urutkan berdasarkan deadline terdekat
    todosWithDeadline.sort((a, b) {
      return a.deadline!.compareTo(b.deadline!);
    });
    // Ambil maksimal 5 tugas terdekat
    final limitedTodos = todosWithDeadline.take(5).toList();
    
    // Reschedule notifications untuk semua todos dengan deadline
    // Ini penting saat app restart untuk memastikan notifications tetap aktif
    final notificationService = NotificationService();
    for (final todo in todosWithDeadline) {
      if (todo.deadline != null && !todo.isCompleted) {
        await notificationService.scheduleDeadlineNotifications(
          todoId: todo.id,
          todoTitle: todo.title,
          deadline: todo.deadline!,
        );
      }
    }
    
    if (mounted) {
      setState(() {
        _todosWithDeadline = limitedTodos;
      });
      // Setelah data ter-update, jadwalkan tick refresh berdasar deadline terbaru
      _scheduleDeadlineTick();
    }
  }

  /// Mendapatkan greeting berdasarkan waktu
  /// Mengembalikan "Selamat Pagi", "Selamat Siang", atau "Selamat Sore"
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Selamat Pagi';
    } else if (hour >= 12 && hour < 17) {
      return 'Selamat Siang';
    } else if (hour >= 17 && hour < 21) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Logout',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Apakah Anda yakin ingin logout?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppTheme.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              color: AppTheme.textSecondary,
              tooltip: 'Logout',
              onPressed: _handleLogout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header rounded area
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOut,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: Text(
                            _userName != null ? '${_getGreeting()}, $_userName' : _getGreeting(),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Weather card (glassmorphism, rounded, animated)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _SectionCard(
                      child: _isLoadingWeather
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(color: AppTheme.accentBlue),
                              ),
                            )
                          : (_weather == null
                              ? Row(
                                  children: const [
                                    Icon(Icons.wb_sunny_outlined, color: AppTheme.textSecondary),
                                    SizedBox(width: 12),
                                    Text('Tidak dapat memuat cuaca',
                                        style: TextStyle(color: AppTheme.textSecondary)),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (_weather!.icon.isNotEmpty)
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(milliseconds: 500),
                                        tween: Tween(begin: 0.9, end: 1.0),
                                        curve: Curves.easeOutBack,
                                        builder: (context, v, child) => Transform.scale(
                                          scale: v,
                                          child: child,
                                        ),
                                        child: Image.network(
                                          'https:${_weather!.icon}',
                                          width: 56,
                                          height: 56,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.wb_sunny, size: 56, color: AppTheme.accentBlue);
                                          },
                                        ),
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _weather!.location,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_weather!.temperature.toStringAsFixed(0)}°C - ${_weather!.condition}',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _InfoPill(
                                                icon: Icons.water_drop,
                                                label: 'Kelembapan',
                                                value: '${_weather!.humidity.toStringAsFixed(0)}% ',
                                              ),
                                              _InfoPill(
                                                icon: Icons.air,
                                                label: 'Angin',
                                                value: '${_weather!.windSpeed.toStringAsFixed(0)} km/j',
                                              ),
                                              _InfoPill(
                                                icon: _weather!.isBadWeather
                                                    ? Icons.warning_amber_rounded
                                                    : Icons.check_circle_outline,
                                                label: 'Status',
                                                value: _weather!.isBadWeather ? 'Cuaca Buruk' : 'Aman',
                                                color: _weather!.isBadWeather
                                                    ? AppTheme.red.withOpacity(0.18)
                                                    : AppTheme.green.withOpacity(0.18),
                                                textColor: _weather!.isBadWeather ? AppTheme.red : AppTheme.green,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )),
                    ),
                  ),
                  // Deadline section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Row(
                      children: const [
                        Text('Deadline Tugas',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionCard(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: _todosWithDeadline.isEmpty
                          ? Column(
                              children: const [
                                SizedBox(height: 4),
                                Icon(Icons.task_alt, size: 40, color: AppTheme.textTertiary),
                                SizedBox(height: 8),
                                Text('Tidak ada tugas dengan deadline',
                                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
                                SizedBox(height: 4),
                              ],
                            )
                          : Column(
                              children: _todosWithDeadline.map((todo) {
                                final deadline = todo.deadline;
                                if (deadline == null) return const SizedBox.shrink();
                                final isOverdue = _toJakarta(deadline).isBefore(_jakartaNow());
                                return TweenAnimationBuilder<double>(
                                  key: ValueKey(todo.id),
                                  duration: const Duration(milliseconds: 350),
                                  tween: Tween(begin: 0, end: 1),
                                  curve: Curves.easeOut,
                                  builder: (context, v, child) => Opacity(
                                    opacity: v,
                                    child: Transform.translate(
                                      offset: Offset(0, 14 * (1 - v)),
                                      child: child,
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? AppTheme.red.withOpacity(0.08)
                                          : AppTheme.surface.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isOverdue
                                            ? AppTheme.red.withOpacity(0.28)
                                            : AppTheme.divider,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.event,
                                            color: isOverdue ? AppTheme.red : AppTheme.accentBlue, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                todo.title,
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight:
                                                      isOverdue ? FontWeight.w600 : FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('dd MMM yyyy, HH:mm').format(_toJakarta(deadline)),
                                                style: TextStyle(
                                                  color: isOverdue ? AppTheme.red : AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// Kartu seksional dengan efek glass/blur halus dan sudut membulat
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Badge/pill kecil untuk info cuaca
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final Color? textColor;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.accentBlue.withOpacity(0.14);
    final fg = textColor ?? AppTheme.accentBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
