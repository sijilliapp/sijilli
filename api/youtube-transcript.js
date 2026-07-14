const https = require('https');
const { URL } = require('url');

/**
 * Helper: تنزيل محتوى رابط مع دعم إعادة التوجيه
 */
function downloadUrl(url, extraHeaders = {}, maxRedirects = 5) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      method: 'GET',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        ...extraHeaders,
      },
    };

    const req = https.request(options, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        if (maxRedirects <= 0) return reject(new Error('Too many redirects'));
        try {
          const next = new URL(res.headers.location, url).toString();
          return downloadUrl(next, extraHeaders, maxRedirects - 1).then(resolve).catch(reject);
        } catch (e) {
          return reject(e);
        }
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} from ${parsedUrl.hostname}`));
      }
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    });
    req.on('error', reject);
    req.end();
  });
}

/**
 * استخراج كائن JSON لـ ytInitialPlayerResponse من صفحة YouTube
 * يدعم الصيغتين القديمة والحديثة
 */
function extractPlayerResponse(html) {
  const patterns = [
    'ytInitialPlayerResponse = ',
    'ytInitialPlayerResponse=',
    '"ytInitialPlayerResponse":',
  ];

  for (const key of patterns) {
    let startPos = html.indexOf(key);
    if (startPos === -1) continue;
    startPos += key.length;

    // تخطي أي مسافات بيضاء
    while (startPos < html.length && html[startPos] !== '{') startPos++;
    if (startPos >= html.length) continue;

    let braceCount = 0;
    let inString = false;
    let isEscaped = false;
    let endPos = -1;

    for (let i = startPos; i < html.length; i++) {
      const ch = html[i];
      if (isEscaped) { isEscaped = false; continue; }
      if (ch === '\\') { isEscaped = true; continue; }
      if (ch === '"') { inString = !inString; continue; }
      if (!inString) {
        if (ch === '{') braceCount++;
        else if (ch === '}') {
          braceCount--;
          if (braceCount === 0) { endPos = i; break; }
        }
      }
    }

    if (endPos !== -1) {
      try {
        return JSON.parse(html.substring(startPos, endPos + 1));
      } catch (_) {}
    }
  }
  return null;
}

/**
 * تحليل ملف XML لترجمة YouTube وتحويله إلى مصفوفة من الأسطر
 */
function parseXmlTranscript(xml) {
  const lines = [];
  const regex = /<text\b([^>]*)>([\s\S]*?)<\/text>/g;
  let match;
  while ((match = regex.exec(xml)) !== null) {
    const attrs = match[1];
    const rawText = match[2];

    const startMatch = /start="([^"]+)"/.exec(attrs);
    const durMatch = /dur="([^"]+)"/.exec(attrs);

    const startMs = Math.round(parseFloat(startMatch?.[1] || '0') * 1000);
    const durMs = Math.round(parseFloat(durMatch?.[1] || '0') * 1000);

    const text = rawText
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&apos;/g, "'")
      .replace(/&nbsp;/g, ' ')
      .trim();

    if (text) {
      lines.push({ start: startMs, duration: durMs, text });
    }
  }
  return lines;
}

/**
 * GET /api/youtube-transcript?videoId=XXXX
 * يُرجع: { lines: [{ start, duration, text }] }
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
    // ─── 1. جلب صفحة الفيديو من YouTube ───
    const html = await downloadUrl(
      `https://www.youtube.com/watch?v=${videoId}&hl=ar`,
      {
        // Cookie المطلوبة للتجاوز صفحة الموافقة (SOCS)
        Cookie:
          'SOCS=CAESHAgBEhJnd3NfMjAyMzA4MTAtMF9SQzIaAmFyIAEaBgiAo_CmBg; CONSENT=YES+cb.20231001-17-p0.ar+FX+987',
      }
    );

    if (html.length < 1000) {
      return res.status(502).json({ error: 'لم يتم استلام صفحة يوتيوب بشكل صحيح' });
    }

    // ─── 2. استخراج بيانات المشغل ───
    const playerResponse = extractPlayerResponse(html);
    if (!playerResponse) {
      return res.status(404).json({ error: 'لا يتوفر تفريغ نصي لهذا الفيديو (تعذر العثور على بيانات التشغيل)' });
    }

    const captionTracks =
      playerResponse?.captions?.playerCaptionsTracklistRenderer?.captionTracks;

    if (!captionTracks || captionTracks.length === 0) {
      return res.status(404).json({ error: 'لا توجد ترجمة أو تفريغ نصي متوفر لهذا الفيديو' });
    }

    // ─── 3. اختيار أفضل مسار: عربي → إنجليزي → أي مسار ───
    let trackUrl =
      captionTracks.find((t) => t.languageCode === 'ar')?.baseUrl ||
      captionTracks.find((t) => t.languageCode?.startsWith('ar'))?.baseUrl ||
      captionTracks.find((t) => t.languageCode === 'en')?.baseUrl ||
      captionTracks[0]?.baseUrl;

    if (!trackUrl) {
      return res.status(404).json({ error: 'تعذر العثور على رابط مسار الترجمة' });
    }

    // إضافة fmt=json3 إذا كان متاحاً للحصول على JSON بدلاً من XML
    const xmlUrl = trackUrl.includes('fmt=') ? trackUrl : `${trackUrl}&fmt=xml`;

    // ─── 4. جلب ملف XML/JSON للترجمة ───
    const xmlContent = await downloadUrl(xmlUrl);

    // ─── 5. تحليل وإرجاع النتائج ───
    const lines = parseXmlTranscript(xmlContent);

    if (lines.length === 0) {
      return res.status(404).json({ error: 'التفريغ النصي لهذا الفيديو فارغ أو غير متاح' });
    }

    return res.status(200).json({ lines });
  } catch (err) {
    console.error('[youtube-transcript]', err.message);
    return res.status(500).json({ error: `فشل جلب التفريغ النصي: ${err.message}` });
  }
};
