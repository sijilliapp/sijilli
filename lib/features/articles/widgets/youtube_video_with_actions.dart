import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'youtube_transcript_bottom_sheet.dart';

class YoutubeVideoWithActions extends StatefulWidget {
  final String videoId;

  const YoutubeVideoWithActions({super.key, required this.videoId});

  @override
  State<YoutubeVideoWithActions> createState() => _YoutubeVideoWithActionsState();
}

class _YoutubeVideoWithActionsState extends State<YoutubeVideoWithActions> {
  bool _isPlaying = false;
  YoutubePlayerController? _controller;
  Duration? _pendingSeekDuration;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Widget _buildPlayer() {
    if (_controller == null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
          showControls: true,
        ),
      );

      if (_pendingSeekDuration != null) {
        _controller!.seekTo(
          seconds: _pendingSeekDuration!.inSeconds.toDouble(),
          allowSeekAhead: true,
        );
        _pendingSeekDuration = null;
      }
    }
    
    return YoutubePlayer(
      controller: _controller!,
      aspectRatio: 16 / 9,
    );
  }

  Widget _buildPreview() {
    final thumbnailUrl = 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';
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

  void _showTranscriptBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => YoutubeTranscriptBottomSheet(
        videoId: widget.videoId,
        controller: _controller,
        onStartPlaying: () {
          if (!_isPlaying) {
            setState(() {
              _isPlaying = true;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // مشغل الفيديو أو المعاينة (بدون زوايا منحنية)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _isPlaying ? _buildPlayer() : _buildPreview(),
        ),
        // شريط الأزرار مع هوامش متساوية من جميع الجهات ودعم التمدد والمشاركة المتساوية للمساحة
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showTranscriptBottomSheet,
                  icon: const Icon(Icons.subtitles, size: 18),
                  label: const Text('النص المسموع (تفريغ الفيديو)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // في حال إضافة أزرار أخرى في المستقبل، يتم إضافتها كعناصر Expanded داخل الـ Row لتتقاسم المساحة تلقائياً
            ],
          ),
        ),
      ],
    );
  }
}
