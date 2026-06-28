const fs = require('fs');
const path = require('path');
const https = require('https');

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function stripFormatting(text) {
  if (!text) return '';
  
  // 1. Remove markdown images
  let cleanText = text.replace(/!\[.*?\]\((https?:\/\/\S+?)\)/ig, '');
  
  // 2. Remove formatting tags (including BOLD, HIGHLIGHT, and alternate closing tag formats)
  cleanText = cleanText.replace(/\[\/?(POEM|CENTER|JUSTIFY|LEFT|RIGHT|B|BOLD|HIGHLIGHT|AUDIO)\/?\]/ig, '');
  cleanText = cleanText.replace(/\[\//ig, '');
  cleanText = cleanText.replace(/==|~~|--|\+\+|\*/g, '');
  
  const lines = cleanText.split('\n');
  const cleanedLines = [];
  
  const imageRegex = /^(?:https?:\/\/\S+?\.(?:jpg|jpeg|png|webp|gif|bmp)(?:\?\S*)?)$/i;
  const unsplashRegex = /^(?:https?:\/\/images\.unsplash\.com\/\S+|https?:\/\/unsplash\.com\/photo-\S+)$/i;
  const youtubeRegex = /^(?:https?:\/\/)?(?:www\.)?(?:m\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})(?:\S*)?$/i;

  for (const line of lines) {
    let trimmed = line.trim();
    if (trimmed.length > 1) {
      if ((trimmed.startsWith('=') && trimmed.endsWith('=')) ||
          (trimmed.startsWith('~') && trimmed.endsWith('~')) ||
          (trimmed.startsWith('-') && trimmed.endsWith('-')) ||
          (trimmed.startsWith('+') && trimmed.endsWith('+'))) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
    }
    
    // Skip lines that contain only a media link (images or youtube) to keep preview descriptions clean
    if (imageRegex.test(trimmed) || unsplashRegex.test(trimmed) || youtubeRegex.test(trimmed)) {
      continue;
    }
    
    cleanedLines.push(trimmed);
  }
  
  return cleanedLines.join('\n').trim();
}

function extractFirstMediaUrl(text) {
  if (!text) return null;
  const lines = text.split('\n');
  
  const markdownRegex = /!\[.*?\]\((https?:\/\/\S+?)\)/i;
  const imageRegex = /^(?:https?:\/\/\S+?\.(?:jpg|jpeg|png|webp|gif|bmp)(?:\?\S*)?)$/i;
  const unsplashRegex = /^(?:https?:\/\/images\.unsplash\.com\/\S+|https?:\/\/unsplash\.com\/photo-\S+)$/i;
  const youtubeRegex = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/i;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    // 1. Check markdown image
    const markdownMatch = trimmed.match(markdownRegex);
    if (markdownMatch) {
      return markdownMatch[1];
    }

    // Remove alignment tags to inspect raw URL
    let cleanLine = trimmed;
    if (cleanLine.length > 1) {
      if (cleanLine.startsWith('=') && cleanLine.endsWith('=')) {
        cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
      } else if (cleanLine.toUpperCase().startsWith('[CENTER]') && cleanLine.toUpperCase().endsWith('[/CENTER]')) {
        cleanLine = cleanLine.substring(8, cleanLine.length - 9).trim();
      }
    }

    // 2. Check direct image
    if (imageRegex.test(cleanLine) || unsplashRegex.test(cleanLine)) {
      return cleanLine;
    }

    // 3. Check YouTube URL
    const youtubeMatch = cleanLine.match(youtubeRegex);
    if (youtubeMatch) {
      const videoId = youtubeMatch[1];
      return `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`;
    }
  }
  return null;
}

function getTitle(text) {
  const plain = stripFormatting(text);
  if (!plain) return 'مقال';
  const lines = plain.split('\n').filter(l => l.trim().length > 0);
  if (lines.length === 0) return 'مقال';
  const firstLine = lines[0];
  const words = firstLine.split(/\s+/);
  if (words.length <= 5) return firstLine;
  return words.slice(0, 5).join(' ') + '...';
}

function getDescription(text) {
  const plain = stripFormatting(text);
  if (!plain) return '';
  return plain.length > 150 ? plain.substring(0, 150) + '...' : plain;
}

module.exports = async (req, res) => {
  const { username, articleId } = req.query;

  let htmlContent = '';
  try {
    const htmlPath = path.join(process.cwd(), 'web', 'index.html');
    htmlContent = fs.readFileSync(htmlPath, 'utf8');
    htmlContent = htmlContent.replace('<base href="$FLUTTER_BASE_HREF">', '<base href="/">');
  } catch (err) {
    return res.status(500).send('Error loading template');
  }

  if (!articleId) {
    return res.status(200).send(htmlContent);
  }

  try {
    const article = await fetchJson(`https://sijilli.pockethost.io/api/collections/articles/records/${articleId}`);
    if (article && article.id) {
      const title = getTitle(article.text);
      const description = getDescription(article.text);
      const imageUrl = article.image 
        ? `https://sijilli.pockethost.io/api/files/articles/${article.id}/${article.image}`
        : (extractFirstMediaUrl(article.text) || '');
      const url = `https://sijilli.com/${username}/${articleId}`;

      const metaTags = `
  <meta property="og:type" content="article" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${description}" />
  ${imageUrl ? `<meta property="og:image" content="${imageUrl}" />` : ''}
  <meta property="og:url" content="${url}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${description}" />
  ${imageUrl ? `<meta name="twitter:image" content="${imageUrl}" />` : ''}
`;

      htmlContent = htmlContent.replace('</head>', `${metaTags}\n</head>`);
      // Update page title as well
      htmlContent = htmlContent.replace(/<title>.*?<\/title>/, `<title>${title}</title>`);
    }
  } catch (err) {
    // If anything fails, fallback to original HTML
  }

  res.setHeader('Content-Type', 'text/html');
  return res.status(200).send(htmlContent);
};
