param(
  [int]$Port = 8080,
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $PSScriptRoot

function Test-LocalPortAvailable {
  param([int]$Port)

  $listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Parse("0.0.0.0"),
    $Port
  )

  try {
    $listener.Start()
    return $true
  } catch {
    return $false
  } finally {
    $listener.Stop()
  }
}

function Get-ContentType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { "text/html; charset=utf-8"; break }
    ".css" { "text/css; charset=utf-8"; break }
    ".js" { "application/javascript; charset=utf-8"; break }
    ".svg" { "image/svg+xml"; break }
    ".png" { "image/png"; break }
    ".jpg" { "image/jpeg"; break }
    ".jpeg" { "image/jpeg"; break }
    ".webp" { "image/webp"; break }
    ".ico" { "image/x-icon"; break }
    default { "application/octet-stream"; break }
  }
}

function Send-Response {
  param(
    [System.IO.Stream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [string]$ContentType,
    [byte[]]$Body
  )

  $headers = @(
    "HTTP/1.1 $StatusCode $StatusText",
    "Content-Type: $ContentType",
    "Content-Length: $($Body.Length)",
    "Connection: close",
    "",
    ""
  ) -join "`r`n"

  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
  $Stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($Body.Length -gt 0) {
    $Stream.Write($Body, 0, $Body.Length)
  }
}

while (-not (Test-LocalPortAvailable -Port $Port)) {
  $Port++
  if ($Port -gt 8099) {
    Write-Host "No free local port found. Opening index.html directly instead."
    Start-Process (Join-Path $PSScriptRoot "index.html")
    exit 0
  }
}

$url = "http://0.0.0.0:$Port/"
$root = [System.IO.Path]::GetFullPath($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar)
$server = [System.Net.Sockets.TcpListener]::new(
  [System.Net.IPAddress]::Parse("0.0.0.0"),
  $Port
)

try {
  $server.Start()
} catch {
  Write-Host "Could not start local web server. Opening index.html directly instead."
  Start-Process (Join-Path $PSScriptRoot "index.html")
  exit 0
}

if (-not $NoBrowser) {
  Start-Process $url
}

Write-Host "Arn1ko Studio site is running at $url"
Write-Host "Press Ctrl+C in this window to stop the local server."

try {
  while ($true) {
    $client = $server.AcceptTcpClient()

    try {
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new(
        $stream,
        [System.Text.Encoding]::ASCII,
        $false,
        1024,
        $true
      )

      $requestLine = $reader.ReadLine()
      while ($true) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrEmpty($line)) {
          break
        }
      }

      if ($requestLine -notmatch "^(GET|HEAD)\s+([^\s]+)\s+HTTP/") {
        $body = [System.Text.Encoding]::UTF8.GetBytes("400 - Bad request")
        Send-Response -Stream $stream -StatusCode 400 -StatusText "Bad Request" -ContentType "text/plain; charset=utf-8" -Body $body
        continue
      }

      $requestPath = $Matches[2].Split("?")[0]
      $requestPath = [System.Uri]::UnescapeDataString($requestPath.TrimStart("/"))
      if ([string]::IsNullOrWhiteSpace($requestPath)) {
        $requestPath = "index.html"
      }

      $safePath = $requestPath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
      $filePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $safePath))

      if (
        -not $filePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not [System.IO.File]::Exists($filePath)
      ) {
        $body = [System.Text.Encoding]::UTF8.GetBytes("404 - File not found")
        Send-Response -Stream $stream -StatusCode 404 -StatusText "Not Found" -ContentType "text/plain; charset=utf-8" -Body $body
        continue
      }

      $content = [System.IO.File]::ReadAllBytes($filePath)
      if ($requestLine.StartsWith("HEAD ")) {
        $content = [byte[]]::new(0)
      }

      Send-Response -Stream $stream -StatusCode 200 -StatusText "OK" -ContentType (Get-ContentType -Path $filePath) -Body $content
    } finally {
      $client.Close()
    }
  }
} finally {
  $server.Stop()
}
