import 'dart:io' show File;
import 'package:flutter/material.dart';

/// File helper untuk mobile/platform yang support dart:io
bool isFileAvailable(String path) {
  try {
    // ignore: avoid_slow_async_io
    return File(path).existsSync();
  } catch (e) {
    return false;
  }
}

/// Build image widget untuk mobile (menggunakan file system)
Widget buildImageWidget(String path, {double? height, double? width}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: BoxFit.cover,
  );
}

