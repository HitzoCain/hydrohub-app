param(
    [Parameter(Mandatory = $true)]
    [string]$VersionName,

    [Parameter(Mandatory = $true)]
    [int]$VersionCode,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotes = "Bug fixes and performance improvements.",

    [Parameter(Mandatory = $false)]
    [switch]$Draft
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repositoryRoot

$keyProperties = Join-Path $repositoryRoot "android\key.properties"
$keystoreSettings = Get-Content $keyProperties -ErrorAction SilentlyContinue
if (-not $keystoreSettings) {
    throw "Missing android/key.properties. Restore the original signing key and create key.properties from android/key.properties.example."
}

$storeFileLine = $keystoreSettings | Where-Object { $_ -match '^storeFile=' } | Select-Object -First 1
if (-not $storeFileLine) {
    throw "android/key.properties does not contain storeFile."
}

$storeFile = $storeFileLine.Substring("storeFile=".Length).Trim()
$keystoreCandidates = @(
    (Join-Path $repositoryRoot "android\app\$storeFile"),
    (Join-Path $repositoryRoot "android\$storeFile"),
    (Join-Path $repositoryRoot $storeFile)
) | Select-Object -Unique
$keystorePath = $keystoreCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if (-not $keystorePath) {
    throw "Signing keystore was not found. Restore the original JKS used by release 1.0.5."
}

if ($VersionName -notmatch '^\d+\.\d+\.\d+$') {
    throw "VersionName must use semantic version format, for example 1.0.6."
}

$pubspecPath = Join-Path $repositoryRoot "pubspec.yaml"
$pubspec = Get-Content $pubspecPath
$pubspec = $pubspec -replace '^version:\s*.*$', "version: $VersionName+$VersionCode"
Set-Content -Path $pubspecPath -Value $pubspec

flutter test test/app_update_service_test.dart
if ($LASTEXITCODE -ne 0) {
    throw "Automatic-update tests failed."
}

flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    throw "Release APK build failed."
}

$builtApk = Join-Path $repositoryRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $builtApk)) {
    throw "Built APK was not found: $builtApk"
}

$apkName = "aqua-in-lavada.apk"
$releaseApk = Join-Path $repositoryRoot $apkName
Copy-Item $builtApk $releaseApk -Force

$sha256 = (Get-FileHash $releaseApk -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = [ordered]@{
    packageName = "io.github.hitzocain.aquainlavada"
    versionName = $VersionName
    versionCode = $VersionCode
    apkAssetName = $apkName
    sha256 = $sha256
    releaseNotes = $ReleaseNotes
}

$manifestPath = Join-Path $repositoryRoot "update.json"
$manifest | ConvertTo-Json | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "Built and prepared $apkName"
Write-Host "SHA-256: $sha256"
Write-Host "Update manifest: $manifestPath"

$tag = "v$VersionName"
if ($Draft) {
    & gh release create $tag `
        --repo "HitzoCain/hydrohub-app" `
        --title "Aqua en Lavada $VersionName" `
        --notes $ReleaseNotes `
        --draft `
        $releaseApk `
        $manifestPath
} else {
    & gh release create $tag `
        --repo "HitzoCain/hydrohub-app" `
        --title "Aqua en Lavada $VersionName" `
        --notes $ReleaseNotes `
        $releaseApk `
        $manifestPath
}
if ($LASTEXITCODE -ne 0) {
    throw "GitHub release creation failed."
}

Write-Host "Published GitHub release $tag"
