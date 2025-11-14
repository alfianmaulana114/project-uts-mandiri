import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../models/todo_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';

/// Screen untuk menambah atau mengedit tugas
/// Desain mirip Notion dark mode dengan dukungan gambar
class TodoAddEditScreen extends StatefulWidget {
  final TodoModel? todo; // Jika null berarti tambah baru, jika ada berarti edit

  const TodoAddEditScreen({super.key, this.todo});

  @override
  State<TodoAddEditScreen> createState() => _TodoAddEditScreenState();
}

class _TodoAddEditScreenState extends State<TodoAddEditScreen> {
  final _repository = RepositoryProvider().todoRepository;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  
  String _selectedCategory = 'Umum';
  DateTime? _selectedDeadline;
  String? _imagePath; // Bisa berupa path lokal atau URL Supabase
  String? _localImagePath; // Path lokal sementara sebelum upload
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Jika edit mode, isi form dengan data yang ada
    if (widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _descriptionController.text = widget.todo!.description;
      _selectedCategory = widget.todo!.category;
      _selectedDeadline = widget.todo!.deadline;
      _imagePath = widget.todo!.imagePath;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
          folder: 'todos',
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

  /// Memilih tanggal dan waktu deadline
  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentBlue,
              onPrimary: Colors.white,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: _selectedDeadline != null
            ? TimeOfDay.fromDateTime(_selectedDeadline!)
            : TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.accentBlue,
                onPrimary: Colors.white,
                surface: AppTheme.surface,
                onSurface: AppTheme.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedDeadline = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  /// Menyimpan atau update tugas
  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.todo == null) {
        // Tambah baru
        final newTodo = TodoModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          createdAt: DateTime.now(),
          deadline: _selectedDeadline,
          imagePath: _imagePath,
        );
        await _repository.addTodo(newTodo);
      } else {
        // Update existing
        final updatedTodo = widget.todo!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          deadline: _selectedDeadline,
          imagePath: _imagePath,
        );
        await _repository.updateTodo(updatedTodo);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        print('❌ Error saving todo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menyimpan: ${e.toString()}'),
            backgroundColor: AppTheme.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    } finally {
      if (mounted && !_isSaving) {
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
          widget.todo == null ? 'Tugas Baru' : 'Edit Tugas',
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
              onPressed: (_isUploading) ? null : _saveTodo,
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
                  labelText: 'Judul Tugas',
                  hintText: 'Masukkan judul tugas',
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

              // Deskripsi
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  hintText: 'Masukkan deskripsi tugas',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 6,
              ),
              const SizedBox(height: 24),

              // Kategori
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: AppConstants.todoCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Deadline
              InkWell(
                onTap: _selectDeadline,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.accentBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDeadline == null
                              ? 'Pilih Tenggat Waktu (Opsional)'
                              : DateFormat('dd MMM yyyy, HH:mm').format(_selectedDeadline!),
                          style: TextStyle(
                            color: _selectedDeadline == null
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_selectedDeadline != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          color: AppTheme.textSecondary,
                          onPressed: () {
                            setState(() {
                              _selectedDeadline = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
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

