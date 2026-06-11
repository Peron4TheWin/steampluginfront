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
    Remove-Item -Path $wsock -Force -ErrorAction SilentlyContinue
    Write-Log "Deleted versiondll.dll"
}

# ============================================================
# Crear .cef-enable-remote-debugging
# ============================================================

$cefFile = Join-Path $SteamDir ".cef-enable-remote-debugging"

if (-not (Test-Path $cefFile)) {
    New-Item -Path $cefFile -ItemType File -Force | Out-Null
}


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

function Get-GitHubAsset($repo, $assetName) {
    try {
        $headers = @{ "User-Agent" = "steampluginback/1.0"; "Accept" = "application/vnd.github+json" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
        $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
        if (-not $asset) { Write-Log "WARN: Asset $assetName not found in $repo"; return $null }
        $sha256 = ""
        if ($asset.digest -match "^sha256:(.+)$") { $sha256 = $Matches[1] }
        return @{ url = $asset.browser_download_url; sha256 = $sha256; tag = $release.tag_name }
    } catch {
        Write-Log "ERROR fetching $repo`: $_"
        return $null
    }
}

function Download-File($url, $dest) {
    try {
        Write-Log "Downloading: $url"
        $wc = New-Object System.Net.WebClient
        $wc.Headers["User-Agent"] = "steampluginback/1.0"
        $bytes = $wc.DownloadData($url)
        [System.IO.File]::WriteAllBytes($dest, $bytes)
        Write-Log "Saved to $dest ($($bytes.Length) bytes)"
        return $bytes
    } catch {
        Write-Log "ERROR downloading $url`: $_"
        return $null
    }
}

Write-Log "============================================================"
Write-Log "Update started"

# === STFixer (CloudRedirectCLI) ===
Write-Log "=== STFixer ==="
$stfixerPath  = "$SteamDir\stfixer.exe"
$stfixerAsset = Get-GitHubAsset "Selectively11/CloudRedirect" "CloudRedirectCLI.exe"

if (-not $stfixerAsset) {
    Write-Log "WARN: Could not fetch STFixer release info"
} else {
    Write-Log "Latest: $($stfixerAsset.tag) sha256: $($stfixerAsset.sha256)"
    $localHash = Get-SHA256File $stfixerPath
    Write-Log "Local: $localHash"

    if ($localHash -eq $stfixerAsset.sha256) {
        Write-Log "stfixer.exe is up to date"
    } else {
        Write-Log "Downloading stfixer.exe..."
        Download-File $stfixerAsset.url $stfixerPath | Out-Null
    }
}

Write-Log "Running stfixer..."
Start-Process -FilePath $stfixerPath -ArgumentList "/stfixer" -Wait
Write-Log "STFixer done"

# === wsock32.dll ===
Write-Log "=== wsock32.dll ==="
$dllPath  = "$SteamDir\wsock32.dll"
$dllAsset = Get-GitHubAsset "Peron4TheWin/steampluginback" "wsock32.dll"

if (-not $dllAsset) {
    Write-Log "WARN: Could not fetch wsock32.dll release info"
} else {
    Write-Log "Latest: $($dllAsset.tag) sha256: $($dllAsset.sha256)"
    $localHash = Get-SHA256File $dllPath
    Write-Log "Local: $localHash"

    if ($localHash -eq $dllAsset.sha256) {
        Write-Log "wsock32.dll is up to date"
    } else {
        Write-Log "Downloading wsock32.dll..."
        Download-File $dllAsset.url $dllPath | Out-Null
    }
}

# === content.js ===
Write-Log "=== content.js ==="
$jsPath = "$SteamDir\content.js"
$jsUrl  = "https://raw.githubusercontent.com/Peron4TheWin/steampluginfront/refs/heads/master/content/content.js"

try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers["User-Agent"] = "steampluginback/1.0"
    $remoteBytes = $wc.DownloadData($jsUrl)
    $remoteHash  = Get-SHA256Bytes $remoteBytes
    $localHash   = Get-SHA256File $jsPath
    Write-Log "Local: $localHash | Remote: $remoteHash"

    if ($localHash -eq $remoteHash) {
        Write-Log "content.js is up to date"
    } else {
        [System.IO.File]::WriteAllBytes($jsPath, $remoteBytes)
        Write-Log "content.js updated"
    }
} catch {
    Write-Log "WARN: Failed to fetch content.js`: $_"
}

Write-Log "Update done"
