import https from 'https';
import fs from 'fs';

const k = JSON.parse(fs.readFileSync('/home/runner/workspace/.hermes_data/c.json', 'utf-8')).apiKey.trim();
const p = JSON.stringify({query: 'magic link torbox', limit: 5});

const r = https.request({
  hostname: 'api.firecrawl.dev',
  path: '/v1/search',
  method: 'POST',
  headers: {
    'Authorization': 'Bearer ' + k,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(p)
  }
}, x => {
  let b = '';
  x.on('data', d => b += d);
  x.on('end', () => process.stdout.write(b));
});
r.write(p);
r.end();
