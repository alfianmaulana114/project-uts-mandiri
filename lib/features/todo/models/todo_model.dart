/// Model untuk data tugas (Todo)
/// Menyimpan informasi tentang sebuah tugas
class TodoModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime createdAt;
  final DateTime? reminderDate;
  final DateTime? deadline;
  final bool isCompleted;
  final String? imagePath; // Path gambar yang dilampirkan

  /// Konstruktor untuk membuat instance TodoModel
  TodoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.createdAt,
    this.reminderDate,
    this.deadline,
    this.isCompleted = false,
    this.imagePath,
  });

  /// Membuat instance TodoModel dari JSON
  /// Berguna jika nanti ingin menyimpan data ke database
  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reminderDate: json['reminderDate'] != null
          ? DateTime.parse(json['reminderDate'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
    );
  }

  /// Mengubah instance TodoModel menjadi JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'reminderDate': reminderDate?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'isCompleted': isCompleted,
      'imagePath': imagePath,
    };
  }

  /// Membuat copy dari TodoModel dengan beberapa field yang diubah
  /// Berguna untuk update status atau data tugas
  TodoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    DateTime? createdAt,
    DateTime? reminderDate,
    DateTime? deadline,
    bool? isCompleted,
    String? imagePath,
  }) {
    return TodoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      reminderDate: reminderDate ?? this.reminderDate,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

