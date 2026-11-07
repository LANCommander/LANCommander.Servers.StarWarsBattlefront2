#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Star Wars: Battlefront II (2005) is retail software with no public download. Use an existing install
# (the folder that holds GameData/BattlefrontII.exe) in /config/Server, or set SWBF2_ARCHIVE_URL to a
# zip of it (GameData/ at the zip root, or inside one top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallBattlefront2"

$exe = Join-Path $Env:SERVER_DIR 'GameData/BattlefrontII.exe'

if (Test-Path -Path $exe) {
    Write-Log "Star Wars: Battlefront II found in $Env:SERVER_DIR"
} elseif ($Env:SWBF2_ARCHIVE_URL) {
    Write-Log "Installing Star Wars: Battlefront II from $Env:SWBF2_ARCHIVE_URL"

    # The archive is about 7.5 GB, so work under /config rather than the container's root filesystem.
    # A file:// archive is read in place instead of being copied first.
    $extract    = '/config/.swbf2-extract'
    $downloaded = $null

    if ($Env:SWBF2_ARCHIVE_URL -like 'file://*') {
        $zip = [System.Uri]::UnescapeDataString($Env:SWBF2_ARCHIVE_URL.Substring(7))
        if (-not (Test-Path -Path $zip -PathType Leaf)) { throw "Archive not found: $zip" }
    } else {
        $zip = '/config/.swbf2-download.zip'
        $downloaded = $zip
        curl -fL --retry 3 --output $zip "$Env:SWBF2_ARCHIVE_URL"
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:SWBF2_ARCHIVE_URL" }
    }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    # The server only needs GameData/, and not its 4 GB of cutscenes (data/_lvl_pc/movies). unzip's *
    # also matches /, so one pattern covers GameData/ at the root and inside a top-level folder; -C
    # makes the patterns case-insensitive (a pattern that matches nothing makes unzip fail).
    unzip -q -o -C $zip '*GameData/*' -x '*/_lvl_pc/movies/*' -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept GameData/ at the zip root or inside one top-level folder
    $gameData = Get-ChildItem -Path $extract -Filter 'BattlefrontII.exe' -Recurse -File -Depth 2 |
        Where-Object { $_.Directory.Name -ieq 'GameData' } |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $gameData) { throw "GameData/BattlefrontII.exe not found in $Env:SWBF2_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Remove-Item -Recurse -Force -Path (Join-Path $Env:SERVER_DIR 'GameData') -ErrorAction SilentlyContinue
    Move-Item -Force -Path $gameData.FullName -Destination (Join-Path $Env:SERVER_DIR 'GameData')
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $extract
    if ($downloaded) { Remove-Item -Force -Path $downloaded }

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Star Wars: Battlefront II installed"
} else {
    Write-Log -Level Error "GameData/BattlefrontII.exe not found in $Env:SERVER_DIR. Copy a Star Wars: Battlefront II install there or set SWBF2_ARCHIVE_URL."
}

Invoke-Hook "PostInstallBattlefront2"

Set-Location $Env:SERVER_ROOT
