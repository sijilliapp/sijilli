import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

class InlineAudioPlayer extends StatefulWidget {
  final String audioUrl;

  const InlineAudioPlayer({super.key, required this.audioUrl});

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  late AudioPlayer _audioPlayer;
  static AudioPlayer? _activePlayer;

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      setState(() {
        _isBuffering = true;
        _errorMessage = null;
      });

      // AVPlayer on iOS does not support playing raw .opus files natively.
      // If we detect .opus on iOS, we show a clean error rather than crashing.
      final isOpus = widget.audioUrl.toLowerCase().contains('.opus');
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      
      if (isOpus && isIOS) {
        setState(() {
          _isBuffering = false;
          _errorMessage = 'صيغة OPUS غير مدعومة على iOS. يرجى التصدير كـ M4A';
        });
        return;
      }

      if (widget.audioUrl.startsWith('http://') || 
          widget.audioUrl.startsWith('https://') ||
          widget.audioUrl.startsWith('blob:')) {
        await _audioPlayer.setUrl(widget.audioUrl);
      } else {
        await _audioPlayer.setFilePath(widget.audioUrl);
      }

      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });
      });

      _positionSubscription = _audioPlayer.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() {
          _position = pos;
        });
      });

      _durationSubscription = _audioPlayer.durationStream.listen((dur) {
        if (!mounted) return;
        setState(() {
          _duration = dur ?? Duration.zero;
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _errorMessage = 'فشل تحميل الملف الصوتي';
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_errorMessage != null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // Pause any other active player in the app
        if (_activePlayer != null && _activePlayer != _audioPlayer) {
          await _activePlayer!.pause().catchError((_) {});
        }
        _activePlayer = _audioPlayer;
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ أثناء التشغيل';
        });
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    
    if (_activePlayer == _audioPlayer) {
      _activePlayer = null;
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getCleanFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final rawName = uri.pathSegments.last;

      if (rawName.toLowerCase().contains('whatsapp') || rawName.toLowerCase().endsWith('.opus')) {
        return 'رسالة صوتية من واتساب 💬';
      }

      // 1. Separate filename and extension
      final dotIndex = rawName.lastIndexOf('.');
      if (dotIndex != -1) {
        String mainPart = rawName.substring(0, dotIndex);
        final ext = rawName.substring(dotIndex);
        
        // 2. Strip PocketBase 10-char random suffix (e.g. _a1b2c3d4e5)
        final suffixRegex = RegExp(r'_([a-zA-Z0-9]{10})$');
        if (suffixRegex.hasMatch(mainPart)) {
          mainPart = mainPart.replaceFirst(suffixRegex, '');
        }
        
        // 3. Remove underscores to get raw hex
        final hexOnly = mainPart.replaceAll('_', '').toLowerCase();
        
        // 4. Validate if it's a valid hex string of even length
        if (hexOnly.isNotEmpty && 
            hexOnly.length % 2 == 0 && 
            RegExp(r'^[0-9a-f]+$').hasMatch(hexOnly)) {
          
          // 5. Check if it looks like UTF-8 Arabic bytes (which start with d8/d9/da/db or 20 for space)
          bool isArabicHex = false;
          for (int i = 0; i < hexOnly.length; i += 2) {
            final byte = hexOnly.substring(i, i + 2);
            if (byte == 'd8' || byte == 'd9' || byte == 'da' || byte == 'db' || byte == '20') {
              isArabicHex = true;
              break;
            }
          }
          
          if (isArabicHex) {
            final buffer = StringBuffer();
            for (int i = 0; i < hexOnly.length; i += 2) {
              buffer.write('%');
              buffer.write(hexOnly.substring(i, i + 2));
            }
            final percentEncoded = buffer.toString();
            final decoded = Uri.decodeFull(percentEncoded);
            if (decoded.trim().isNotEmpty) {
              return '$decoded$ext';
            }
          }
        }
      }

      // Fallback: standard pocketbase cleaning and URI decoding
      String cleanName = rawName;
      final pbSuffixPattern = RegExp(r'_([a-zA-Z0-9]{10})\.([a-zA-Z0-9]+)$');
      if (pbSuffixPattern.hasMatch(cleanName)) {
        cleanName = cleanName.replaceFirst(RegExp(r'_([a-zA-Z0-9]{10})\.'), '.');
      }
      return Uri.decodeFull(cleanName);
    } catch (_) {
      return 'ملف صوتي 🎵';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = _getCleanFileName(widget.audioUrl);
    final isWhatsApp = fileName.contains('واتساب');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      height: 58.0,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: _errorMessage != null
          ? Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                  onPressed: _initAudio,
                ),
              ],
            )
          : Row(
              children: [
                // Play / Pause / Buffer Button
                _isBuffering
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          onPressed: _togglePlay,
                        ),
                      ),
                const SizedBox(width: 8),
                
                // Audio Details (Name & Slider)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: MarqueeText(
                              text: fileName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.75) ?? const Color(0xFF212121),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isWhatsApp
                                  ? Colors.green.withOpacity(0.1)
                                  : AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isWhatsApp ? 'واتساب' : 'صوت',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isWhatsApp ? Colors.green.shade600 : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Slider & Duration layout
                      Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbColor: AppColors.primary,
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: _duration.inMilliseconds.toDouble(),
                                value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                                onChanged: (value) {
                                  _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeText({super.key, required this.text, required this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!mounted) return;
    
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || !_scrollController.hasClients) return;
      
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: widget.text.length * 120),
        curve: Curves.linear,
      );
      
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
