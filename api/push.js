const crypto = require('crypto');
const http2 = require('http2');

// Helper to sign APNs JWT
function generateAPNsToken(privateKeyPem, keyId, teamId) {
  const header = {
    alg: 'ES256',
    kid: keyId
  };
  const payload = {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000)
  };
  
  const base64UrlHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  const base64UrlPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  
  const sign = crypto.createSign('SHA256');
  sign.update(`${base64UrlHeader}.${base64UrlPayload}`);
  const signature = sign.sign(privateKeyPem, 'base64url');
  
  return `${base64UrlHeader}.${base64UrlPayload}.${signature}`;
}

// Helper to send HTTP/2 request to a specific APNs host
function sendRequest(host, jwtToken, deviceToken, bundleId, payload) {
  return new Promise((resolve, reject) => {
    const client = http2.connect(`https://${host}`);
    
    client.on('error', (err) => {
      reject(err);
    });
    
    const headers = {
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      'authorization': `bearer ${jwtToken}`,
      'apns-push-type': 'alert',
      'apns-topic': bundleId,
      'apns-expiration': '0',
      'apns-priority': '10',
      'content-type': 'application/json'
    };
    
    const req = client.request(headers);
    
    req.on('response', (resHeaders) => {
      let data = '';
      req.on('data', (chunk) => {
        data += chunk;
      });
      req.on('end', () => {
        client.close();
        const status = resHeaders[':status'];
        resolve({ status, data: data ? JSON.parse(data) : {} });
      });
    });
    
    req.on('error', (err) => {
      reject(err);
    });
    
    req.write(JSON.stringify(payload));
    req.end();
  });
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { deviceToken, title, body, badge, sound, relatedId, type } = req.body;

  if (!deviceToken || !title || !body) {
    return res.status(400).json({ error: 'Missing deviceToken, title, or body' });
  }

  const privateKey = process.env.APNS_PRIVATE_KEY; // The raw content of the .p8 file (with newlines replaced or intact)
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID; // e.g. com.sijilli.app

  if (!privateKey || !keyId || !teamId || !bundleId) {
    return res.status(500).json({ error: 'Server environment variables not configured' });
  }

  try {
    // Format the private key if it was passed as a single line with escaped newlines
    let formattedKey = privateKey;
    if (!formattedKey.includes('\n') && formattedKey.includes('\\n')) {
      formattedKey = formattedKey.replace(/\\n/g, '\n');
    }

    // Generate the JWT signed token (lasts 1 hour, generated fresh per request)
    const jwtToken = generateAPNsToken(formattedKey, keyId, teamId);

    const payload = {
      aps: {
        alert: {
          title: title,
          body: body
        },
        sound: sound || 'default',
        badge: badge || 1
      },
      relatedId: relatedId || '',
      type: type || ''
    };

    // 1. Try sending to Production APNs server
    let result = await sendRequest('api.push.apple.com', jwtToken, deviceToken, bundleId, payload);
    
    // 2. If it's a BadDeviceToken or BadEnvironmentKeyInToken, it might be a Sandbox/TestFlight token. Retry on Sandbox server.
    if (result.status !== 200 && (result.data.reason === 'BadDeviceToken' || result.data.reason === 'BadEnvironmentKeyInToken')) {
      console.log('🔄 APNs environment mismatch on production, retrying on sandbox server...');
      result = await sendRequest('api.sandbox.push.apple.com', jwtToken, deviceToken, bundleId, payload);
    }

    if (result.status === 200) {
      return res.status(200).json({ success: true });
    } else {
      return res.status(result.status).json({ success: false, reason: result.data.reason });
    }
  } catch (error) {
    console.error('❌ APNs error:', error);
    return res.status(500).json({ error: error.message });
  }
}
