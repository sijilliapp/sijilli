import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/image_saver_util.dart';
import 'poetry/poem_view.dart';
import 'poetry/poem_formatter_utils.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/utils/bidi_utils.dart';

class ArticleContentRenderer extends StatelessWidget {
  final String text;
  final String? fontFamily;

  const ArticleContentRenderer({super.key, required this.text, this.fontFamily});

  TextSpan _parseInlineFormatting(String text, BuildContext context) {
    const double fontSize = 22.0;
    const double lineHeight = 1.75;

    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: AppColors.getTextPrimary(context),
      fontWeight: FontWeight.w600, // Thickened to w600 for better clarity and sharpness
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
      YoutubePreviewCard(videoId: videoId),
    );
  }

  List<Widget> _renderTextBlock(BuildContext context, String blockText) {
    final List<Widget> widgets = [];
    final lines = blockText.split('\n');
    
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

      // Check for media links in the cleaned line
      final imageUrl = _extractImageUrl(cleanLine);
      if (imageUrl != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
          child: _buildInlineImage(context, imageUrl),
        ));
        continue;
      }
      
      final youtubeId = _extractYoutubeId(cleanLine);
      if (youtubeId != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
          child: _buildYoutubePlayer(context, youtubeId),
        ));
        continue;
      }
      
      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
        child: Text.rich(
          _parseInlineFormatting(cleanLine, context),
          textAlign: textAlign,
        ),
      ));
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
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
    
    int lastMatchEnd = 0;
    
    for (final match in poemPattern.allMatches(cleanedText)) {
      // Add preceding normal text if any
      final preText = cleanedText.substring(lastMatchEnd, match.start).trim();
      if (preText.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _renderTextBlock(context, preText),
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
        children: _renderTextBlock(context, postText),
      ));
    }
    
    // If no text or poems were added at all, just render the original string
    if (widgets.isEmpty && cleanedText.isNotEmpty) {
      widgets.addAll(_renderTextBlock(context, cleanedText));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
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
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.5),
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
                  backgroundColor: Colors.white.withOpacity(0.25),
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
    );
  }
}

class YoutubePreviewCard extends StatefulWidget {
  final String videoId;

  const YoutubePreviewCard({super.key, required this.videoId});

  @override
  State<YoutubePreviewCard> createState() => _YoutubePreviewCardState();
}

class _YoutubePreviewCardState extends State<YoutubePreviewCard> {
  late List<String> _thumbnailUrls;
  int _currentUrlIndex = 0;
  bool _isPlaying = false;
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _thumbnailUrls = [
      'https://img.youtube.com/vi/${widget.videoId}/maxresdefault.jpg',
      'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg',
      'https://img.youtube.com/vi/${widget.videoId}/mqdefault.jpg',
    ];
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  void _handleImageError() {
    if (_currentUrlIndex < _thumbnailUrls.length - 1) {
      setState(() {
        _currentUrlIndex++;
      });
    }
  }

  Future<void> _openInYoutubeApp() async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=${widget.videoId}';
    final uri = Uri.parse(youtubeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط يوتيوب')),
        );
      }
    }
  }

  Widget _buildPlayer() {
    _controller ??= YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        mute: false,
        showControls: true,
      ),
    );
    
    return YoutubePlayer(
      controller: _controller!,
      aspectRatio: 16 / 9,
    );
  }

  Widget _buildPreview() {
    final thumbnailUrl = _thumbnailUrls[_currentUrlIndex];
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPlaying = true;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.black87,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (context, url, error) {
              if (_currentUrlIndex < _thumbnailUrls.length - 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _handleImageError());
                return Container(
                  color: Colors.black87,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              
              return Container(
                color: Colors.black87,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_outlined, color: Colors.white54, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'تشغيل الفيديو',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'تشغيل الفيديو',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _isPlaying ? _buildPlayer() : _buildPreview(),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _openInYoutubeApp,
                icon: const Icon(Icons.open_in_new, size: 14, color: Colors.red),
                label: Text(
                  'فتح في تطبيق يوتيوب',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ],
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
