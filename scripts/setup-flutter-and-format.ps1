<#
Automates: extract Flutter ZIP -> install to C:\tools\flutter -> add to PATH -> format file(s) -> optionally commit & push
Usage examples:
  # Dry run (no commit):
  .\scripts\setup-flutter-and-format.ps1 -ZipPath "$env:USERPROFILE\Downloads\flutter_windows_3.41.2-stable.zip"

  # Format the single file and auto-commit+push to current branch:
  .\scripts\setup-flutter-and-format.ps1 -ZipPath "$env:USERPROFILE\Downloads\flutter_windows_3.41.2-stable.zip" -File "lib\features\global_mirror\view\screens\gift_history_screen.dart" -AutoCommit

Parameters:
  -ZipPath <string>   Path to the flutter ZIP file (default: Downloads/flutter_windows_3.41.2-stable.zip)
  -Target <string>    Install target (default: C:\tools\flutter)
  -File <string>      File to format (default the gift_history_screen.dart file CI mentioned)
  -FormatAll          Switch: format folders (lib test backend) instead of a single file
  -AutoCommit         Switch: run git add, commit and push after formatting
  -Message <string>   Commit message (default: "style: format code with dart/flutter format")
#>

param(
    [string] $ZipPath = "$env:USERPROFILE\Downloads\flutter_windows_3.41.2-stable.zip",
    [string] $Target = "C:\\tools\\flutter",
    [string] $File = "lib\\features\\global_mirror\\view\\screens\\gift_history_screen.dart",
    [switch] $FormatAll,
    [switch] $AutoCommit,
    [string] $Message = "style: format code with dart/flutter format"
)

function Fail([string]$msg) {
    Write-Error $msg
    exit 1
}

Write-Output "Parameters:`n ZipPath: $ZipPath`n Target: $Target`n File: $File`n FormatAll: $FormatAll`n AutoCommit: $AutoCommit"

if (-not (Test-Path $ZipPath)) {
    Fail "ZIP not found at: $ZipPath. Please download the Flutter Windows stable zip and set -ZipPath to its location."
}

# Create temp folder and extract
$temp = Join-Path $env:TEMP "flutter_install_temp_$(Get-Random)"
if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
New-Item -ItemType Directory -Path $temp -Force | Out-Null
Write-Output "Extracting $ZipPath -> $temp (this may take a while)"
try {
    Expand-Archive -Path $ZipPath -DestinationPath $temp -Force -ErrorAction Stop
} catch {
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
    Fail "Failed to expand archive: $_"
}

# Determine where the actual flutter folder is inside temp
$children = Get-ChildItem -Path $temp -Force | Where-Object { $_.PSIsContainer }
if ($children.Count -eq 1 -and $children[0].Name -match '^flutter') {
    $extractedFlutter = $children[0].FullName
} else {
    # If archive already flattened or multiple items, treat $temp as flutter folder
    $extractedFlutter = $temp
}

Write-Output "Moving extracted Flutter to $Target"
try {
    if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
    Move-Item -Path $extractedFlutter -Destination $Target -Force
} catch {
    # If move fails (e.g., because extractedFlutter == $temp), try copy
    try {
        Copy-Item -Path (Join-Path $extractedFlutter '*') -Destination $Target -Recurse -Force
        Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
    } catch {
        Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
        # Use explicit exception message to avoid interpolation/parser issues with ':' and '$_'
        $errMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
        Fail "Failed to move or copy extracted Flutter into $Target. Error: $errMsg"
    }
}

# Clean up temp if still exists
if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }

# Determine flutter.bat path
$binCandidate1 = Join-Path $Target 'bin\flutter.bat'
$binCandidate2 = Join-Path $Target 'flutter\bin\flutter.bat' # in case nested
$binPath = $null
if (Test-Path $binCandidate1) { $binPath = Split-Path $binCandidate1 -Parent }
elseif (Test-Path $binCandidate2) { $binPath = Split-Path $binCandidate2 -Parent }
else { Fail "flutter.bat not found under $Target. Check extraction results with Get-ChildItem $Target -Recurse -Depth 2" }

Write-Output "Found flutter.bat in: $binPath"

# Add to current session PATH
if ($env:Path -notlike "*${binPath}*") {
    $env:Path = "$env:Path;$binPath"
    Write-Output "Added $binPath to current session PATH"
}

# Persist to user PATH
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPath -notlike "*${binPath}*") {
    try {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$binPath", 'User')
        Write-Output "Persisted $binPath to User PATH. New shells will pick it up automatically."
    } catch {
        Write-Warning "Could not persist PATH: $_"
    }
} else {
    Write-Output "$binPath already present in User PATH"
}

# Verify flutter
try {
    $versionOutput = & "$binPath\flutter.bat" --version 2>&1
    Write-Output "Flutter version:`n$versionOutput"
} catch {
    Write-Warning "Failed to run flutter --version: $_"
}

# Optionally run doctor -v (comment out if noisy)
try {
    Write-Output "Running flutter doctor -v (may print a few warnings about Android toolchain if not installed)"
    & "$binPath\flutter.bat" doctor -v 2>&1 | Select-Object -First 200 | ForEach-Object { Write-Output $_ }
} catch {
    Write-Warning "flutter doctor failed: $_"
}

# Choose format command: prefer flutter, fall back to dart if available
$formatCmd = "$binPath\flutter.bat"
if (-not (Test-Path "$formatCmd")) {
    # try dart on PATH
    if (Get-Command dart -ErrorAction SilentlyContinue) { $formatCmd = "dart" } else { Fail "Neither flutter nor dart were found for formatting." }
}

# Run formatting
if ($FormatAll) {
    Write-Output "Running format on lib, test, backend"
    & $formatCmd format lib test backend
} else {
    Write-Output "Running format on single file: $File"
    & $formatCmd format $File
}

# Show git status
Write-Output "Git status (porcelain):"
$gitStatus = & git status --porcelain 2>&1
Write-Output $gitStatus

if ($gitStatus -and $AutoCommit) {
    # determine current branch
    try { $branch = (& git rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = 'feature/gift-history-screen' }
    Write-Output "AutoCommit requested. Current branch: $branch"
    & git add -A
    # commit only if there are staged changes
    try {
        & git commit -m "$Message"
        Write-Output "Committed formatting changes"
    } catch {
        Write-Warning "git commit returned non-zero (maybe no changes to commit): $_"
    }
    try {
        Write-Output "Pulling remote updates with rebase"
        & git pull --rebase origin $branch
    } catch {
        Write-Warning "git pull --rebase failed; you may need to resolve conflicts manually: $_"
    }
    try {
        Write-Output "Pushing to origin/$branch"
        & git push origin $branch
    } catch {
        Write-Warning "git push failed: $_"
    }
} elseif ($AutoCommit) {
    Write-Warning "AutoCommit requested but no git changes detected. Nothing to commit."
}

Write-Output "Done. If you persisted PATH, please open a new PowerShell window to pick up the updated PATH, or use the full path to flutter: $binPath\flutter.bat"
