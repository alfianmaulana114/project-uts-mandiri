import '../../features/todo/repositories/todo_repository.dart';
import '../../features/todo/repositories/todo_repository_impl.dart';
import '../../features/todo/data/todo_data_source.dart';
import '../../features/note/repositories/note_repository.dart';
import '../../features/note/repositories/note_repository_impl.dart';
import '../../features/note/data/note_data_source.dart';
import '../../features/archive/repositories/archive_repository.dart';
import '../../features/archive/repositories/archive_repository_impl.dart';
import '../../features/archive/data/archive_data_source.dart';
import '../../features/weather/repositories/weather_repository.dart';
import '../../features/weather/repositories/weather_repository_impl.dart';
import '../../features/weather/data/weather_data_source.dart';

/// Provider untuk dependency injection
/// Mengikuti prinsip SOLID - Dependency Inversion
/// Semua repository diinisialisasi di sini agar mudah diubah nanti
class RepositoryProvider {
  // Singleton pattern
  static final RepositoryProvider _instance = RepositoryProvider._internal();
  factory RepositoryProvider() => _instance;
  RepositoryProvider._internal();

  // Repository instances
  late final TodoRepository _todoRepository;
  late final NoteRepository _noteRepository;
  late final ArchiveRepository _archiveRepository;
  late final WeatherRepository _weatherRepository;

  /// Inisialisasi semua repository
  void init() {
    // Initialize data sources
    final todoDataSource = TodoDataSource();
    final noteDataSource = NoteDataSource();
    final archiveDataSource = ArchiveDataSource();
    final weatherDataSource = WeatherDataSource();

    // Initialize repositories with their data sources
    _todoRepository = TodoRepositoryImpl(dataSource: todoDataSource);
    _noteRepository = NoteRepositoryImpl(dataSource: noteDataSource);
    _archiveRepository = ArchiveRepositoryImpl(dataSource: archiveDataSource);
    _weatherRepository = WeatherRepositoryImpl(dataSource: weatherDataSource);
  }

  // Getters untuk mengakses repository
  TodoRepository get todoRepository => _todoRepository;
  NoteRepository get noteRepository => _noteRepository;
  ArchiveRepository get archiveRepository => _archiveRepository;
  WeatherRepository get weatherRepository => _weatherRepository;
}

