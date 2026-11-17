# Local-only harness, same layout as serve.cjs, for PCs without Node.js.
# Export Godot to ../../tmp/phase5_web_export/index.html first, then run:
#   powershell -ExecutionPolicy Bypass -File net-sim-3d/web/serve.ps1
# Lobby: http://localhost:8765/   Game: http://localhost:8765/game/index.html
# Listens on localhost only; nothing is published.
$ErrorActionPreference = 'Stop'
$lobby = Join-Path $PSScriptRoot 'index.html'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\tmp\phase5_web_export'))
$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'
  '.wasm' = 'application/wasm'; '.pck' = 'application/octet-stream'
  '.png' = 'image/png'; '.svg' = 'image/svg+xml'
}
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:8765/')
$listener.Start()
Write-Host 'NetSim3D Lobby: http://localhost:8765/'
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    $file = $null
    if ($path -eq '/' -or $path -eq '/index.html') { $file = $lobby }
    elseif ($path.StartsWith('/game/')) {
      $rel = $path.Substring(6); if ($rel -eq '') { $rel = 'index.html' }
      $file = [IO.Path]::GetFullPath((Join-Path $gameRoot $rel))
      if (-not $file.StartsWith($gameRoot + [IO.Path]::DirectorySeparatorChar)) { $res.StatusCode = 403; $file = $null }
    } else { $res.StatusCode = 404 }
    if ($file) {
      if (Test-Path -LiteralPath $file -PathType Leaf) {
        $ext = [IO.Path]::GetExtension($file)
        $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $res.Headers['Cache-Control'] = 'no-cache'
        $fs = [IO.File]::OpenRead($file)
        try { $res.ContentLength64 = $fs.Length; $fs.CopyTo($res.OutputStream) } finally { $fs.Dispose() }
      } else { $res.StatusCode = 404 }
    }
  } catch { Write-Host "request failed: $_" }
  finally { try { $res.Close() } catch {} }
}
