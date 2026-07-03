import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../../core/utils/audio_helper.dart';
import '../../../../core/utils/audio_cache_manager.dart';

class AdvancedAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final String? audioTitle;
  final Function(String text, String audioUrl, bool isFinal)? onTextGenerated; // If non-null, we are in Edit Mode

  const AdvancedAudioPlayer({
    super.key,
    required this.audioUrl,
    this.audioTitle,
    this.onTextGenerated,
  });

  @override
  State<AdvancedAudioPlayer> createState() => _AdvancedAudioPlayerState();
}

class _AdvancedAudioPlayerState extends State<AdvancedAudioPlayer> {
  late AudioPlayer _audioPlayer;
  static AudioPlayer? _activePlayer;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isAudioReady = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  // AB Loop variables
  Duration? _loopA;
  Duration? _loopB;

  // Speed and Loop Mode variables
  double _speed = 1.0;
  bool _isRepeatEnabled = false;

  // AI loading states
  bool _isTranscribing = false;
  bool _isSummarizing = false;
  bool _isAICancelled = false;

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
        _isAudioReady = false;
        _errorMessage = null;
      });

      // AVPlayer on iOS does not support playing raw .opus files natively.
      final isOpus = widget.audioUrl.toLowerCase().contains('.opus');
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      
      if (isOpus && isIOS) {
        setState(() {
          _isBuffering = false;
          _errorMessage = 'صيغة OPUS غير مدعومة على iOS. يرجى التصدير كـ M4A';
        });
        return;
      }

      // Check and fetch from local cache if possible
      final resolvedUrl = await AudioCacheManager.instance.getAudioSource(widget.audioUrl);

      if (resolvedUrl.startsWith('http://') || 
          resolvedUrl.startsWith('https://') ||
          resolvedUrl.startsWith('blob:')) {
        await _audioPlayer.setUrl(resolvedUrl);
      } else {
        await _audioPlayer.setFilePath(resolvedUrl);
      }

      setState(() {
        _isAudioReady = true;
        _isBuffering = false;
      });

      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        final bool isCompleted = state.processingState == ProcessingState.completed;
        setState(() {
          _isPlaying = state.playing && !isCompleted;
          _isBuffering = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          if (state.processingState == ProcessingState.ready) {
            _isAudioReady = true;
          }
          if (isCompleted) {
            _position = Duration.zero;
            _audioPlayer.pause();
            _audioPlayer.seek(Duration.zero);
          }
        });
      });

      _positionSubscription = _audioPlayer.positionStream.listen((pos) {
        if (!mounted) return;
        
        // AB Loop logic
        if (_loopA != null && _loopB != null && pos >= _loopB!) {
          _audioPlayer.seek(_loopA!);
          return;
        }

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

  Future<void> _toggleRepeat() async {
    try {
      final nextState = !_isRepeatEnabled;
      await _audioPlayer.setLoopMode(nextState ? LoopMode.one : LoopMode.off);
      setState(() {
        _isRepeatEnabled = nextState;
      });
    } catch (e) {
      debugPrint('Error setting repeat: $e');
    }
  }

  Future<void> _changeSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      setState(() {
        _speed = speed;
      });
    } catch (e) {
      debugPrint('Error setting speed: $e');
    }
  }

  Future<void> _skip(int seconds) async {
    final currentPos = _audioPlayer.position;
    final newPos = currentPos + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      await _audioPlayer.seek(Duration.zero);
    } else if (newPos > _duration) {
      await _audioPlayer.seek(_duration);
    } else {
      await _audioPlayer.seek(newPos);
    }
  }

  // AI services trigger
  Future<void> _callAIService(bool isTranscription) async {
    if (isTranscription) {
      if (_isTranscribing) {
        // Stop/cancel current operation
        setState(() {
          _isAICancelled = true;
          _isTranscribing = false;
        });
        return;
      }
    } else {
      if (_isSummarizing) {
        setState(() {
          _isAICancelled = true;
          _isSummarizing = false;
        });
        return;
      }
    }

    setState(() {
      _isAICancelled = false;
      if (isTranscription) {
        _isTranscribing = true;
      } else {
        _isSummarizing = true;
      }
    });

    try {
      // 0. Cache check for summary and transcription
      final prefs = await SharedPreferences.getInstance();
      if (!isTranscription) {
        final cachedSummary = prefs.getString('summary_${widget.audioUrl.hashCode}');
        if (cachedSummary != null && cachedSummary.trim().isNotEmpty) {
          if (_isAICancelled) return;
          _showAIResultDialog('تلخيص الأفكار الرئيسية', cachedSummary);
          return;
        }
      } else if (widget.onTextGenerated == null) {
        final cachedTranscription = prefs.getString('transcription_${widget.audioUrl.hashCode}');
        if (cachedTranscription != null && cachedTranscription.trim().isNotEmpty) {
          if (_isAICancelled) return;
          _showAIResultDialog('التفريغ الصوتي الذكي', cachedTranscription, isAlreadyCompleted: true);
          return;
        }
      }

      // Calculate startTime if transcribing
      String? startTimeStr;
      if (isTranscription) {
        final currentPos = _audioPlayer.position;
        final minutes = currentPos.inMinutes;
        final seconds = currentPos.inSeconds % 60;
        startTimeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      final isNetwork = widget.audioUrl.startsWith('http://') || 
                        widget.audioUrl.startsWith('https://') ||
                        widget.audioUrl.startsWith('blob:');

      final functionName = isTranscription ? 'transcribe' : 'summarize';
      final String baseUrl = kIsWeb ? Uri.base.origin : 'https://www.sijilli.com';
      final serviceUrl = Uri.parse('$baseUrl/api/$functionName');
      
      http.Response response;

      final Map<String, dynamic> requestBody = {};
      if (startTimeStr != null) {
        requestBody['startTime'] = startTimeStr;
      }
      if (_duration != Duration.zero) {
        requestBody['duration'] = _duration.inSeconds;
      }

      if (isNetwork) {
        requestBody['url'] = widget.audioUrl;
        response = await http.post(
          serviceUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 40));
      } else {
        // Local file - read bytes and send base64
        final file = File(widget.audioUrl);
        if (!await file.exists()) {
          _showErrorDialog('الملف الصوتي المحلي غير موجود');
          return;
        }

        final length = await file.length();
        if (length > 4.2 * 1024 * 1024) {
          _showErrorDialog('الملف الصوتي كبير جداً للتفريغ الفوري قبل الحفظ. يرجى حفظ المقال أولاً ثم تفريغه.');
          return;
        }

        final bytes = await file.readAsBytes();
        final base64Data = base64Encode(bytes);
        
        // Resolve mimeType
        String mimeType = 'audio/mp3';
        final lower = widget.audioUrl.toLowerCase();
        if (lower.endsWith('.wav')) mimeType = 'audio/wav';
        else if (lower.endsWith('.m4a')) mimeType = 'audio/mp4';
        else if (lower.endsWith('.ogg')) mimeType = 'audio/ogg';
        else if (lower.endsWith('.opus')) mimeType = 'audio/opus';
        else if (lower.endsWith('.aac')) mimeType = 'audio/aac';

        requestBody['audioData'] = base64Data;
        requestBody['mimeType'] = mimeType;

        response = await http.post(
          serviceUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 50));
      }

      if (_isAICancelled) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final generatedText = data['text'] as String?;

        if (generatedText != null && generatedText.trim().isNotEmpty) {
          if (isTranscription) {
            if (widget.onTextGenerated != null) {
              // Edit Mode: Stream text word-by-word
              final List<String> words = generatedText.split(RegExp(r'\s+'));
              int wordIndex = 0;
              String accumulated = "";
              
              setState(() {
                _isTranscribing = true;
                _isAICancelled = false;
              });

              Timer.periodic(const Duration(milliseconds: 80), (timer) {
                if (_isAICancelled || !mounted || wordIndex >= words.length) {
                  timer.cancel();
                  if (widget.onTextGenerated != null) {
                    final finalAppendedText = '$accumulated\n\n[أكمل 05:00]';
                    widget.onTextGenerated!(finalAppendedText, widget.audioUrl, true);
                  }
                  if (mounted) {
                    setState(() {
                      _isTranscribing = false;
                    });
                  }
                  return;
                }

                accumulated += (wordIndex == 0 ? "" : " ") + words[wordIndex];
                widget.onTextGenerated!(accumulated, widget.audioUrl, false);
                wordIndex++;
              });
            } else {
              // Read Mode: Open dialog/sheet to show the result
              _showAIResultDialog('التفريغ الصوتي الذكي', generatedText);
            }
          } else {
            // Cache the summary
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('summary_${widget.audioUrl.hashCode}', generatedText);
            
            // Show result
            _showAIResultDialog('تلخيص الأفكار الرئيسية', generatedText);
          }
        } else {
          _showErrorDialog('فشل في جلب الاستجابة من الذكاء الاصطناعي');
        }
      } else {
        final bodyStr = response.body;
        final bool isQuotaExceeded = response.statusCode == 429 || 
                                     bodyStr.contains('429') || 
                                     bodyStr.contains('RESOURCE_EXHAUSTED') || 
                                     bodyStr.toLowerCase().contains('quota');
        
        if (isQuotaExceeded) {
          _showUpgradePromptDialog();
          return;
        }

        String detail = '';
        try {
          final data = json.decode(bodyStr);
          if (data['error'] != null) {
            detail = '\nالسبب: ${data['error']}';
          }
        } catch (_) {}
        _showErrorDialog('فشل الاتصال بخادم الذكاء الاصطناعي (رمز ${response.statusCode})$detail');
      }
    } catch (e) {
      if (!_isAICancelled) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('429') || errStr.contains('quota') || errStr.contains('resource_exhausted')) {
          _showUpgradePromptDialog();
        } else {
          _showErrorDialog('حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _isSummarizing = false;
        });
      }
    }
  }

  Widget _buildSummaryContent(String text) {
    final lines = text.split('\n');
    final List<Widget> lineWidgets = [];
    final timestampRegex = RegExp(r'(?:\[)?(\d{1,2}):(\d{2})(?:\])?');

    for (final line in lines) {
      if (line.trim().isEmpty) {
        lineWidgets.add(const SizedBox(height: 8));
        continue;
      }

      final matches = timestampRegex.allMatches(line);
      if (matches.isNotEmpty) {
        final List<InlineSpan> spans = [];
        int lastMatchEnd = 0;

        for (final match in matches) {
          // Add text before the match
          if (match.start > lastMatchEnd) {
            spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
          }

          final timeStr = match.group(0)!; // e.g. [01:23]
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final targetDuration = Duration(minutes: minutes, seconds: seconds);

          // Add clickable timestamp span
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () {
                  _audioPlayer.seek(targetDuration);
                  if (!_isPlaying) {
                    _togglePlay();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('انتقال إلى $timeStr'),
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );

          lastMatchEnd = match.end;
        }

        // Add remaining text after the last match
        if (lastMatchEnd < line.length) {
          spans.add(TextSpan(text: line.substring(lastMatchEnd)));
        }

        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RichText(
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.getTextPrimary(context),
                  fontFamily: 'Outfit',
                ),
                children: spans,
              ),
            ),
          ),
        );
      } else {
        // Fallback for normal line without timestamp
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.getTextPrimary(context),
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lineWidgets,
    );
  }

  void _showAIResultDialog(String title, String content, {bool isAlreadyCompleted = false}) {
    if (title == 'التفريغ الصوتي الذكي') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return InteractiveTranscriptionSheet(
            initialText: content,
            audioUrl: widget.audioUrl,
            audioDuration: _duration,
            isAlreadyCompleted: isAlreadyCompleted,
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusL)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildSummaryContent(content),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleABLoopToggle() {
    final currentPos = _position;
    if (_loopA == null && _loopB == null) {
      setState(() {
        _loopA = currentPos;
      });
    } else if (_loopA != null && _loopB == null) {
      if (currentPos > _loopA!) {
        setState(() {
          _loopB = currentPos;
        });
        _audioPlayer.seek(_loopA!);
      } else {
        _showErrorDialog('نقطة النهاية (B) يجب أن تكون بعد نقطة البداية (A)');
      }
    } else {
      setState(() {
        _loopA = null;
        _loopB = null;
      });
    }
  }

  Widget _buildABLoopButtonLabel() {
    final TextStyle activeStyle = TextStyle(
      color: Colors.blueAccent,
      fontWeight: FontWeight.bold,
      fontSize: 12,
      shadows: [
        Shadow(
          color: Colors.blueAccent.withOpacity(0.5),
          blurRadius: 8,
        ),
      ],
    );
    
    final TextStyle inactiveStyle = TextStyle(
      color: AppColors.getTextSecondary(context).withOpacity(0.5),
      fontWeight: FontWeight.normal,
      fontSize: 12,
    );

    final TextStyle arrowStyle = TextStyle(
      color: (_loopA != null && _loopB != null) 
          ? Colors.blueAccent 
          : AppColors.getTextSecondary(context).withOpacity(0.4),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'A',
            style: _loopA != null ? activeStyle : inactiveStyle,
          ),
          TextSpan(
            text: ' ⇄ ',
            style: arrowStyle,
          ),
          TextSpan(
            text: 'B',
            style: _loopB != null ? activeStyle : inactiveStyle,
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showUpgradePromptDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusL),
          ),
          backgroundColor: AppColors.getCardBackground(context),
          title: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'طلب ترقية الحساب',
                style: TextStyle(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          content: Text(
            'لقد تجاوزت الحد المسموح به للتفريغ والتلخيص المجاني المتاح للمستخدمين العاديين.\n\nيرجى ترقية حسابك من مستخدم إلى كاتب للحصول على باقة مزايا متكاملة تشمل تفريغاً صوتياً غير محدود وتلخيصاً ذكياً فورياً!',
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Outfit',
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'لاحقاً',
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سيتم فتح صفحة طلب الترقية قريباً'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusS),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'ترقية إلى كاتب',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final cleanFileName = widget.audioTitle ?? AudioHelper.getCleanFileNameFromUrl(widget.audioUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isLoopAOnly = _loopA != null && _loopB == null;
    final bool isLoopActive = _loopA != null && _loopB != null;

    final Color buttonBg = isLoopActive 
        ? Colors.blueAccent.withOpacity(0.12)
        : (isLoopAOnly ? Colors.blueAccent.withOpacity(0.06) : Colors.grey.withOpacity(0.08));

    final BorderSide border = isLoopActive
        ? const BorderSide(color: Colors.blueAccent, width: 1.5)
        : (isLoopAOnly ? const BorderSide(color: Colors.blueAccent, width: 0.5) : BorderSide.none);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context).withOpacity(isDark ? 0.6 : 0.85),
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Filename
              Row(
                children: [
                  const Icon(Icons.audio_file_rounded, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cleanFileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  if (_errorMessage != null)
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20)
                  else if (!_isAudioReady)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                    )
                  else
                    const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
                ],
              ),
              const SizedBox(height: 12),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                // Slider / Progress bar
                Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context)),
                    ),
                    Expanded(
                      child: Slider(
                        activeColor: Colors.blueAccent,
                        inactiveColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                        value: _position.inMilliseconds.toDouble(),
                        max: _duration.inMilliseconds > 0 
                            ? _duration.inMilliseconds.toDouble() 
                            : 100.0,
                        onChanged: (val) {
                          _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context)),
                    ),
                  ],
                ),

                // Main Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Speed Menu
                    PopupMenuButton<double>(
                      icon: Text(
                        '${_speed}x',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
                      ),
                      onSelected: _changeSpeed,
                      itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                        return PopupMenuItem<double>(
                          value: s,
                          child: Text('${s}x', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                    ),

                    // Skip -10s
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded, size: 20),
                      onPressed: () => _skip(-10),
                    ),

                    // Play/Pause Button
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Skip +10s
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded, size: 20),
                      onPressed: () => _skip(10),
                    ),

                    // Repeat toggle
                    IconButton(
                      icon: Icon(
                        _isRepeatEnabled ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        color: _isRepeatEnabled ? Colors.blueAccent : AppColors.getTextSecondary(context),
                      ),
                      onPressed: _toggleRepeat,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),

                // A-B Loop & AI Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // A-B Loop unified button
                    ElevatedButton(
                      onPressed: _handleABLoopToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBg,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        side: border,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusS),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _buildABLoopButtonLabel(),
                    ),

                    // AI Transcribe Button
                    ElevatedButton.icon(
                      onPressed: _isSummarizing ? null : () => _callAIService(true),
                      icon: _isTranscribing
                          ? const Icon(Icons.stop_rounded, size: 14, color: Colors.redAccent)
                          : const Icon(Icons.translate_rounded, size: 14),
                      label: Text(
                        _isTranscribing ? 'إيقاف التفريغ' : 'تفريغ النص',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTranscribing 
                            ? Colors.redAccent.withOpacity(0.1) 
                            : Colors.blueAccent.withOpacity(0.06),
                        foregroundColor: _isTranscribing ? Colors.redAccent : Colors.blueAccent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        side: BorderSide(
                          color: _isTranscribing ? Colors.redAccent : Colors.blueAccent.withOpacity(0.3),
                          width: _isTranscribing ? 1.5 : 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusS),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                    // AI Summarize Button
                    ElevatedButton.icon(
                      onPressed: _isTranscribing ? null : () => _callAIService(false),
                      icon: _isSummarizing
                          ? const Icon(Icons.stop_rounded, size: 14, color: Colors.redAccent)
                          : const Icon(Icons.summarize_rounded, size: 14),
                      label: Text(
                        _isSummarizing ? 'إيقاف الفهرسة' : 'الفهرس',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSummarizing 
                            ? Colors.redAccent.withOpacity(0.1) 
                            : Colors.blueAccent.withOpacity(0.06),
                        foregroundColor: _isSummarizing ? Colors.redAccent : Colors.blueAccent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        side: BorderSide(
                          color: _isSummarizing ? Colors.redAccent : Colors.blueAccent.withOpacity(0.3),
                          width: _isSummarizing ? 1.5 : 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusS),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InteractiveTranscriptionSheet extends StatefulWidget {
  final String initialText;
  final String audioUrl;
  final Duration? audioDuration;
  final bool isAlreadyCompleted;

  const InteractiveTranscriptionSheet({
    super.key,
    required this.initialText,
    required this.audioUrl,
    this.audioDuration,
    this.isAlreadyCompleted = false,
  });

  @override
  State<InteractiveTranscriptionSheet> createState() => _InteractiveTranscriptionSheetState();
}

class _InteractiveTranscriptionSheetState extends State<InteractiveTranscriptionSheet> {
  late String _text;
  late String _currentTimestamp;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
    
    if (widget.isAlreadyCompleted) {
      _currentTimestamp = "";
    } else {
      if (widget.audioDuration != null && widget.audioDuration!.inSeconds <= 300) {
        _currentTimestamp = "";
        _saveCompletedTranscription(_text);
      } else {
        _currentTimestamp = "05:00";
      }
    }
  }

  Future<void> _saveCompletedTranscription(String fullText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('transcription_${widget.audioUrl.hashCode}', fullText);
      debugPrint('💾 Cached completed transcription for: ${widget.audioUrl}');
    } catch (e) {
      debugPrint('⚠️ Error caching completed transcription: $e');
    }
  }

  Future<void> _fetchNextChunk() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String baseUrl = kIsWeb ? Uri.base.origin : 'https://www.sijilli.com';
      final serviceUrl = Uri.parse('$baseUrl/api/transcribe');

      final Map<String, dynamic> requestBody = {
        'startTime': _currentTimestamp,
      };
      if (widget.audioDuration != null) {
        requestBody['duration'] = widget.audioDuration!.inSeconds;
      }

      final isNetwork = widget.audioUrl.startsWith('http://') || 
                        widget.audioUrl.startsWith('https://') ||
                        widget.audioUrl.startsWith('blob:');

      http.Response response;
      if (isNetwork) {
        requestBody['url'] = widget.audioUrl;
        response = await http.post(
          serviceUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 40));
      } else {
        final file = File(widget.audioUrl);
        if (!await file.exists()) {
          throw Exception('الملف الصوتي المحلي غير موجود');
        }
        final bytes = await file.readAsBytes();
        requestBody['audioData'] = base64Encode(bytes);
        
        String mimeType = 'audio/mp3';
        final lower = widget.audioUrl.toLowerCase();
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
          setState(() {
            _text = '$_text\n\n$generatedText';
            
            final parts = _currentTimestamp.split(':');
            if (parts.length == 2) {
              final mins = int.tryParse(parts[0]) ?? 0;
              final secs = int.tryParse(parts[1]) ?? 0;
              final totalSecs = mins * 60 + secs + 300;
              final nextMins = totalSecs ~/ 60;
              final nextSecs = totalSecs % 60;
              
              if (nextMins < 60 || (nextMins == 60 && nextSecs == 0)) {
                final nextMinsStr = nextMins.toString().padLeft(2, '0');
                final nextSecsStr = nextSecs.toString().padLeft(2, '0');
                _currentTimestamp = '$nextMinsStr:$nextSecsStr';
                
                if (widget.audioDuration != null && totalSecs >= widget.audioDuration!.inSeconds) {
                  _currentTimestamp = "";
                  _saveCompletedTranscription(_text);
                }
              } else {
                _currentTimestamp = "";
                _saveCompletedTranscription(_text);
              }
            }
          });
        } else {
          setState(() {
            _currentTimestamp = "";
          });
          _saveCompletedTranscription(_text);
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
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusL)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التفريغ الصوتي الذكي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.getTextPrimary(context),
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentTimestamp.isNotEmpty) ...[
                  if (_isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _fetchNextChunk,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.keyboard_double_arrow_down_rounded, size: 16, color: AppColors.primary),
                      label: Text(
                        'أكمل $_currentTimestamp',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم نسخ النص المفرغ بالكامل بنجاح'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.copy_all_rounded, size: 16),
                  label: const Text(
                    'نسخ النص',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
}
