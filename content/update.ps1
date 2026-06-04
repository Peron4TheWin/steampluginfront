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

# === CloudRedirectCLI ===
Write-Log "=== CloudRedirect ==="
$crExe   = "$SteamDir\CloudRedirectCLI.exe"
$crDll   = "$SteamDir\cloud_redirect.dll"
$crStamp = "$SteamDir\CloudRedirectCLI.stamp"
$crAsset = Get-GitHubAsset "Selectively11/CloudRedirect" "CloudRedirectCLI.exe"

if (-not $crAsset) {
    Write-Log "WARN: Could not fetch CloudRedirect release info"
} else {
    Write-Log "Latest: $($crAsset.tag) sha256: $($crAsset.sha256)"
    $lastStamp = if (Test-Path $crStamp) { (Get-Content $crStamp -Raw).Trim() } else { "" }
    $localHash = Get-SHA256File $crExe
    Write-Log "Local: $localHash | Stamp: $lastStamp"

    $needsRun = $false

    if (-not (Test-Path $crExe)) {
        Write-Log "CloudRedirectCLI.exe not found - downloading..."
        $bytes = Download-File $crAsset.url $crExe
        if ($bytes) { $needsRun = $true }
    } elseif ($localHash -ne $crAsset.sha256) {
        Write-Log "SHA256 mismatch - updating..."
        $bytes = Download-File $crAsset.url $crExe
        if ($bytes) { $needsRun = $true }
    } elseif ($lastStamp -ne $crAsset.sha256) {
        Write-Log "Not yet run for this version"
        $needsRun = $true
    } elseif (-not (Test-Path $crDll)) {
        Write-Log "cloud_redirect.dll missing - running stfixer again"
        $needsRun = $true
    } else {
        Write-Log "CloudRedirectCLI up to date and already ran"
    }

    if ($needsRun) {
        Write-Log "Running CloudRedirectCLI /stfixer..."
        $proc = Start-Process -FilePath $crExe -ArgumentList "/stfixer" -Wait -PassThru
        Write-Log "CloudRedirectCLI exited with code: $($proc.ExitCode)"
        Set-Content -Path $crStamp -Value $crAsset.sha256 -NoNewline
        Write-Log "Stamp saved"
    }
}

# === version.dll ===
Write-Log "=== version.dll ==="
$dllPath  = "$SteamDir\version.dll"
$dllAsset = Get-GitHubAsset "Peron4TheWin/steampluginback" "version.dll"

if (-not $dllAsset) {
    Write-Log "WARN: Could not fetch version.dll release info"
} else {
    Write-Log "Latest: $($dllAsset.tag) sha256: $($dllAsset.sha256)"
    $localHash = Get-SHA256File $dllPath
    Write-Log "Local: $localHash"

    if ($localHash -eq $dllAsset.sha256) {
        Write-Log "version.dll is up to date"
    } else {
        Write-Log "Downloading version.dll..."
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
