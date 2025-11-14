import 'package:flutter/material.dart';

/// Stub file helper untuk web platform
/// File system operations tidak tersedia di web
bool isFileAvailable(String path) {
  // Di web, asumsikan file selalu tersedia jika path tidak kosong
  return path.isNotEmpty;
}

/// Build image widget untuk web (menggunakan network)
Widget buildImageWidget(String path, {double? height, double? width}) {
  return Image.network(
    path,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
  );
}

