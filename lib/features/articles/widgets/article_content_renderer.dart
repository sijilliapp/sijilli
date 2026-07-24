import 'package:flutter/material.dart';
import 'package:sijilli/core/utils/audio_helper.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/image_saver_util.dart';
import 'poetry/poem_view.dart';
import 'poetry/poem_formatter_utils.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/utils/bidi_utils.dart';
import 'inline_audio_player.dart';
import 'advanced_audio_player.dart';
import 'youtube_video_with_actions.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/article_provider.dart';
import '../../../core/providers/settings_provider.dart';

class ArticleContentRenderer extends StatelessWidget {
  final String text;
  final String? fontFamily;
  final List<String>? audioUrls;
  final List<String>? imageFiles;
  final String? articleId;
  final Function(String text, String audioUrl, bool isFinal)? onTextGenerated;
  final Function(String updatedText)? onTextUpdated;
  final Map<String, dynamic>? audioMetadata;
  final Function(Map<String, dynamic> updatedMetadata)? onMetadataUpdated;

  const ArticleContentRenderer({
    super.key,
    required this.text,
    this.fontFamily,
    this.audioUrls,
    this.imageFiles,
    this.articleId,
    this.onTextGenerated,
    this.onTextUpdated,
    this.audioMetadata,
    this.onMetadataUpdated,
  });

  TextSpan _parseInlineFormatting(String text, BuildContext context, {bool isJustified = false}) {
    const double fontSize = 22.0;
    const double lineHeight = 1.75;

    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: AppColors.getTextPrimary(context),
      fontWeight: FontWeight.w600, // Thickened to w600 for better clarity and sharpness
      wordSpacing: isJustified ? -0.4 : 0.0, // Prevent huge gaps when justifying
    );

    final defaultStyle = ThemeProvider.getTextStyleForFont(fontFamily ?? 'Default', baseStyle);

    return TextSpan(
      children: PoemFormatterUtils.parseInlineText(text, defaultStyle, context),
    );
  }

  String? _extractImageUrl(String line) {
    final trimmed = line.trim();
    if (trimmed.contains(' ')) {
      final markdownRegex = RegExp(r'^!\[.*?\]\((https?://\S+?)\)$', caseSensitive: false);
      final markdownMatch = markdownRegex.firstMatch(trimmed);
      if (markdownMatch != null) {
        return markdownMatch.group(1);
      }
      return null;
    }
    
    if (!trimmed.startsWith(RegExp(r'https?://'))) return null;
    
    final urlRegex = RegExp(
      r'^https?://[^\s/$.?#].[^\s]*\.(?:jpg|jpeg|png|webp|gif|bmp)(?:\?\S*)?$',
      caseSensitive: false,
    );
    if (urlRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    if (trimmed.contains('images.unsplash.com') || trimmed.contains('unsplash.com/photo-')) {
      return trimmed;
    }
    
    return null;
  }

  String? _extractYoutubeId(String line) {
    final trimmed = line.trim();
    if (trimmed.contains(' ')) return null;
    if (!trimmed.startsWith(RegExp(r'https?://'))) return null;
    
    final pattern = RegExp(
      r'^(?:https?://)?(?:www\.)?(?:m\.)?(?:youtube\.com/(?:watch\?(?:.*&)?v=|embed/|v/|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})(?:\S*)?$',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  String? _extractAudioUrl(String line) {
    final trimmed = line.trim();
    if (trimmed.contains(' ')) return null;
    if (!trimmed.startsWith(RegExp(r'https?://'))) return null;
    
    final audioExtensions = ['.mp3', '.wav', '.m4a', '.aac', '.opus', '.ogg', '.caf'];
    final lower = trimmed.toLowerCase();
    for (final ext in audioExtensions) {
      if (lower.endsWith(ext) || lower.contains('$ext?')) {
        return trimmed;
      }
    }
    return null;
  }

  Widget _buildEdgeToEdge(BuildContext context, Widget child) {
    return EdgeToEdgeLayout(child: child);
  }

  Widget _buildInlineImage(BuildContext context, String imageUrl) {
    return _buildEdgeToEdge(
      context,
      GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black,
              pageBuilder: (context, _, __) => FullScreenImageViewer(imageUrl: imageUrl),
              transitionsBuilder: (context, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.fitWidth,
          placeholder: (context, url) => Container(
            height: 200,
            color: AppColors.getBackground(context).withOpacity(0.05),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 100,
            color: AppColors.getBackground(context).withOpacity(0.05),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'فشل تحميل الصورة',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYoutubePlayer(BuildContext context, String videoId) {
    return _buildEdgeToEdge(
      context,
      YoutubeVideoWithActions(videoId: videoId),
    );
  }

  List<Widget> _renderTextBlock(BuildContext context, String blockText, _AudioIndex audioIndexWrapper, _ImageIndex imageIndexWrapper) {
    final List<Widget> widgets = [];
    final lines = blockText.split('\n');
    
    SettingsProvider? settingsProvider;
    try {
      settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {}
    final bool isGlobalJustify = settingsProvider?.justifyArticles ?? false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }
      
      TextAlign textAlign = TextAlign.start;
      String cleanLine = line.trim();
      final cleanLineUpper = cleanLine.toUpperCase();
      
      if ((cleanLineUpper.startsWith('[CENTER]') && cleanLineUpper.endsWith('[/CENTER]')) ||
          (cleanLine.startsWith('=') && cleanLine.endsWith('=') && cleanLine.length > 1)) {
        textAlign = TextAlign.center;
        if (cleanLine.startsWith('=')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[CENTER]'.length, cleanLine.length - '[/CENTER]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[JUSTIFY]') && cleanLineUpper.endsWith('[/JUSTIFY]')) ||
                 (cleanLine.startsWith('~') && cleanLine.endsWith('~') && cleanLine.length > 1)) {
        textAlign = TextAlign.justify;
        if (cleanLine.startsWith('~')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[JUSTIFY]'.length, cleanLine.length - '[/JUSTIFY]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[LEFT]') && cleanLineUpper.endsWith('[/LEFT]')) ||
                 (cleanLine.startsWith('--') && cleanLine.endsWith('--') && cleanLine.length > 3)) {
        textAlign = TextAlign.left;
        if (cleanLine.startsWith('-')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[LEFT]'.length, cleanLine.length - '[/LEFT]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[RIGHT]') && cleanLineUpper.endsWith('[/RIGHT]')) ||
                 (cleanLine.startsWith('++') && cleanLine.endsWith('++') && cleanLine.length > 3)) {
        textAlign = TextAlign.right;
        if (cleanLine.startsWith('+')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[RIGHT]'.length, cleanLine.length - '[/RIGHT]'.length).trim();
        }
      }

      if (textAlign == TextAlign.start && isGlobalJustify) {
        // Smart justification: only justify lines with a healthy word count (10 or more words)
        // to prevent ugly spacing on short lines.
        final wordCount = cleanLine.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        if (wordCount >= 10) {
          textAlign = TextAlign.justify;
        }
      }

      // Normalize line by stripping inline formatting tags (like [BOLD], [HIGHLIGHT], etc.)
      // to ensure embedded tags ([AUDIO], YouTube links, images) are recognized cleanly even if formatted.
      final String normalizedLine = cleanLine
          .replaceAll(RegExp(r'\[/?(POEM|BOLD|CENTER|JUSTIFY|LEFT|RIGHT|B|HIGHLIGHT|POEM_LEFT|POEM_CENTER)/?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[/'), '')
          .replaceAll(RegExp(r'==|~~|--|\+\+|\*'), '')
          .trim();

      // Check for media links in the cleaned line
      final imageUrl = _extractImageUrl(normalizedLine);
      if (imageUrl != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
          child: _buildInlineImage(context, imageUrl),
        ));
        continue;
      }
      
      final youtubeId = _extractYoutubeId(normalizedLine);
      if (youtubeId != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
          child: _buildYoutubePlayer(context, youtubeId),
        ));
        continue;
      }

      // 1. Direct audio file URL
      final directAudioUrl = _extractAudioUrl(normalizedLine);
      if (directAudioUrl != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
          child: InlineAudioPlayer(audioUrl: directAudioUrl),
        ));
        continue;
      }

      // 2. [AUDIO_ADVANCED] embedding tag (supports [AUDIO_ADVANCED], [AUDIO_ADVANCED: filename], [AUDIO_ADVANCED_filename], and [AUDIO_ADVANCED: URL])
      final advancedMatch = RegExp(r'^\[AUDIO_ADVANCED(?:_|:\s*)(.+?)\]$', caseSensitive: false).firstMatch(normalizedLine);
      final isAdvancedTag = normalizedLine.toUpperCase() == '[AUDIO_ADVANCED]' || advancedMatch != null;

      if (isAdvancedTag) {
        String? resolvedUrl;
        
        if (advancedMatch != null) {
          final content = advancedMatch.group(1)!.trim();
          if (content.toLowerCase().startsWith('http://') || content.toLowerCase().startsWith('https://')) {
            resolvedUrl = content;
          } else {
            // Find file by name matching
            final filenameQuery = content.toLowerCase();
            if (audioUrls != null) {
              for (final url in audioUrls!) {
                final cleanFile = AudioHelper.getCleanAudioTitle(url).toLowerCase();
                final cleanFileWithExt = AudioHelper.getCleanFileNameFromUrl(url).toLowerCase();
                
                if (cleanFile == filenameQuery || 
                    cleanFileWithExt == filenameQuery || 
                    cleanFile.contains(filenameQuery) || 
                    filenameQuery.contains(cleanFile)) {
                  resolvedUrl = url;
                  break;
                }
              }
            }
          }
        }
        
        // Fallback: sequential mapping if not resolved
        if (resolvedUrl == null) {
          if (audioUrls != null && audioUrls!.isNotEmpty && audioIndexWrapper.value < audioUrls!.length) {
            resolvedUrl = audioUrls![audioIndexWrapper.value];
            audioIndexWrapper.value++;
          }
        }

        if (resolvedUrl != null) {
          final List<String> audioFiles = audioUrls?.map((u) {
            if (u.toLowerCase().startsWith('http://') || u.toLowerCase().startsWith('https://')) {
              try {
                return Uri.parse(u).pathSegments.last;
              } catch (_) {}
            }
            return u.split('/').last;
          }).toList() ?? [];
          final String resolvedTitle = AudioHelper.getAudioDisplayName(resolvedUrl, text, audioFiles);

          widgets.add(Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
            child: AdvancedAudioPlayer(
              audioUrl: resolvedUrl,
              audioTitle: resolvedTitle,
              onTextGenerated: onTextGenerated,
              audioMetadata: audioMetadata,
              onMetadataUpdated: onMetadataUpdated,
            ),
          ));
        } else {
          widgets.add(Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusS),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'الملف الصوتي الخاص بهذا التضمين غير متوفر',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ));
        }
        continue;
      }

      // 3. [AUDIO] embedding tag (supports [AUDIO], [AUDIO: filename], [AUDIO_filename], and [AUDIO: URL])
      final audioMatch = RegExp(r'^\[AUDIO(?:_|:\s*)(.+?)\]$', caseSensitive: false).firstMatch(normalizedLine);
      final isAudioTag = normalizedLine.toUpperCase() == '[AUDIO]' || audioMatch != null;

      if (isAudioTag) {
        String? resolvedUrl;
        
        if (audioMatch != null) {
          final content = audioMatch.group(1)!.trim();
          if (content.toLowerCase().startsWith('http://') || content.toLowerCase().startsWith('https://')) {
            resolvedUrl = content;
          } else {
            // Find file by name matching
            final filenameQuery = content.toLowerCase();
            if (audioUrls != null) {
              for (final url in audioUrls!) {
                final cleanFile = AudioHelper.getCleanAudioTitle(url).toLowerCase();
                final cleanFileWithExt = AudioHelper.getCleanFileNameFromUrl(url).toLowerCase();
                
                if (cleanFile == filenameQuery || 
                    cleanFileWithExt == filenameQuery || 
                    cleanFile.contains(filenameQuery) || 
                    filenameQuery.contains(cleanFile)) {
                  resolvedUrl = url;
                  break;
                }
              }
            }
          }
        }
        
        // Fallback: sequential mapping if not resolved
        if (resolvedUrl == null) {
          if (audioUrls != null && audioUrls!.isNotEmpty && audioIndexWrapper.value < audioUrls!.length) {
            resolvedUrl = audioUrls![audioIndexWrapper.value];
            audioIndexWrapper.value++;
          }
        }

        if (resolvedUrl != null) {
          widgets.add(Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
            child: InlineAudioPlayer(audioUrl: resolvedUrl),
          ));
        } else {
          widgets.add(Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusS),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'الملف الصوتي الخاص بهذا التضمين غير متوفر',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ));
        }
        continue;
      }
      
      // 4. [IMAGE] embedding tag (supports [IMAGE], [IMAGE: filename], [IMAGE_filename], and [IMAGE: URL])
      final imageMatch = RegExp(r'^\[IMAGE(?:_|:\s*)(.+?)\]$', caseSensitive: false).firstMatch(normalizedLine);
      final isImageTag = normalizedLine.toUpperCase() == '[IMAGE]' || imageMatch != null;

      if (isImageTag) {
        String? resolvedUrl;
        
        if (imageMatch != null) {
          final content = imageMatch.group(1)!.trim();
          if (content.toLowerCase().startsWith('http://') || content.toLowerCase().startsWith('https://')) {
            resolvedUrl = content;
          } else {
            // Find file by name matching
            final filenameQuery = content.toLowerCase();
            if (imageFiles != null) {
              for (final url in imageFiles!) {
                final cleanFile = url.split('/').last.split('?').first.toLowerCase();
                if (cleanFile == filenameQuery || 
                    cleanFile.contains(filenameQuery) || 
                    filenameQuery.contains(cleanFile)) {
                  resolvedUrl = url;
                  break;
                }
              }
            }
          }
        }
        
        // Fallback: sequential mapping if not resolved
        if (resolvedUrl == null) {
          if (imageFiles != null && imageFiles!.isNotEmpty && imageIndexWrapper.value < imageFiles!.length) {
            resolvedUrl = imageFiles![imageIndexWrapper.value];
            imageIndexWrapper.value++;
          }
        }

        if (resolvedUrl != null) {
          final resolvedUrlCopy = resolvedUrl;
          final isLocal = !resolvedUrlCopy.startsWith('http');
          widgets.add(Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(imageUrl: resolvedUrlCopy),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusM),
                child: isLocal
                    ? Image.file(
                        File(resolvedUrlCopy),
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: resolvedUrlCopy,
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
              ),
            ),
          ));
        } else {
          widgets.add(Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusS),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'الصورة المدمجة الخاصة بهذا التضمين غير متوفرة',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ));
        }
        continue;
      }
      
      final continueMatch = RegExp(r'^\[(?:أكمل|Continue)\s*(\d{1,2}:\d{2})\]$', caseSensitive: false).firstMatch(normalizedLine);
      if (continueMatch != null) {
        final timestamp = continueMatch.group(1)!;
        if (onTextUpdated == null) {
          continue;
        }
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
          child: ContinueTranscriptionButton(
            timestamp: timestamp,
            audioUrls: audioUrls,
            articleText: text,
            onTextUpdated: onTextUpdated!,
          ),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
        child: SelectableText.rich(
          _parseInlineFormatting(cleanLine, context, isJustified: textAlign == TextAlign.justify),
          textAlign: textAlign,
        ),
      ));
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings to trigger rebuilds when justification or fonts change
    try {
      Provider.of<SettingsProvider>(context);
    } catch (_) {}
    
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Clean citations in brackets [...] of diacritics to prevent font rendering/ligature distortion
    final cleanedText = text.replaceAllMapped(RegExp(r'\[([^\]]+?)\]'), (match) {
      final content = match.group(1)!;
      final cleanedContent = content
          .replaceAll('ٱ', 'ا')
          .replaceAll(RegExp(r'[\u064b-\u0652\u0670]'), '');
      return '[$cleanedContent]';
    });

    final List<Widget> widgets = [];
    final poemPattern = RegExp(r'\[POEM(?:\s+TYPE="([^"]+?)")?\](.*?)\[/POEM\]', dotAll: true, caseSensitive: false);
    
    final audioIndexWrapper = _AudioIndex();
    final imageIndexWrapper = _ImageIndex();
    int lastMatchEnd = 0;
    
    for (final match in poemPattern.allMatches(cleanedText)) {
      // Add preceding normal text if any
      final preText = cleanedText.substring(lastMatchEnd, match.start).trim();
      if (preText.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _renderTextBlock(context, preText, audioIndexWrapper, imageIndexWrapper),
          ),
        ));
      }
      
      // Add PoemView
      final type = match.group(1)?.toUpperCase() ?? 'STANDARD';
      final poemContent = match.group(2)?.trim() ?? '';
      if (poemContent.isNotEmpty) {
        widgets.add(PoemView(poemText: poemContent, fontFamily: fontFamily, type: type));
      }
      
      lastMatchEnd = match.end;
    }
    
    // Add remaining normal text
    final postText = cleanedText.substring(lastMatchEnd).trim();
    if (postText.isNotEmpty) {
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _renderTextBlock(context, postText, audioIndexWrapper, imageIndexWrapper),
      ));
    }
    
    // If no text or poems were added at all, just render the original string
    if (widgets.isEmpty && cleanedText.isNotEmpty) {
      widgets.addAll(_renderTextBlock(context, cleanedText, audioIndexWrapper, imageIndexWrapper));
    }
    final isArabic = BidiUtils.isRtl(text, fallbackToRtl: Localizations.localeOf(context).languageCode == 'ar');

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  /// فتح الصورة كـ dialog مركزي بخلفية سوداء شفافة (بدون slide جانبي)
  static Future<void> show(BuildContext context, String imageUrl) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => FullScreenImageViewer(imageUrl: imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = !imageUrl.startsWith('http');
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: GestureDetector(
                onTap: () {}, // منع إغلاق عند الضغط على الصورة نفسها
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isLocal
                        ? Image.file(
                            File(imageUrl),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: FloatingActionButton.extended(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    onPressed: () async {
                      final filename = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                      final success = await ImageSaverUtil.saveImageFromUrl(imageUrl, filename);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'تم حفظ الصورة في ألبوم الصور بنجاح 🖼️'
                                  : 'فشل حفظ الصورة ❌',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('حفظ الصورة'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class EdgeToEdgeLayout extends StatelessWidget {
  final Widget child;

  const EdgeToEdgeLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth > 800) {
      return child;
    }
    return _RawEdgeToEdgeLayout(screenWidth: screenWidth, child: child);
  }
}

class _RawEdgeToEdgeLayout extends SingleChildRenderObjectWidget {
  final double screenWidth;

  const _RawEdgeToEdgeLayout({
    required this.screenWidth,
    required super.child,
  });

  @override
  RenderEdgeToEdgeLayout createRenderObject(BuildContext context) {
    return RenderEdgeToEdgeLayout(screenWidth);
  }

  @override
  void updateRenderObject(BuildContext context, RenderEdgeToEdgeLayout renderObject) {
    renderObject.screenWidth = screenWidth;
  }
}


class RenderEdgeToEdgeLayout extends RenderShiftedBox {
  double _screenWidth;

  RenderEdgeToEdgeLayout(this._screenWidth, [RenderBox? child]) : super(child);

  double get screenWidth => _screenWidth;
  set screenWidth(double value) {
    if (_screenWidth == value) return;
    _screenWidth = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _screenWidth;
  @override
  double computeMaxIntrinsicWidth(double height) => _screenWidth;
  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(width) ?? 0.0;
  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(width) ?? 0.0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) return constraints.smallest;
    final childConstraints = BoxConstraints(
      minWidth: _screenWidth,
      maxWidth: _screenWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
    final childSize = child!.getDryLayout(childConstraints);
    return constraints.constrain(Size(constraints.maxWidth, childSize.height));
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final childConstraints = BoxConstraints(
      minWidth: _screenWidth,
      maxWidth: _screenWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
    child!.layout(childConstraints, parentUsesSize: true);

    size = constraints.constrain(Size(constraints.maxWidth, child!.size.height));

    final double overflow = _screenWidth - size.width;
    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    childParentData.offset = Offset(-overflow / 2.0, 0.0);
  }
}

class _AudioIndex {
  int value = 0;
}

class _ImageIndex {
  int value = 0;
}

class ContinueTranscriptionButton extends StatefulWidget {
  final String timestamp;
  final List<String>? audioUrls;
  final String articleText;
  final Function(String updatedText) onTextUpdated;

  const ContinueTranscriptionButton({
    super.key,
    required this.timestamp,
    required this.audioUrls,
    required this.articleText,
    required this.onTextUpdated,
  });

  @override
  State<ContinueTranscriptionButton> createState() => _ContinueTranscriptionButtonState();
}

class _ContinueTranscriptionButtonState extends State<ContinueTranscriptionButton> {
  bool _isLoading = false;

  Future<void> _transcribeNextChunk() async {
    if (_isLoading) return;

    if (widget.audioUrls == null || widget.audioUrls!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد ملف صوتي للتفريغ')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final audioUrl = widget.audioUrls!.first;
      final String baseUrl = kIsWeb ? Uri.base.origin : 'https://www.sijilli.com';
      final serviceUrl = Uri.parse('$baseUrl/api/transcribe');

      final requestBody = {
        'startTime': widget.timestamp,
      };

      final isNetwork = audioUrl.startsWith('http://') || 
                        audioUrl.startsWith('https://') ||
                        audioUrl.startsWith('blob:');

      http.Response response;
      if (isNetwork) {
        requestBody['url'] = audioUrl;
        response = await http.post(
          serviceUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 40));
      } else {
        // Local file - read bytes and send base64
        final file = File(audioUrl);
        if (!await file.exists()) {
          throw Exception('الملف الصوتي المحلي غير موجود');
        }
        final bytes = await file.readAsBytes();
        requestBody['audioData'] = base64Encode(bytes);
        
        String mimeType = 'audio/mp3';
        final lower = audioUrl.toLowerCase();
        if (lower.endsWith('.wav')) mimeType = 'audio/wav';
        else if (lower.endsWith('.m4a')) mimeType = 'audio/mp4';
        else if (lower.endsWith('.ogg')) mimeType = 'audio/ogg';
        else if (lower.endsWith('.opus')) mimeType = 'audio/opus';

        requestBody['mimeType'] = mimeType;

        response = await http.post(
          serviceUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 50));
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final generatedText = data['text'] as String?;

        if (generatedText != null && generatedText.trim().isNotEmpty) {
          // Replace [أكمل 05:00] (or similar) in raw text with the generated text,
          // followed by the next 5-minute tag (if next time is <= 60 minutes)
          final String currentTag = '[أكمل ${widget.timestamp}]';
          final String continueTag = '[Continue ${widget.timestamp}]';
          
          // Parse current timestamp to add 5 minutes
          final parts = widget.timestamp.split(':');
          String? nextTag;
          if (parts.length == 2) {
            final mins = int.tryParse(parts[0]) ?? 0;
            final secs = int.tryParse(parts[1]) ?? 0;
            final totalSecs = mins * 60 + secs + 300;
            final nextMins = totalSecs ~/ 60;
            final nextSecs = totalSecs % 60;
            
            if (nextMins < 60 || (nextMins == 60 && nextSecs == 0)) {
              final nextMinsStr = nextMins.toString().padLeft(2, '0');
              final nextSecsStr = nextSecs.toString().padLeft(2, '0');
              nextTag = '[أكمل $nextMinsStr:$nextSecsStr]';
            }
          }

          final String appendText = nextTag != null 
              ? '\n$generatedText\n\n$nextTag' 
              : '\n$generatedText\n';

          // Update article text
          String updatedText = widget.articleText;
          if (updatedText.contains(currentTag)) {
            updatedText = updatedText.replaceFirst(currentTag, appendText);
          } else if (updatedText.contains(continueTag)) {
            updatedText = updatedText.replaceFirst(continueTag, appendText);
          } else {
            // Fallback: replace with regex
            updatedText = updatedText.replaceFirst(
              RegExp(r'\[(?:أكمل|Continue)\s*' + RegExp.escape(widget.timestamp) + r'\]', caseSensitive: false),
              appendText,
            );
          }

          widget.onTextUpdated(updatedText);
        } else {
          // Gemini returned empty text -> audio has ended! Remove the tag
          final String currentTag = '[أكمل ${widget.timestamp}]';
          final String continueTag = '[Continue ${widget.timestamp}]';
          String updatedText = widget.articleText;
          if (updatedText.contains(currentTag)) {
            updatedText = updatedText.replaceFirst(currentTag, '');
          } else if (updatedText.contains(continueTag)) {
            updatedText = updatedText.replaceFirst(continueTag, '');
          }
          widget.onTextUpdated(updatedText);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تفريغ المقطع: رمز الاستجابة ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التفريغ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: OutlinedButton.icon(
          onPressed: _transcribeNextChunk,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          icon: const Icon(Icons.keyboard_double_arrow_down_rounded, size: 16, color: AppColors.primary),
          label: Text(
            'أكمل ${widget.timestamp}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
