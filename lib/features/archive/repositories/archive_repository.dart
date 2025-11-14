import '../models/archive_model.dart';

/// Abstraksi repository untuk pengelolaan data Archive
abstract class ArchiveRepository {
  /// Mengambil semua arsip
  Future<List<ArchiveModel>> getAllArchives();

  /// Mengambil arsip berdasarkan ID
  Future<ArchiveModel?> getArchiveById(String id);

  /// Menambahkan arsip baru
  Future<void> addArchive(ArchiveModel archive);

  /// Mengupdate arsip
  Future<void> updateArchive(ArchiveModel archive);

  /// Menghapus arsip berdasarkan ID
  Future<void> deleteArchive(String id);

  /// Mengambil arsip berdasarkan tipe file
  Future<List<ArchiveModel>> getArchivesByType(String fileType);
}

