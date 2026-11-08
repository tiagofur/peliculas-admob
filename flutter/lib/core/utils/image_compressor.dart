import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../logging/logger_factory.dart';

class ImageCompressor {
  const ImageCompressor();

  Future<Uint8List> compress(
    Uint8List bytes, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 85,
    CompressFormat format = CompressFormat.jpeg,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: format,
      );

      LoggerFactory.debug(
        'ImageCompressor: compressed image from ${bytes.length} bytes to ${result.length} bytes',
      );

      return result;
    } catch (error) {
      LoggerFactory.error('ImageCompressor: failed to compress image: $error');
      rethrow;
    }
  }
}
