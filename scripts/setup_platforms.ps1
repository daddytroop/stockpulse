# Regenerates the flutter platform folders locally and applies the custom
# Android widget overlay. Run once after cloning.
#
# Usage:
#   .\scripts\setup_platforms.ps1              # android + web
#   .\scripts\setup_platforms.ps1 -Windows     # android + web + windows

param(
    [switch]$Windows
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter is not installed. See https://docs.flutter.dev/get-started/install"
}

$platforms = 'android,web'
if ($Windows) { $platforms = 'android,web,windows' }

flutter create --platforms $platforms .

if (Test-Path 'android/app/src/main/kotlin/com') {
    Remove-Item -Recurse -Force 'android/app/src/main/kotlin/com'
}
if (Test-Path 'android/app/build.gradle.kts') {
    Remove-Item -Force 'android/app/build.gradle.kts'
}
Copy-Item -Recurse -Force 'platform_overlay/android/.' 'android/'

flutter pub get

Write-Host "Done. Run 'flutter run -d windows' or 'flutter build apk --release'."