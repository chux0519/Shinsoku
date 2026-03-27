param(
    [Parameter(Mandatory = $true)][string]$AppName,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Config,
    [Parameter(Mandatory = $true)][string]$ExecutablePath,
    [Parameter(Mandatory = $true)][string]$WindeployQtPath,
    [Parameter(Mandatory = $true)][string]$VcpkgInstalledDir,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ExecutablePath)) {
    throw "Executable not found: $ExecutablePath"
}

if (-not (Test-Path -LiteralPath $WindeployQtPath)) {
    throw "windeployqt not found: $WindeployQtPath"
}

$normalizedConfig = if ([string]::IsNullOrWhiteSpace($Config)) { "Release" } else { $Config }
$isDebug = $normalizedConfig -ieq "Debug"
$isRelease = $normalizedConfig -ieq "Release"
if (-not $isRelease) {
    throw "package_windows_portable is intended for a Release-configured build tree. Current config: $normalizedConfig"
}
$runtimeBinDir = if ($normalizedConfig -ieq "Debug") {
    Join-Path $VcpkgInstalledDir "debug\\bin"
} else {
    Join-Path $VcpkgInstalledDir "bin"
}

if (-not (Test-Path -LiteralPath $runtimeBinDir)) {
    throw "vcpkg runtime bin directory not found: $runtimeBinDir"
}

$packageRootName = "{0}-{1}-windows-portable" -f $AppName, $Version
$stageRoot = Join-Path $OutputDir ("stage-" + $normalizedConfig.ToLowerInvariant())
$stageDir = Join-Path $stageRoot $packageRootName
$zipPath = Join-Path $OutputDir ($packageRootName + ".zip")

$env:PATH = $runtimeBinDir + ";" + $env:PATH

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

Copy-Item -LiteralPath $ExecutablePath -Destination (Join-Path $stageDir ([System.IO.Path]::GetFileName($ExecutablePath))) -Force

$deployArgs = @(
    "--dir", $stageDir,
    "--no-compiler-runtime",
    "--no-translations",
    "--no-system-d3d-compiler",
    "--no-opengl-sw",
    $ExecutablePath
)
if ($isDebug) {
    $deployArgs = @("--debug") + $deployArgs
} else {
    $deployArgs = @("--release") + $deployArgs
}

& $WindeployQtPath @deployArgs
if ($LASTEXITCODE -ne 0) {
    throw "windeployqt failed with exit code $LASTEXITCODE"
}

Get-ChildItem -LiteralPath $runtimeBinDir -Filter *.dll | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stageDir $_.Name) -Force
}

$readmePath = Join-Path $stageDir "README.txt"
@"
Shinsoku portable package

Run:
  shinsoku.exe

Notes:
  - This is a portable build with bundled Qt and runtime dependencies.
  - Settings, history, and recordings are stored in the user config/data location.
"@ | Set-Content -LiteralPath $readmePath -Encoding ASCII

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -LiteralPath $stageDir -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Portable package created:"
Write-Host "  $zipPath"
