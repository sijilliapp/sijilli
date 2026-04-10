import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class ImageSaverUtil {
  static final Dio _dio = Dio();

  /// Downloads an image from [url] and saves it to the gallery.
  /// [fileName] is the name of the file to save.
  static Future<bool> saveImageFromUrl(String url, String fileName) async {
    try {
      // 1. Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/$fileName';

      // 2. Download the file
      await _dio.download(url, path);

      // 3. Save to gallery using Gal
      await Gal.putImage(path);

      // 4. Clean up temp file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      print('❌ Error saving image: $e');
      return false;
    }
  }

  /// Request gallery permission if needed (Gal handles this usually but good for explicit checks)
  static Future<bool> hasAccess() async {
    return await Gal.hasAccess();
  }

  static Future<void> requestAccess() async {
    await Gal.requestAccess();
  }
}
