const { YoutubeTranscript } = require('youtube-transcript');

/**
 * GET /api/youtube-transcript?videoId=XXXX
 *
 * يستخدم مكتبة youtube-transcript التي تستدعي Innertube API
 * الداخلي ليوتيوب — يعمل من الخادم بدون مشاكل CORS أو Consent.
 *
 * يُرجع: { lines: [{ start: ms, duration: ms, text: string }] }
 */
module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const videoId = req.query.videoId;
  if (!videoId || !/^[a-zA-Z0-9_-]{6,20}$/.test(videoId)) {
    return res.status(400).json({ error: 'معرف الفيديو غير صالح' });
  }

  try {
    // محاولة جلب الترجمة بالعربية أولاً ثم الإنجليزية ثم أي لغة
    let rawLines = null;
    const langOrder = ['ar', 'en'];

    for (const lang of langOrder) {
      try {
        rawLines = await YoutubeTranscript.fetchTranscript(videoId, {
          lang,
        });
        if (rawLines && rawLines.length > 0) break;
      } catch (_) {
        // إذا فشلت هذه اللغة، جرّب التالية
      }
    }

    // إذا فشلت كل اللغات المحددة، جرّب بدون تحديد لغة
    if (!rawLines || rawLines.length === 0) {
      rawLines = await YoutubeTranscript.fetchTranscript(videoId);
    }

    if (!rawLines || rawLines.length === 0) {
      return res.status(404).json({
        error: 'لا توجد ترجمة أو تفريغ نصي متوفر لهذا الفيديو',
      });
    }

    // تحويل الصيغة: المكتبة تُعيد { text, duration, offset }
    // نُعيد: { text, start (ms), duration (ms) }
    const lines = rawLines
      .filter((l) => l.text && l.text.trim())
      .map((l) => ({
        start: Math.round((l.offset ?? 0) * 1000),
        duration: Math.round((l.duration ?? 0) * 1000),
        text: l.text
          .replace(/&amp;/g, '&')
          .replace(/&quot;/g, '"')
          .replace(/&#39;/g, "'")
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .trim(),
      }));

    return res.status(200).json({ lines });
  } catch (err) {
    console.error('[youtube-transcript]', err.message);

    // رسائل خطأ مفيدة للمستخدم
    let userMessage = 'فشل جلب التفريغ النصي';
    if (
      err.message?.includes('disabled') ||
      err.message?.includes('No transcript')
    ) {
      userMessage = 'التفريغ النصي معطّل أو غير متوفر لهذا الفيديو';
    } else if (err.message?.includes('unavailable')) {
      userMessage = 'الفيديو غير متاح أو محظور في منطقتك';
    }

    return res.status(500).json({ error: userMessage });
  }
};
