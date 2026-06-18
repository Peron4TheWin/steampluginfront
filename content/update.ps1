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

# Igual que Get-GitHubAsset pero matchea por patron en lugar de nombre exacto
function Get-GitHubAssetByPattern($repo, $pattern) {
    try {
        $headers = @{ "User-Agent" = "steampluginback/1.0"; "Accept" = "application/vnd.github+json" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
        $asset = $release.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
        if (-not $asset) { Write-Log "WARN: No asset matching '$pattern' found in $repo"; return $null }
        $sha256 = ""
        if ($asset.digest -match "^sha256:(.+)$") { $sha256 = $Matches[1] }
        return @{ url = $asset.browser_download_url; sha256 = $sha256; tag = $release.tag_name; name = $asset.name }
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

# === OpenSteamTool ===
Write-Log "=== OpenSteamTool ==="

$ostFiles   = @("OpenSteamTool.dll")
$ostStamp   = "$SteamDir\opensteamtool.stamp"
$ostToml    = "$SteamDir\opensteamtool.toml"
$luaDir     = "$SteamDir\config\stplug-in"

$ostAsset = Get-GitHubAssetByPattern "OpenSteam001/OpenSteamTool" "*-Release.zip"

if (-not $ostAsset) {
    Write-Log "WARN: Could not fetch OpenSteamTool release info"
} else {
    Write-Log "Latest: $($ostAsset.tag) ($($ostAsset.name)) sha256: $($ostAsset.sha256)"

    $lastStamp = if (Test-Path $ostStamp) { (Get-Content $ostStamp -Raw).Trim() } else { "" }
    Write-Log "Stamp: $lastStamp"

    $allPresent = ($ostFiles | Where-Object { -not (Test-Path "$SteamDir\$_") }).Count -eq 0

    if ($allPresent -and $lastStamp -eq $ostAsset.sha256) {
        Write-Log "OpenSteamTool up to date, skipping"
    } else {
        if (-not $allPresent) {
            Write-Log "Some OpenSteamTool files missing, downloading..."
        } else {
            Write-Log "SHA256 mismatch or new version, updating..."
        }

        $tmpZip = [System.IO.Path]::GetTempFileName() + ".zip"
        $bytes = Download-File $ostAsset.url $tmpZip

        if ($bytes) {
            $downloadedHash = Get-SHA256File $tmpZip
            if ($ostAsset.sha256 -and $downloadedHash -ne $ostAsset.sha256) {
                Write-Log "ERROR: SHA256 mismatch post-download ($downloadedHash), abortando"
                Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
            } else {
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($tmpZip)
                    foreach ($entry in $zip.Entries) {
                        if ($ostFiles -contains $entry.Name) {
                            $destPath = "$SteamDir\$($entry.Name)"
                            $stream = $entry.Open()
                            $fs = [System.IO.File]::Create($destPath)
                            $stream.CopyTo($fs)
                            $fs.Close()
                            $stream.Close()
                            Write-Log "Extracted: $($entry.Name)"
                        }
                    }
                    $zip.Dispose()
                    Write-Log "OpenSteamTool extracted OK"
                    Set-Content -Path $ostStamp -Value $ostAsset.sha256 -NoNewline
                    Write-Log "Stamp saved"
                } catch {
                    Write-Log "ERROR extracting zip: $_"
                }
                Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Crear toml si no existe, apuntando al dir de plugins del backend
    if (-not (Test-Path $ostToml)) {
        Write-Log "Creando opensteamtool.toml..."
        $luaDirForward = $luaDir.Replace("\", "/")
        $tomlContent = @"
[lua]
paths = ["$luaDirForward"]
"@
        Set-Content -Path $ostToml -Value $tomlContent -NoNewline -Encoding UTF8
        Write-Log "opensteamtool.toml creado"
    } else {
        Write-Log "opensteamtool.toml ya existe, no se toca"
    }
}

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
