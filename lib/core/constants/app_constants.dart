/// Konstanta aplikasi yang digunakan di seluruh aplikasi
class AppConstants {
  AppConstants._(); // Private constructor untuk mencegah instantiasi

  // Kategori Todo
  static const List<String> todoCategories = [
    'Kuliah',
    'Belajar Mandiri',
    'Pekerjaan',
    'Organisasi',
    'Umum',
  ];

  // Warna default untuk Note
  static const String defaultNoteColor = '#2E2E2E';

  // Tipe file Archive
  static const String archiveFileTypePdf = 'pdf';
  static const String archiveFileTypeDoc = 'doc';
  static const String archiveFileTypeImage = 'image';
  static const String archiveFileTypeFile = 'file';

  // Ekstensi file yang didukung
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> pdfExtensions = ['pdf'];
  static const List<String> docExtensions = ['doc', 'docx'];
}

