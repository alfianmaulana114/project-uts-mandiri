/// Model untuk data catatan (Note)
/// Menyimpan informasi tentang sebuah catatan
class NoteModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String color; // Warna catatan (hex color)
  final List<String> tags; // Tag/kategori catatan
  final String? imagePath; // Path gambar yang dilampirkan

  /// Konstruktor untuk membuat instance NoteModel
  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.color = '#FFFFFF',
    this.tags = const [],
    this.imagePath,
  });

  /// Membuat instance NoteModel dari JSON
  /// Berguna jika nanti ingin menyimpan data ke database
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      color: json['color'] as String? ?? '#FFFFFF',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((tag) => tag as String)
              .toList() ??
          [],
      imagePath: json['imagePath'] as String?,
    );
  }

  /// Mengubah instance NoteModel menjadi JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'color': color,
      'tags': tags,
      'imagePath': imagePath,
    };
  }

  /// Membuat copy dari NoteModel dengan beberapa field yang diubah
  /// Berguna untuk update data catatan
  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
    List<String>? tags,
    String? imagePath,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      tags: tags ?? this.tags,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

