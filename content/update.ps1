function Get-SteamPath {
    $paths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\WOW6432Node\Valve\Steam",
        "HKLM:\Software\Valve\Steam"
    )
    foreach ($p in $paths) {
        try {
            $val = (Get-ItemProperty -Path $p -Name "SteamPath" -ErrorAction Stop).SteamPath
            if ($val) { return $val.Trim('"') }
        } catch {}
    }
    return "C:\Program Files (x86)\Steam"
}

$SteamDir = Get-SteamPath
$LogFile  = "$SteamDir\update.log"

function Write-Log($msg) {
    $ts = [int][double]::Parse((Get-Date -UFormat %s))
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Get-SHA256File($path) {
    if (-not (Test-Path $path)) { return "" }
    try { return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower() } catch { return "" }
}

function Get-SHA256Bytes($bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-","").ToLower()
}

# ============================================================
# Kill todos los procesos Steam
# ============================================================

Get-Process | Where-Object {
    $_.ProcessName -match "steam"
} | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -ErrorAction Stop
        Write-Host "Killed $($_.ProcessName) ($($_.Id))"
    } catch {}
}

Start-Sleep -Seconds 2

# Delete wsock32.dll if present
$wsock = Join-Path $SteamDir "wsock32.dll"
if (Test-Path $wsock) {
    Remove-Item -Path $wsock -Force -ErrorAction SilentlyContinue
    Write-Log "Deleted wsock32.dll"
}

$winhttp = Join-Path $SteamDir "winhttp.dll"
if (Test-Path $winhttp) {
    Remove-Item -Path $winhttp -Force -ErrorAction SilentlyContinue
    Write-Log "Deleted winhttp.dll"
}

# Delete version.dll if present
$versiondll = Join-Path $SteamDir "version.dll"
if (Test-Path $versiondll) {
    Remove-Item -Path $versiondll -Force -ErrorAction SilentlyContinue
    Write-Log "Deleted version.dll"
}

# ============================================================
# Crear .cef-enable-remote-debugging
# ============================================================

$cefFile = Join-Path $SteamDir ".cef-enable-remote-debugging"
if (-not (Test-Path $cefFile)) {
    New-Item -Path $cefFile -ItemType File -Force | Out-Null
}

Write-Log "============================================================"
Write-Log "Update started"

$MirrorBase = "http://api.perondepot.xyz/mirror"

# ── Helper: download from mirror if changed ──────────────────────────
function Update-FromMirror($filename, $localPath) {
    $url = "$MirrorBase/$filename"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers["User-Agent"] = "steampluginback/1.0"
        $remoteBytes = $wc.DownloadData($url)
        $remoteHash  = Get-SHA256Bytes $remoteBytes
        $localHash   = Get-SHA256File $localPath

        if ($localHash -eq $remoteHash) {
            Write-Log "$filename up to date"
        } else {
            [System.IO.File]::WriteAllBytes($localPath, $remoteBytes)
            Write-Log "$filename updated ($($remoteBytes.Length) bytes)"
        }
    } catch {
        Write-Log "WARN: Failed to download $filename`: $_"
    }
}

# === OpenSteamTool.dll ===
Write-Log "=== OpenSteamTool.dll ==="
Update-FromMirror "OpenSteamTool.dll" "$SteamDir\OpenSteamTool.dll"

# === extract_tickets.exe ===
Write-Log "=== extract_tickets.exe ==="
Update-FromMirror "extract_tickets.exe" "$SteamDir\extract_tickets.exe"

# === wsock32.dll ===
Write-Log "=== wsock32.dll ==="
Update-FromMirror "wsock32.dll" "$SteamDir\wsock32.dll"

# === content.js ===
Write-Log "=== content.js ==="
Update-FromMirror "content.js" "$SteamDir\content.js"

# === content_properties.js ===
Write-Log "=== content_properties.js ==="
Update-FromMirror "content_properties.js" "$SteamDir\content_properties.js"

# Crear opensteamtool.toml si no existe
$ostToml = "$SteamDir\opensteamtool.toml"
if (-not (Test-Path $ostToml)) {
    Write-Log "Creando opensteamtool.toml..."
    $tomlContent = @"
[lua]
paths = ["config/stplug-in"]
"@
    Set-Content -Path $ostToml -Value $tomlContent -NoNewline -Encoding UTF8
    Write-Log "opensteamtool.toml creado"
}

Write-Log "Update done"
