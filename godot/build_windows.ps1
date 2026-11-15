param(
    [string]$Config = "release"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SwiftDir = Join-Path $ScriptDir "swift"
$BinDest = Join-Path $ScriptDir "bin"

Write-Host "Building GezGodot ($Config) for Windows..."
Push-Location $SwiftDir
try {
    swift build -c $Config
    if ($LASTEXITCODE -ne 0) {
        throw "swift build failed with exit code $LASTEXITCODE"
    }
    $BuildBin = (swift build -c $Config --show-bin-path).Trim()
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path $BinDest | Out-Null

foreach ($dllName in @("GezGodot.dll", "SwiftGodotRuntime.dll")) {
    $src = Join-Path $BuildBin $dllName
    if (Test-Path $src) {
        Copy-Item -Force $src $BinDest
    }
    else {
        Write-Warning "Expected built DLL not found at $src"
    }
}

# Locate Swift runtime DLLs per SwiftGodot WINDOWS_BUILD.md
$runtimeCandidates = @()
if ($env:LOCALAPPDATA) {
    $runtimeCandidates += Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Programs\Swift\Runtimes\*\usr\bin") -ErrorAction SilentlyContinue
}
$runtimeCandidates += Get-ChildItem -Path "C:\Users\*\AppData\Local\Programs\Swift\Runtimes\*\usr\bin" -ErrorAction SilentlyContinue
$runtimeCandidates += Get-ChildItem -Path "C:\Program Files\Swift\Runtimes\*\usr\bin" -ErrorAction SilentlyContinue
if ($env:SDKROOT) {
    $sdkRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $env:SDKROOT))
    $runtimeCandidates += Get-ChildItem -Path (Join-Path $sdkRoot "Runtimes\*\usr\bin") -ErrorAction SilentlyContinue
}

$runtimeDir = ($runtimeCandidates | Select-Object -First 1).FullName
if (-not $runtimeDir) {
    # Fallback: check PATH entries for swiftCore.dll
    $swiftCoreOnPath = ($env:PATH -split ";" | Where-Object { $_ -and (Test-Path (Join-Path $_ "swiftCore.dll")) } | Select-Object -First 1)
    $runtimeDir = $swiftCoreOnPath
}

if (-not $runtimeDir) {
    throw "Could not locate Swift runtime DLL directory (swiftCore.dll)."
}

Write-Host "Copying Swift runtime DLLs from $runtimeDir..."
Copy-Item -Force -Path (Join-Path $runtimeDir "*.dll") -Destination $BinDest

Write-Host "Built and staged Windows GDExtension into: $BinDest"
