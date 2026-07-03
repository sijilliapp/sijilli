const https = require('https');
const { URL } = require('url');

function downloadFile(url, maxRedirects = 5) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, (res) => {
      // Handle redirects (301, 302, 307, 308)
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        if (maxRedirects <= 0) {
          return reject(new Error('Too many redirects'));
        }
        try {
          const targetUrl = new URL(res.headers.location, url).toString();
          return downloadFile(targetUrl, maxRedirects - 1).then(resolve).catch(reject);
        } catch (urlErr) {
          return reject(new Error(`Redirect URL parse error: ${urlErr.message}`));
        }
      }

      if (res.statusCode !== 200) {
        return reject(new Error(`Failed to download file: status ${res.statusCode}`));
      }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    });
    request.on('error', reject);
  });
}

function makeGeminiRequest(apiKey, payload, retriesLeft = 3, delayMs = 2000) {
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
  const requestData = JSON.stringify(payload);

  return new Promise((resolve, reject) => {
    const geminiReq = https.request(
      geminiUrl,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(requestData)
        }
      },
      (geminiRes) => {
        let body = '';
        geminiRes.on('data', (chunk) => { body += chunk; });
        geminiRes.on('end', async () => {
          try {
            let responseJson = {};
            try {
              responseJson = JSON.parse(body);
            } catch (_) {}
            
            const is503 = geminiRes.statusCode === 503 || 
                          (responseJson.error && (responseJson.error.code === 503 || responseJson.error.status === 'UNAVAILABLE'));
                          
            if (is503 && retriesLeft > 0) {
              console.warn(`Gemini 503 returned. Retrying in ${delayMs}ms... (${retriesLeft} retries left)`);
              await new Promise((r) => setTimeout(r, delayMs));
              return makeGeminiRequest(apiKey, payload, retriesLeft - 1, delayMs * 1.5).then(resolve).catch(reject);
            }

            if (responseJson.candidates && responseJson.candidates[0] && responseJson.candidates[0].content && responseJson.candidates[0].content.parts && responseJson.candidates[0].content.parts[0]) {
              resolve(responseJson.candidates[0].content.parts[0].text);
            } else {
              reject(new Error(`Invalid response from Gemini: ${body}`));
            }
          } catch (e) {
            reject(e);
          }
        });
      }
    );

    geminiReq.on('error', async (err) => {
      if (retriesLeft > 0) {
        console.warn(`Request error: ${err.message}. Retrying in ${delayMs}ms...`);
        await new Promise((r) => setTimeout(r, delayMs));
        return makeGeminiRequest(apiKey, payload, retriesLeft - 1, delayMs * 1.5).then(resolve).catch(reject);
      }
      reject(err);
    });

    geminiReq.write(requestData);
    geminiReq.end();
  });
}

function getMimeType(url) {
  const lower = url.toLowerCase();
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  if (lower.endsWith('.opus')) return 'audio/opus';
  if (lower.endsWith('.aac')) return 'audio/aac';
  return 'audio/mp3';
}

module.exports = async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const audioUrl = req.query.url || (req.body && req.body.url);
  const audioData = req.body && req.body.audioData;
  const mimeType = req.body && req.body.mimeType || (audioUrl ? getMimeType(audioUrl) : 'audio/mp3');

  if (!audioUrl && !audioData) {
    return res.status(400).json({ error: 'Missing audio URL or audioData parameter' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'Server configuration error: missing GEMINI_API_KEY' });
  }

  try {
    let base64Audio;
    if (audioData) {
      base64Audio = audioData;
    } else {
      // 1. Download the audio file
      const fileBuffer = await downloadFile(audioUrl);
      base64Audio = fileBuffer.toString('base64');
    }

    const startTime = req.body && req.body.startTime || "00:00";
    // Calculate stop time (+5 minutes)
    let stopTime = "05:00";
    try {
      const parts = startTime.split(':');
      if (parts.length === 2) {
        const mins = parseInt(parts[0], 10);
        const secs = parseInt(parts[1], 10);
        const totalSecs = mins * 60 + secs + 300;
        const stopMins = Math.floor(totalSecs / 60);
        const stopSecs = totalSecs % 60;
        stopTime = `${stopMins.toString().padStart(2, '0')}:${stopSecs.toString().padStart(2, '0')}`;
      }
    } catch (_) {}

    const duration = req.body && req.body.duration;

    let promptText = "قم بتفريغ هذا الملف الصوتي بدقة بالغة إلى نص مقروء باللغة العربية. حافظ على سياق الحديث البشري وعلامات الترقيم المناسبة. إذا كان المتحدث يتحدث بلهجة عامية عربية، قم بكتابتها كما هي بأحرف عربية واضحة ومفهومة دون تبديل أو تغيير يخل بالمعنى الأصلي.";
    
    if (duration && duration <= 300) {
      promptText += ` طول الملف الصوتي الفعلي هو ${duration} ثانية فقط. قم بتفريغ الملف بالكامل من بدايته وحتى نهايته بدقة دون أي زيادة أو تأليف أو تخمين خارج نطاق الصوت الفعلي.`;
    } else {
      promptText += ` قم بتفريغ جزء مدته 5 دقائق فقط من الملف الصوتي، يبدأ من الطابع الزمني [${startTime}] وينتهي عند الطابع الزمني [${stopTime}].`;
      if (duration) {
        promptText += ` الطول الإجمالي للملف الصوتي هو ${duration} ثانية.`;
      }
      promptText += ` تجاهل تماماً أي كلام قيل قبل [${startTime}] أو بعد [${stopTime}]. لا تقم بتأليف أو تخمين أي كلام غير موجود في النطاق المحدد.`;
    }
    promptText += " هام جداً: إذا كان الملف الصوتي (أو الجزء المحدد منه) صامتاً تماماً، أو يحتوي على ضوضاء أو موسيقى فقط، أو أن الكلام البشري فيه غير مفهوم أو غير واضح لغوياً على الإطلاق، فاكتب هذه العبارة المحددة فقط دون أي كلام آخر: [صوت غير واضح أو صمت]. لا تقم بتخمين أو ابتكار أي نصوص على الإطلاق في هذه الحالة.";
    promptText += " اكتب النص المفرغ مباشرة دون أي مقدمات أو شرح.";

    // 2. Prepare payload for Gemini 2.5 Flash
    const payload = {
      contents: [
        {
          parts: [
            {
              inlineData: {
                mimeType: mimeType,
                data: base64Audio
              }
            },
            {
              text: promptText
            }
          ]
        }
      ]
    };

    // 3. Make request with automatic retries for temporary 503 errors
    const transcription = await makeGeminiRequest(apiKey, payload);

    return res.status(200).json({ text: transcription });

  } catch (err) {
    console.error('Transcription error:', err);
    return res.status(500).json({ error: `Failed to transcribe audio: ${err.message}` });
  }
};
