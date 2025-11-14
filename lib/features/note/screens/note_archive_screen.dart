import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../models/note_model.dart';

/// Arsip Catatan: menampilkan catatan dengan filter per-bulan dan per-tag
class NoteArchiveScreen extends StatefulWidget {
  const NoteArchiveScreen({super.key});

  @override
  State<NoteArchiveScreen> createState() => _NoteArchiveScreenState();
}

class _NoteArchiveScreenState extends State<NoteArchiveScreen> {
  final _repository = RepositoryProvider().noteRepository;
  List<NoteModel> _allNotes = [];
  List<NoteModel> _filtered = [];
  DateTime? _selectedMonth;
  String _selectedTag = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _repository.getAllNotes();
    notes.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    if (mounted) {
      setState(() {
        _allNotes = notes;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    var list = List<NoteModel>.from(_allNotes);
    if (_selectedTag != 'Semua') {
      list = list.where((n) => n.tags.contains(_selectedTag)).toList();
    }
    if (_selectedMonth != null) {
      final y = _selectedMonth!.year;
      final m = _selectedMonth!.month;
      list = list.where((n) {
        final d = n.updatedAt ?? n.createdAt;
        return d.year == y && d.month == m;
      }).toList();
    }
    setState(() {
      _filtered = list;
    });
  }

  List<DateTime> _availableMonths() {
    final set = <DateTime>[];
    for (final n in _allNotes) {
      final d = n.updatedAt ?? n.createdAt;
      final key = DateTime(d.year, d.month);
      if (!set.any((e) => e.year == key.year && e.month == key.month)) set.add(key);
    }
    set.sort((a, b) => b.compareTo(a));
    return set;
  }

  @override
  Widget build(BuildContext context) {
    final months = _availableMonths();
    return FutureBuilder<List<String>>(
      future: _repository.getAllTags(),
      builder: (context, snapshot) {
        final allTags = ['Semua', ...(snapshot.data ?? [])];

        return Scaffold(
      appBar: AppBar(title: const Text('Arsip Catatan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DateTime>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Bulan'),
                    items: const [
                      DropdownMenuItem<DateTime>(value: null, child: Text('Semua Bulan')),
                    ]
                        .followedBy(months.map((m) => DropdownMenuItem<DateTime>(
                              value: m,
                              child: Text(DateFormat('MMMM yyyy', 'id_ID').format(m)),
                            )))
                        .toList(),
                    onChanged: (v) {
                      _selectedMonth = v;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTag,
                    decoration: const InputDecoration(labelText: 'Tag'),
                    items: allTags
                        .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      _selectedTag = v;
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 12),
                        const Text('Tidak ada catatan',
                            style: TextStyle(color: AppTheme.textTertiary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final n = _filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (n.imagePath != null && File(n.imagePath!).existsSync()) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(n.imagePath!),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...n.tags.take(3).map((tag) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentBlue.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(tag,
                                                style: const TextStyle(
                                                    color: AppTheme.accentBlue, fontSize: 10)),
                                          )),
                                      Text(
                                        DateFormat('dd MMM yyyy', 'id_ID')
                                            .format(n.updatedAt ?? n.createdAt),
                                        style: const TextStyle(
                                            color: AppTheme.textTertiary, fontSize: 11),
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
      },
    );
  }
}


