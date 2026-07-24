import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class AudioCacheManager {
  static final AudioCacheManager instance = AudioCacheManager._internal();
  AudioCacheManager._internal();

  final Map<String, bool> _downloadingUrls = {};

  /// Checks if a network audio file is cached locally. If yes, returns local path.
  /// If no, triggers background download and returns the original URL immediately so playback is not delayed.
  Future<String> getAudioSource(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url; // Local file path or asset
    }

    // الويب لا يدعم الكاش المحلي — نعيد الـ URL مباشرة
    if (kIsWeb) return url;

    try {
      final cacheDir = await getTemporaryDirectory();
      final audioCacheDir = Directory('${cacheDir.path}/audio_cache');
      if (!await audioCacheDir.exists()) {
        await audioCacheDir.create(recursive: true);
      }

      // Generate a safe unique filename based on the URL path segment
      final uri = Uri.parse(url);
      final rawName = uri.pathSegments.last;
      final cleanName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_');
      final localFile = File('${audioCacheDir.path}/$cleanName');

      if (await localFile.exists()) {
        final length = await localFile.length();
        if (length > 0) {
          debugPrint('🎧 AudioCacheManager: Cache HIT for $url -> ${localFile.path}');
          return localFile.path;
        }
      }

      // Cache MISS - trigger download in background if not already downloading
      if (_downloadingUrls[url] != true) {
        _downloadingUrls[url] = true;
        _downloadInBackground(url, localFile);
      }

    } catch (e) {
      debugPrint('❌ AudioCacheManager error: $e');
    }

    return url; // Fallback to network URL immediately
  }

  Future<void> _downloadInBackground(String url, File localFile) async {
    if (kIsWeb) return; // لا كاش على الويب
    try {
      debugPrint('📥 AudioCacheManager: Starting background download for $url');
      final client = HttpClient();
      
      // Set connection and response timeouts
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        // limit download size to 30MB
        final contentLength = response.contentLength;
        if (contentLength > 30 * 1024 * 1024) {
          debugPrint('⚠️ AudioCacheManager: Audio file too large (${(contentLength / 1024 / 1024).toStringAsFixed(1)}MB), skipping cache.');
          return;
        }

        final tempFile = File('${localFile.path}.tmp');
        final ios = tempFile.openWrite();
        await response.pipe(ios);
        await ios.close();

        // Rename temp file to final destination once download completes successfully
        await tempFile.rename(localFile.path);
        debugPrint('✅ AudioCacheManager: Successfully cached $url -> ${localFile.path}');
      } else {
        debugPrint('❌ AudioCacheManager: Download failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ AudioCacheManager download error: $e');
    } finally {
      _downloadingUrls.remove(url);
    }
  }
}
