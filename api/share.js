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
  let cleanText = text.replace(/\[\/?(POEM|CENTER|JUSTIFY|LEFT|RIGHT|B)\]/ig, '');
  cleanText = cleanText.replace(/==|~~|--|\+\+|\*/g, '');
  const lines = cleanText.split('\n');
  const cleanedLines = lines.map(line => {
    let trimmed = line.trim();
    if (trimmed.length > 1) {
      if ((trimmed.startsWith('=') && trimmed.endsWith('=')) ||
          (trimmed.startsWith('~') && trimmed.endsWith('~')) ||
          (trimmed.startsWith('-') && trimmed.endsWith('-')) ||
          (trimmed.startsWith('+') && trimmed.endsWith('+'))) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
    }
    return trimmed;
  });
  return cleanedLines.join('\n').trim();
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
        : '';
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
