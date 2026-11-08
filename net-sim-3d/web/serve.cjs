// Local-only harness. Export Godot to ../../tmp/phase5_web_export/index.html first.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const gameRoot = path.resolve(__dirname, '../../tmp/phase5_web_export');
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml'};
http.createServer((req, res) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname); }
  catch { res.writeHead(400).end(); return; }
  let file;
  if (pathname === '/' || pathname === '/index.html') file = path.join(__dirname, 'index.html');
  else if (pathname.startsWith('/game/')) {
    file = path.resolve(gameRoot, pathname.slice(6) || 'index.html');
    if (!file.startsWith(gameRoot + path.sep)) { res.writeHead(403).end(); return; }
  } else { res.writeHead(404).end(); return; }
  fs.stat(file, (err, info) => {
    if (err || !info.isFile()) { res.writeHead(404).end('Export the Godot Web build first.'); return; }
    res.writeHead(200, {'Content-Type':mime[path.extname(file)] || 'application/octet-stream','Content-Length':info.size,'Cache-Control':'no-cache'});
    const stream = fs.createReadStream(file);
    stream.on('error', () => res.destroy());
    stream.pipe(res);
  });
}).listen(8765, '127.0.0.1', () => console.log('NetSim3D Lobby: http://127.0.0.1:8765/'));
