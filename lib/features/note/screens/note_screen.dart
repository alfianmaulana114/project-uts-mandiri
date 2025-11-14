import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/widgets/common_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/note_model.dart';
import 'note_add_edit_screen.dart';

// Conditional import untuk File
import 'file_helper.dart' if (dart.library.io) 'file_helper_io.dart' as file_helper;

/// Halaman untuk menampilkan dan mengelola catatan
/// Desain mirip aplikasi Catatan Xiaomi dengan warna abu-abu
class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final _repository = RepositoryProvider().noteRepository;
  List<NoteModel> _notes = [];
  List<NoteModel> _filteredNotes = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  /// Memuat data catatan dari repository
  /// Dipanggil saat screen pertama kali dibuat
  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Filter catatan berdasarkan query pencarian
  void _filterNotes() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredNotes = _notes;
      });
      return;
    }

    setState(() {
      _filteredNotes = _notes.where((note) {
        final titleMatch = note.title.toLowerCase().contains(query);
        final contentMatch = note.content.toLowerCase().contains(query);
        final tagsMatch = note.tags.any((tag) => tag.toLowerCase().contains(query));
        return titleMatch || contentMatch || tagsMatch;
      }).toList();
    });
  }

  /// Mengambil semua catatan dari repository
  Future<void> _loadNotes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      print('🔄 Loading notes...');
      final notes = await _repository.getAllNotes();
      // Urutkan berdasarkan tanggal terbaru
      notes.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      
      print('✅ Loaded ${notes.length} notes');
      
      if (mounted) {
        setState(() {
          _notes = notes;
          _filteredNotes = notes;
          _isLoading = false;
        });
        // Update filter jika ada query
        _filterNotes();
      }
    } catch (e) {
      print('❌ Error loading notes: $e');
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

  /// Navigate ke screen untuk menambahkan catatan baru
  Future<void> _navigateToAddNote() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const NoteAddEditScreen(),
      ),
    );
    if (result == true) {
      // Tambah delay kecil untuk memastikan data sudah tersimpan di Supabase
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadNotes();
    }
  }

  /// Navigate ke screen untuk mengedit catatan
  Future<void> _navigateToEditNote(NoteModel note) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NoteAddEditScreen(note: note),
      ),
    );
    if (result == true) {
      // Tambah delay kecil untuk memastikan data sudah tersimpan di Supabase
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadNotes();
    }
  }

  // Catatan: penambahan/penyuntingan catatan sekarang menggunakan halaman baru

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
  Widget _buildFileImage(String path) {
    // Jika path adalah URL (dari Supabase Storage), gunakan Image.network
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
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
      width: double.infinity,
    );
  }

  /// Menghapus catatan
  /// [note] adalah NoteModel yang akan dihapus
  Future<void> _deleteNote(NoteModel note) async {
    await _repository.deleteNote(note.id);
    // Tambah delay kecil untuk memastikan data sudah terhapus di Supabase
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan berhasil dihapus'),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Menampilkan detail catatan dalam dialog
  /// [note] adalah NoteModel yang akan ditampilkan
  void _showNoteDetails(NoteModel note) {
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
                        color: AppTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.note,
                        color: AppTheme.accentBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (note.tags.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: note.tags.take(3).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      color: AppTheme.accentBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
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
                      // Content text
                      const Text(
                        'Konten',
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
                          note.content,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      // Image
                      if (note.imagePath != null && _isImageAvailable(note.imagePath!)) ...[
                        const SizedBox(height: 20),
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
                          child: _buildFileImage(note.imagePath!),
                        ),
                      ],
                      // Tags (jika lebih dari 3, tampilkan di sini)
                      if (note.tags.length > 3) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Tag',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: note.tags.skip(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: AppTheme.accentBlue,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ] else if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
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
                              'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm').format(note.createdAt)}',
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
                          _navigateToEditNote(note);
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
                          _deleteNote(note);
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

  /// Membuat widget untuk menampilkan satu catatan (card)
  /// [note] adalah NoteModel yang akan ditampilkan
  /// Menggunakan warna abu-abu tetap yang cocok dengan tema
  Widget _buildNoteCard(NoteModel note) {
    // Warna abu-abu tetap untuk semua catatan
    final noteColor = AppTheme.surface;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _showNoteDetails(note),
        onLongPress: () => _deleteNote(note),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: noteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.divider,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                note.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Content preview
              Text(
                note.content,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.fade,
              ),
              // Tags
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: note.tags.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppTheme.accentBlue,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Spacer(),
              // Date
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('dd MMM').format(note.createdAt),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
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
    return Scaffold(
      body: Column(
        children: [
          const CommonHeader(title: 'Catatan'),
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          // Notes grid dengan pull-to-refresh
          Expanded(
            child: _isLoading && _notes.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentBlue,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotes,
                    color: AppTheme.accentBlue,
                    child: _filteredNotes.isEmpty
                        ? EmptyState(
                            icon: _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.note_outlined,
                            message: _searchController.text.isNotEmpty
                                ? 'Tidak ada catatan yang cocok'
                                : 'Belum ada catatan',
                            actionLabel: _searchController.text.isNotEmpty ? null : 'Refresh',
                            onAction: _searchController.text.isNotEmpty ? null : _loadNotes,
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _filteredNotes.length,
                            itemBuilder: (context, index) {
                              return _buildNoteCard(_filteredNotes[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddNote,
        backgroundColor: AppTheme.accentBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Catatan Baru',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
