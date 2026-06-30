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

    // 2. Prepare payload for Gemini 1.5 Flash
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
              text: "قم بتفريغ هذا الملف الصوتي بدقة بالغة إلى نص مقروء باللغة العربية. حافظ على سياق الحديث البشري وعلامات الترقيم المناسبة. إذا كان المتحدث يتحدث بلهجة عامية عربية، قم بكتابتها كما هي بأحرف عربية واضحة ومفهومة دون تبديل أو تغيير يخل بالمعنى الأصلي."
            }
          ]
        }
      ]
    };

    // 3. Make POST request to Gemini API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;
    
    const requestData = JSON.stringify(payload);
    
    const transcription = await new Promise((resolveRequest, rejectRequest) => {
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
          geminiRes.on('end', () => {
            try {
              const responseJson = JSON.parse(body);
              if (responseJson.candidates && responseJson.candidates[0] && responseJson.candidates[0].content && responseJson.candidates[0].content.parts && responseJson.candidates[0].content.parts[0]) {
                resolveRequest(responseJson.candidates[0].content.parts[0].text);
              } else {
                rejectRequest(new Error(`Invalid response from Gemini: ${body}`));
              }
            } catch (e) {
              rejectRequest(e);
            }
          });
        }
      );

      geminiReq.on('error', rejectRequest);
      geminiReq.write(requestData);
      geminiReq.end();
    });

    return res.status(200).json({ text: transcription });

  } catch (err) {
    console.error('Transcription error:', err);
    return res.status(500).json({ error: `Failed to transcribe audio: ${err.message}` });
  }
};
