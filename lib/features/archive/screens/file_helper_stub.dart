// Stub untuk File di web platform
class File {
  final String _path;
  File(this._path);
  
  String get path => _path;
  
  Future<bool> exists() async => false;
  
  Future<File> writeAsBytes(List<int> bytes) async {
    throw UnsupportedError('File operations not supported on web');
  }
}

