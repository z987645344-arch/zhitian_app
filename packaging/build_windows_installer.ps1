# Build: powershell -File packaging/build_windows_installer.ps1
# Existing release only: add -SkipBuild. Inspect version without building: -PrepareOnly.
# Completes the historical installer-version TODO: pubspec.yaml is the only version source.
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$PrepareOnly,
    [string]$IsccPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw
$versions = [regex]::Matches($manifest, '(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*(?:#.*)?$')
if ($versions.Count -ne 1) {
    throw 'pubspec.yaml must contain exactly one version in x.y.z+build format.'
}
$appVersion = $versions[0].Groups[1].Value
$versionParts = $appVersion -split '[.+]'
foreach ($part in $versionParts) {
    if ([long]$part -gt 65535) { throw 'Windows version components must be between 0 and 65535.' }
}
$releaseVersion = $versionParts[0..2] -join '.'
$resourceVersion = $versionParts -join '.'
$outputPath = Join-Path $projectRoot "dist/zhitian-windows-setup-$releaseVersion.exe"
if ($PrepareOnly) {
    [pscustomobject]@{ AppVersion = $appVersion; ResourceVersion = $resourceVersion; Output = $outputPath }
    return
}

if (-not $IsccPath) {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $IsccPath = if ($compiler) { $compiler.Source } else {
        Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
    }
}
if (-not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) { throw 'Inno Setup compiler not found.' }

Push-Location $projectRoot
try {
    if (-not $SkipBuild) {
        & flutter build windows --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw "Flutter release build failed: $LASTEXITCODE" }
    }
    $appExe = Join-Path $projectRoot 'build/windows/x64/runner/Release/zhitian.exe'
    if (-not (Test-Path -LiteralPath $appExe -PathType Leaf)) { throw 'Release zhitian.exe not found.' }
    $appInfo = (Get-Item -LiteralPath $appExe).VersionInfo
    if ($appInfo.FileVersion -ne $appVersion -or $appInfo.ProductVersion -ne $appVersion) {
        throw "Release executable version does not match pubspec.yaml ($appVersion). Rebuild before packaging."
    }
    & $IsccPath "/DMyAppVersion=$appVersion" "/DMyAppReleaseVersion=$releaseVersion" `
        "/DMyAppResourceVersion=$resourceVersion" (Join-Path $PSScriptRoot 'windows_installer.iss')
    if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed: $LASTEXITCODE" }
    $setupInfo = (Get-Item -LiteralPath $outputPath).VersionInfo
    # Inno Setup pads string resources with spaces; compare exact versions after removing that padding.
    $setupFileVersion = @($setupInfo.FileMajorPart, $setupInfo.FileMinorPart,
        $setupInfo.FileBuildPart, $setupInfo.FilePrivatePart) -join '.'
    $setupProductVersion = @($setupInfo.ProductMajorPart, $setupInfo.ProductMinorPart,
        $setupInfo.ProductBuildPart, $setupInfo.ProductPrivatePart) -join '.'
    if ($setupInfo.FileVersion.Trim() -ne $appVersion -or $setupInfo.ProductVersion.Trim() -ne $appVersion `
        -or $setupFileVersion -ne $resourceVersion -or $setupProductVersion -ne $resourceVersion) {
        throw 'Installer text version does not match pubspec.yaml.'
    }
    [pscustomobject]@{
        AppVersion = $appVersion
        ResourceVersion = $resourceVersion
        Output = $outputPath
        SizeBytes = (Get-Item -LiteralPath $outputPath).Length
        SHA256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    }
} finally {
    Pop-Location
}
