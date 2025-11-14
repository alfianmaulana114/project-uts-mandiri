import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../models/archive_model.dart';

/// Halaman tambah / edit Arsip Digital
class ArchiveAddEditScreen extends StatefulWidget {
  final ArchiveModel? archive;
  const ArchiveAddEditScreen({super.key, this.archive});

  @override
  State<ArchiveAddEditScreen> createState() => _ArchiveAddEditScreenState();
}

class _ArchiveAddEditScreenState extends State<ArchiveAddEditScreen> {
  final _repository = RepositoryProvider().archiveRepository;
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _fileType;
  String? _pickedFileName;
  String? _pickedFilePath; // Path lokal sementara atau URL Supabase
  String? _localFilePath; // Path lokal sementara sebelum upload
  bool _isUploading = false;

  final List<String> _fileTypes = const ['pdf', 'doc', 'image', 'file'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.archive?.name ?? '');
    _descController = TextEditingController(text: widget.archive?.description ?? '');
    _fileType = widget.archive?.fileType ?? 'file';
    _pickedFilePath = widget.archive?.filePath;
    if (widget.archive?.filePath != null) {
      // Extract filename dari path atau URL
      final pathStr = widget.archive!.filePath!;
      if (pathStr.startsWith('http://') || pathStr.startsWith('https://')) {
        _pickedFileName = path.basename(pathStr.split('?').first);
      } else {
        _pickedFileName = path.basename(pathStr);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.archive == null) {
      final newArchive = ArchiveModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        createdAt: DateTime.now(),
        fileType: _fileType,
        filePath: _pickedFilePath,
      );
      await _repository.addArchive(newArchive);
    } else {
      final updated = widget.archive!.copyWith(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        fileType: _fileType,
        filePath: _pickedFilePath ?? widget.archive!.filePath,
      );
      await _repository.updateArchive(updated);
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickFile() async {
    try {
      final XFile? file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'All Files')]);
      if (file != null) {
        if (kIsWeb) {
          // Di web, file.path bisa null, jadi kita perlu handle berbeda
          setState(() {
            _pickedFileName = file.name;
            _pickedFilePath = file.path; // Bisa null di web
            final ext = (file.name.split('.').last).toLowerCase();
            if (ext == 'pdf') _fileType = 'pdf';
            else if (ext == 'doc' || ext == 'docx') _fileType = 'doc';
            else if (['png','jpg','jpeg','webp'].contains(ext)) _fileType = 'image';
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload file di web belum didukung. Gunakan aplikasi mobile.'),
                backgroundColor: AppTheme.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _isUploading = true;
          _localFilePath = file.path;
          _pickedFileName = file.name;
          final ext = (file.name.split('.').last).toLowerCase();
          if (ext == 'pdf') _fileType = 'pdf';
          else if (ext == 'doc' || ext == 'docx') _fileType = 'doc';
          else if (['png','jpg','jpeg','webp'].contains(ext)) _fileType = 'image';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengupload file...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Upload ke Supabase Storage
        final fileUrl = await _storageService.uploadFile(
          filePath: file.path,
          fileName: file.name,
          bucket: 'files',
          folder: 'archives',
        );

        setState(() {
          _pickedFilePath = fileUrl;
          _localFilePath = file.path;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File berhasil diupload'),
              backgroundColor: AppTheme.accentBlue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _localFilePath = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengupload file: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.archive != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Arsip' : 'Arsip Baru'),
        actions: [
          if (_isUploading)
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
              onPressed: (_isUploading) ? null : _save,
              child: const Text('Simpan', style: TextStyle(color: AppTheme.accentBlue)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Arsip',
                  hintText: 'Contoh: Dokumen KTP',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Row(
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentBlue,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Mengupload file...',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file, color: AppTheme.accentBlue),
                  label: Text(
                    _pickedFileName == null ? 'Pilih File (opsional)' : _pickedFileName!,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _fileType,
                items: _fileTypes
                    .map((t) => DropdownMenuItem<String>(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _fileType = v ?? 'file'),
                decoration: const InputDecoration(labelText: 'Tipe File'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  hintText: 'Tuliskan deskripsi singkat arsip',
                ),
              ),
              const SizedBox(height: 24),
              if (isEdit && widget.archive!.createdAt != null)
                Text(
                  'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(widget.archive!.createdAt)}',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: (_isUploading)
          ? null
          : FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save),
              label: const Text('Simpan'),
            ),
    );
  }
}


