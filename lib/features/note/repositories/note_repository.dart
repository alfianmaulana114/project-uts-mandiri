import '../models/note_model.dart';

/// Abstraksi repository untuk pengelolaan data Note
/// Mengikuti prinsip SOLID - Dependency Inversion Principle
abstract class NoteRepository {
  /// Mengambil semua catatan
  Future<List<NoteModel>> getAllNotes();

  /// Mengambil catatan berdasarkan ID
  Future<NoteModel?> getNoteById(String id);

  /// Menambahkan catatan baru
  Future<void> addNote(NoteModel note);

  /// Mengupdate catatan
  Future<void> updateNote(NoteModel note);

  /// Menghapus catatan berdasarkan ID
  Future<void> deleteNote(String id);

  /// Mengambil catatan berdasarkan tag
  Future<List<NoteModel>> getNotesByTag(String tag);

  /// Mengambil semua tag yang ada
  Future<List<String>> getAllTags();
}

