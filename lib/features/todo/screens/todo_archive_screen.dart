import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../models/todo_model.dart';

/// Layar arsip tugas: menampilkan tugas yang sudah selesai
/// Dilengkapi filter per-bulan dan per-kategori
class TodoArchiveScreen extends StatefulWidget {
  const TodoArchiveScreen({super.key});

  @override
  State<TodoArchiveScreen> createState() => _TodoArchiveScreenState();
}

class _TodoArchiveScreenState extends State<TodoArchiveScreen> {
  final _repository = RepositoryProvider().todoRepository;
  List<TodoModel> _allCompleted = [];
  List<TodoModel> _filtered = [];
  String _selectedCategory = 'Semua';
  DateTime? _selectedMonth; // gunakan year & month

  @override
  void initState() {
    super.initState();
    _loadCompleted();
  }

  Future<void> _loadCompleted() async {
    final all = await _repository.getCompletedTodos();
    // urutkan terbaru selesai di atas (pakai createdAt/deadline sebagai proxy)
    all.sort((a, b) => (b.deadline ?? b.createdAt).compareTo(a.deadline ?? a.createdAt));
    
    if (mounted) {
      setState(() {
        _allCompleted = all;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    var list = List<TodoModel>.from(_allCompleted);

    if (_selectedCategory != 'Semua') {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }
    if (_selectedMonth != null) {
      final y = _selectedMonth!.year;
      final m = _selectedMonth!.month;
      list = list.where((t) {
        final d = t.deadline ?? t.createdAt;
        return d.year == y && d.month == m;
      }).toList();
    }

    setState(() {
      _filtered = list;
    });
  }

  List<DateTime> _availableMonths() {
    final dates = <DateTime>[];
    for (final t in _allCompleted) {
      final d = t.deadline ?? t.createdAt;
      final monthKey = DateTime(d.year, d.month);
      if (!dates.any((e) => e.year == monthKey.year && e.month == monthKey.month)) {
        dates.add(monthKey);
      }
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final months = _availableMonths();
    final categories = ['Semua', ...AppConstants.todoCategories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arsip Tugas'),
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Filter bulan
                Expanded(
                  child: DropdownButtonFormField<DateTime>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Bulan'),
                    items: [
                      const DropdownMenuItem<DateTime>(
                        value: null,
                        child: Text('Semua Bulan'),
                      ),
                      ...months.map((m) => DropdownMenuItem<DateTime>(
                            value: m,
                            child: Text(DateFormat('MMMM yyyy', 'id_ID').format(m)),
                          )),
                    ],
                    onChanged: (val) {
                      _selectedMonth = val;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Filter kategori
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      _selectedCategory = val;
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 12),
                        const Text('Belum ada tugas selesai',
                            style: TextStyle(color: AppTheme.textTertiary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final t = _filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.green, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (t.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      t.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentBlue.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          t.category,
                                          style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy', 'id_ID').format(t.deadline ?? t.createdAt),
                                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


