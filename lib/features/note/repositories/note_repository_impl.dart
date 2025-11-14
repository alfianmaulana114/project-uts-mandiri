import '../models/note_model.dart';
import '../data/note_data_source.dart';
import '../repositories/note_repository.dart';

/// Implementasi konkret dari NoteRepository
class NoteRepositoryImpl implements NoteRepository {
  final NoteDataSource _dataSource;

  NoteRepositoryImpl({NoteDataSource? dataSource})
      : _dataSource = dataSource ?? NoteDataSource();

  @override
  Future<List<NoteModel>> getAllNotes() async {
    return _dataSource.getAllNotesAsync();
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    final notes = await getAllNotes();
    try {
      return notes.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addNote(NoteModel note) async {
    _dataSource.addNote(note);
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    _dataSource.updateNote(note);
  }

  @override
  Future<void> deleteNote(String id) async {
    _dataSource.deleteNote(id);
  }

  @override
  Future<List<NoteModel>> getNotesByTag(String tag) async {
    final notes = await getAllNotes();
    return notes.where((note) => note.tags.contains(tag)).toList();
  }

  @override
  Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final allTags = <String>[];
    for (final note in notes) {
      allTags.addAll(note.tags);
    }
    return allTags.toSet().toList();
  }
}

