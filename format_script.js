const fs = require('fs');
const https = require('https');

const filePath = 'lib/features/global_mirror/view/screens/gift_history_screen.dart';
const source = fs.readFileSync(filePath, 'utf8');

const postData = JSON.stringify({ source: source });

const options = {
  hostname: 'stable.api.dartpad.dev',
  path: '/api/dartservices/v2/format',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

const req = https.request(options, (res) => {
  let rawData = '';
  res.on('data', (chunk) => { rawData += chunk; });
  res.on('end', () => {
    try {
      const parsedData = JSON.parse(rawData);
      if (parsedData.error) {
        console.error('Format error:', parsedData.error.message);
      } else if (parsedData.newString) {
        fs.writeFileSync(filePath, parsedData.newString);
        console.log('Formatted successfully');
      } else {
        console.log('No newString in response:', rawData);
      }
    } catch (e) {
      console.error(e.message);
    }
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.write(postData);
req.end();
