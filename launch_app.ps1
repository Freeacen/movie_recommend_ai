$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webDir = Join-Path $projectDir "build\web"

# 1. Check if server is running on port 8080
$connection = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }

if (-not $connection) {
    # Start python server silently using WorkingDirectory
    Start-Process -FilePath "python" -ArgumentList "-m http.server 8080" -WorkingDirectory $webDir -WindowStyle Hidden
    Start-Sleep -Milliseconds 800
}

# 2. Launch in standalone desktop app mode
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

$url = "http://localhost:8080"

if (Test-Path $chromePath) {
    Start-Process -FilePath $chromePath -ArgumentList "--app=$url --window-size=1200,820"
} elseif (Test-Path $edgePath) {
    Start-Process -FilePath $edgePath -ArgumentList "--app=$url --window-size=1200,820"
} else {
    Start-Process $url
}
