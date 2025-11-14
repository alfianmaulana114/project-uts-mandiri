import '../models/archive_model.dart';
import '../data/archive_data_source.dart';
import '../repositories/archive_repository.dart';

/// Implementasi konkret dari ArchiveRepository
class ArchiveRepositoryImpl implements ArchiveRepository {
  final ArchiveDataSource _dataSource;

  ArchiveRepositoryImpl({ArchiveDataSource? dataSource})
      : _dataSource = dataSource ?? ArchiveDataSource();

  @override
  Future<List<ArchiveModel>> getAllArchives() async {
    return _dataSource.getAllArchives();
  }

  @override
  Future<ArchiveModel?> getArchiveById(String id) async {
    final archives = await getAllArchives();
    try {
      return archives.firstWhere((archive) => archive.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addArchive(ArchiveModel archive) async {
    _dataSource.addArchive(archive);
  }

  @override
  Future<void> updateArchive(ArchiveModel archive) async {
    _dataSource.updateArchive(archive);
  }

  @override
  Future<void> deleteArchive(String id) async {
    _dataSource.deleteArchive(id);
  }

  @override
  Future<List<ArchiveModel>> getArchivesByType(String fileType) async {
    final archives = await getAllArchives();
    return archives.where((archive) => archive.fileType == fileType).toList();
  }
}

