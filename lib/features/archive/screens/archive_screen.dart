import 'dart:io' if (dart.library.html) 'file_helper_stub.dart' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/widgets/common_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/archive_model.dart';
import 'archive_add_edit_screen.dart';

/// Halaman untuk menampilkan dan mengelola arsip digital
/// Desain mirip aplikasi Catatan Xiaomi dengan layout grid
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _repository = RepositoryProvider().archiveRepository;
  List<ArchiveModel> _archives = [];
  List<ArchiveModel> _filteredArchives = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  /// Memuat data arsip dari repository
  /// Dipanggil saat screen pertama kali dibuat
  @override
  void initState() {
    super.initState();
    _loadArchives();
    _searchController.addListener(_filterArchives);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter arsip berdasarkan query pencarian
  void _filterArchives() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredArchives = _archives;
      });
      return;
    }

    setState(() {
      _filteredArchives = _archives.where((archive) {
        final nameMatch = archive.name.toLowerCase().contains(query);
        final descMatch = archive.description?.toLowerCase().contains(query) ?? false;
        final fileTypeMatch = archive.fileType.toLowerCase().contains(query);
        return nameMatch || descMatch || fileTypeMatch;
      }).toList();
    });
  }

  /// Mengambil semua arsip dari repository
  Future<void> _loadArchives() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      print('🔄 Loading archives...');
      final archives = await _repository.getAllArchives();
      // Urutkan berdasarkan tanggal terbaru
      archives.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      
      print('✅ Loaded ${archives.length} archives');
      
      if (mounted) {
        setState(() {
          _archives = archives;
          _filteredArchives = archives;
          _isLoading = false;
        });
        // Update filter jika ada query
        _filterArchives();
      }
    } catch (e) {
      print('❌ Error loading archives: $e');
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

  /// Menampilkan detail arsip dalam dialog
  /// [archive] adalah ArchiveModel yang akan ditampilkan
  void _showArchiveDetails(ArchiveModel archive) {
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
              // Header dengan icon dan close button
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
                      child: Icon(
                        _getFileTypeIcon(archive.fileType),
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
                            archive.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                              archive.fileType.toUpperCase(),
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
                      if (archive.description != null && archive.description!.isNotEmpty) ...[
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
                            archive.description!,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // File Information
                      if (archive.filePath != null && archive.filePath!.isNotEmpty) ...[
                        const Text(
                          'File',
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
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attach_file,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  archive.filePath!,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                              'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm').format(archive.createdAt)}',
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
                child: Column(
                  children: [
                    // Primary actions (Buka & Kirim)
                    if (archive.filePath != null && archive.filePath!.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _openFile(archive);
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Buka'),
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
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _shareFile(archive);
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Kirim'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (archive.filePath != null && archive.filePath!.isNotEmpty)
                      const SizedBox(height: 12),
                    // Secondary actions (Edit & Hapus)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArchiveAddEditScreen(archive: archive),
                                ),
                              );
                              if (result == true) {
                                await Future.delayed(const Duration(milliseconds: 500));
                                await _loadArchives();
                              }
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
                            onPressed: () => _deleteArchive(archive),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menghapus arsip
  /// [archive] adalah ArchiveModel yang akan dihapus
  Future<void> _deleteArchive(ArchiveModel archive) async {
    await _repository.deleteArchive(archive.id);
    Navigator.pop(context); // Close dialog
    // Tambah delay kecil untuk memastikan data sudah terhapus di Supabase
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadArchives();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Arsip berhasil dihapus'),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Membuka file dengan aplikasi eksternal
  /// [archive] adalah ArchiveModel yang akan dibuka
  Future<void> _openFile(ArchiveModel archive) async {
    if (archive.filePath == null || archive.filePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File tidak ditemukan'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    try {
      String filePath = archive.filePath!;

      // Jika file path adalah URL (dari Supabase Storage atau web)
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        if (kIsWeb) {
          // Di web, buka URL di browser baru menggunakan url_launcher atau window.open
          // Untuk sementara, tampilkan pesan
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File URL: $filePath'),
                action: SnackBarAction(
                  label: 'Salin',
                  onPressed: () {
                    // Copy to clipboard - bisa ditambahkan jika perlu
                  },
                ),
              ),
            );
          }
          return;
        } else {
          // Download file terlebih dahulu
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengunduh file...'),
              duration: Duration(seconds: 1),
            ),
          );

          final response = await http.get(Uri.parse(filePath));
          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            if (!kIsWeb) {
              final tempDir = await getTemporaryDirectory();
              final fileName = archive.name;
              final file = File('${tempDir.path}/$fileName');
              await file.writeAsBytes(bytes);
              filePath = file.path;
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Membuka file URL di web tidak didukung'),
                  ),
                );
              }
              return;
            }
          } else {
            throw Exception('Gagal mengunduh file');
          }
        }
      }

      // Buka file dengan aplikasi eksternal (hanya untuk non-web)
      if (!kIsWeb) {
        final result = await OpenFile.open(filePath);

        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tidak dapat membuka file: ${result.message}'),
                backgroundColor: AppTheme.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membuka file: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  /// Mengirim/membagikan file
  /// [archive] adalah ArchiveModel yang akan dikirim
  Future<void> _shareFile(ArchiveModel archive) async {
    if (archive.filePath == null || archive.filePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File tidak ditemukan'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    try {
      String filePath = archive.filePath!;
      XFile? file;

      // Jika file path adalah URL, download terlebih dahulu
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        if (kIsWeb) {
          // Di web, share URL
          await Share.share(
            '${archive.name}\n\n$filePath',
            subject: archive.name,
          );
          return;
        } else {
          // Download file untuk share
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengunduh file...'),
              duration: Duration(seconds: 1),
            ),
          );

          final response = await http.get(Uri.parse(filePath));
          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            if (!kIsWeb) {
              final tempDir = await getTemporaryDirectory();
              final fileName = archive.name;
              final downloadedFile = File('${tempDir.path}/$fileName');
              await downloadedFile.writeAsBytes(bytes);
              filePath = downloadedFile.path;
              file = XFile(filePath);
            } else {
              // Di web, share URL saja
              await Share.share(
                '${archive.name}\n\n$filePath',
                subject: archive.name,
              );
              return;
            }
          } else {
            throw Exception('Gagal mengunduh file');
          }
        }
      } else {
        // Local file path
        if (kIsWeb) {
          // Di web, tidak bisa share file langsung
          await Share.share(
            '${archive.name}\n\nFile: ${archive.filePath}',
            subject: archive.name,
          );
          return;
        } else {
          if (!kIsWeb) {
            final localFile = File(filePath);
            if (await localFile.exists()) {
              file = XFile(filePath);
            } else {
              throw Exception('File tidak ditemukan di path: $filePath');
            }
          }
        }
      }

      // Share file
      if (file != null) {
        await Share.shareXFiles(
          [file],
          text: archive.description ?? archive.name,
          subject: archive.name,
        );
      }
    } catch (e) {
      print('❌ Error sharing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membagikan file: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  /// Mendapatkan icon berdasarkan tipe file
  /// [fileType] adalah tipe file (pdf, doc, image, dll)
  IconData _getFileTypeIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'image':
      case 'jpg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Membuat widget untuk menampilkan satu arsip (card)
  /// [archive] adalah ArchiveModel yang akan ditampilkan
  /// Menggunakan layout grid seperti NoteScreen
  Widget _buildArchiveCard(ArchiveModel archive) {
    final archiveColor = AppTheme.surface;

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
        onTap: () => _showArchiveDetails(archive),
        onLongPress: () => _deleteArchive(archive),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: archiveColor,
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
              // File icon dan name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileTypeIcon(archive.fileType),
                      color: AppTheme.accentBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      archive.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description preview
              if (archive.description != null) ...[
                Text(
                  archive.description!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.fade,
                ),
                const SizedBox(height: 12),
              ],
              const Spacer(),
              // File type dan date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      archive.fileType.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.accentBlue,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM').format(archive.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
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
          const CommonHeader(title: 'Arsip Digital'),
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari arsip...',
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
          Expanded(
            child: _isLoading && _archives.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentBlue,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadArchives,
                    color: AppTheme.accentBlue,
                    child: _filteredArchives.isEmpty
                        ? EmptyState(
                            icon: _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.archive_outlined,
                            message: _searchController.text.isNotEmpty
                                ? 'Tidak ada arsip yang cocok'
                                : 'Tidak ada arsip',
                            actionLabel: _searchController.text.isNotEmpty ? null : 'Refresh',
                            onAction: _searchController.text.isNotEmpty ? null : _loadArchives,
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _filteredArchives.length,
                            itemBuilder: (context, index) {
                              return _buildArchiveCard(_filteredArchives[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const ArchiveAddEditScreen(),
            ),
          );
          if (result == true) {
            // Tambah delay kecil untuk memastikan data sudah tersimpan di Supabase
            await Future.delayed(const Duration(milliseconds: 500));
            await _loadArchives();
          }
        },
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Arsip'),
      ),
    );
  }
}

