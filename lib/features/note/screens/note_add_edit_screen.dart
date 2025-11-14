import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../models/note_model.dart';

/// Screen untuk menambah atau mengedit catatan
/// Desain mirip Notion dark mode dengan dukungan gambar
class NoteAddEditScreen extends StatefulWidget {
  final NoteModel? note; // Jika null berarti tambah baru, jika ada berarti edit

  const NoteAddEditScreen({super.key, this.note});

  @override
  State<NoteAddEditScreen> createState() => _NoteAddEditScreenState();
}

class _NoteAddEditScreenState extends State<NoteAddEditScreen> {
  final _repository = RepositoryProvider().noteRepository;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  
  String? _imagePath; // Bisa berupa path lokal atau URL Supabase
  String? _localImagePath; // Path lokal sementara sebelum upload
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Jika edit mode, isi form dengan data yang ada
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imagePath = widget.note!.imagePath;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Memilih gambar dari galeri atau kamera dan upload ke Supabase
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _isUploading = true;
          _localImagePath = image.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengupload gambar...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Upload ke Supabase Storage
        final fileName = path.basename(image.path);
        final imageUrl = await _storageService.uploadFile(
          filePath: image.path,
          fileName: fileName,
          bucket: 'files',
          folder: 'notes',
        );

        setState(() {
          _imagePath = imageUrl;
          _localImagePath = image.path;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar berhasil diupload'),
              backgroundColor: AppTheme.accentBlue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _localImagePath = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengupload gambar: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  /// Menampilkan dialog pilihan sumber gambar
  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accentBlue),
              title: const Text('Pilih dari Galeri', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accentBlue),
              title: const Text('Ambil Foto', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.red),
                title: const Text('Hapus Gambar', style: TextStyle(color: AppTheme.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imagePath = null;
                    _localImagePath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Menyimpan atau update catatan
  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.note == null) {
        // Tambah baru
        final newNote = NoteModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          content: _contentController.text,
          createdAt: DateTime.now(),
          color: AppConstants.defaultNoteColor,
          imagePath: _imagePath,
        );
        await _repository.addNote(newNote);
      } else {
        // Update existing
        final updatedNote = widget.note!.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          updatedAt: DateTime.now(),
          imagePath: _imagePath,
        );
        await _repository.updateNote(updatedNote);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menyimpan: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Build image widget dari path lokal atau URL Supabase
  Widget _buildImageWidget(String imagePath) {
    // Jika path adalah URL (dimulai dengan http), gunakan Image.network
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: 200,
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
    } else {
      // Jika path lokal, gunakan Image.file
      if (kIsWeb || !File(imagePath).existsSync()) {
        return Container(
          width: double.infinity,
          height: 200,
          color: AppTheme.surface,
          child: const Center(
            child: Icon(Icons.broken_image, color: AppTheme.textSecondary),
          ),
        );
      }
      return Image.file(
        File(imagePath),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.note == null ? 'Catatan Baru' : 'Edit Catatan',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          if (_isSaving || _isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentBlue,
                ),
              ),
            )
          else
            TextButton(
              onPressed: (_isUploading) ? null : _saveNote,
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  hintText: 'Masukkan judul catatan',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Judul wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Konten
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Isi Catatan',
                  hintText: 'Masukkan isi catatan',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 12,
              ),
              const SizedBox(height: 24),

              // Gambar
              Text(
                'Gambar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_isUploading)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.accentBlue),
                        SizedBox(height: 12),
                        Text(
                          'Mengupload gambar...',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_imagePath != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImageWidget(_imagePath!),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _imagePath = null;
                                _localImagePath = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _showImagePickerDialog,
                icon: const Icon(Icons.add_photo_alternate, color: AppTheme.accentBlue),
                label: Text(
                  _imagePath != null ? 'Ganti Gambar' : 'Tambahkan Gambar',
                  style: const TextStyle(color: AppTheme.accentBlue),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

