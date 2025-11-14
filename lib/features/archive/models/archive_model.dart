/// Model untuk data arsip digital
/// Menyimpan informasi tentang sebuah file arsip
class ArchiveModel {
  final String id;
  final String name; // Nama file/arsip
  final String? filePath; // Path file yang diupload (untuk nanti)
  final String? description; // Deskripsi arsip
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String fileType; // Tipe file (pdf, doc, image, dll)

  /// Konstruktor untuk membuat instance ArchiveModel
  ArchiveModel({
    required this.id,
    required this.name,
    this.filePath,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.fileType = 'file',
  });

  /// Membuat instance ArchiveModel dari JSON
  /// Berguna jika nanti ingin menyimpan data ke database
  factory ArchiveModel.fromJson(Map<String, dynamic> json) {
    return ArchiveModel(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      fileType: json['fileType'] as String? ?? 'file',
    );
  }

  /// Mengubah instance ArchiveModel menjadi JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'fileType': fileType,
    };
  }

  /// Membuat copy dari ArchiveModel dengan beberapa field yang diubah
  /// Berguna untuk update data arsip
  ArchiveModel copyWith({
    String? id,
    String? name,
    String? filePath,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fileType,
  }) {
    return ArchiveModel(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileType: fileType ?? this.fileType,
    );
  }
}

