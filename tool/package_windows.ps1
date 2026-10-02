# Packages the Windows build as a portable .zip, a .msi installer, and an
# .msix package.
#
# Usage: pwsh tool/package_windows.ps1
#
# Produces, under build/windows/:
#   ScreenTime-<version>-windows-x64.zip    (portable, extract-and-run)
#   ScreenTimeSetup.msi                     (WiX v6 installer)
#   ScreenTime-<version>-windows-x64.msix   (MSIX package, test-signed)
#
# Requires the WiX Toolset v6 CLI + UI extension (free, no license
# acceptance needed — v7 introduced a paid "Open Source Maintenance Fee"
# EULA gate, so this project pins v6):
#   dotnet tool install --global wix --version 6.0.2
#   wix extension add -g WixToolset.UI.wixext/6.0.2
#
# The .msix is signed with the msix package's bundled self-signed test
# certificate (password "1234"; see msix_config in pubspec.yaml). Before it
# will install on a machine, that certificate must be trusted there — as
# admin, once per machine:
#   Import-PfxCertificate -FilePath build\windows\ScreenTime-test.pfx `
#     -CertStoreLocation Cert:\LocalMachine\TrustedPeople `
#     -Password (ConvertTo-SecureString "1234" -AsPlainText -Force)
# To distribute the msix to other machines without that step, sign it with a
# real code-signing certificate instead (msix_config: certificate_path /
# certificate_password), which this script does not attempt.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pubspec = Get-Content "$root\pubspec.yaml" -Raw
if ($pubspec -notmatch "version:\s*(\S+)\+") {
    throw "Could not read version from pubspec.yaml"
}
$version = $Matches[1]
Write-Host "Packaging Screen Time v$version for Windows..."

Write-Host "`n== flutter build windows --release =="
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

$releaseDir = "$root\build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) { throw "Release directory not found: $releaseDir" }

# The zip includes the LICENSE alongside the app, matching what a end user
# extracting a portable build should see.
Copy-Item "$root\LICENSE" "$releaseDir\LICENSE.txt" -Force

Write-Host "`n== Building portable zip =="
$zipPath = "$root\build\windows\ScreenTime-$version-windows-x64.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Wrote $zipPath"

Write-Host "`n== Building MSI installer =="
$msiPath = "$root\build\windows\ScreenTimeSetup.msi"
& wix build "$root\windows\installer\cat_eyekeeper.wxs" `
    -d "ReleaseDir=$releaseDir" `
    -d "AppVersion=$version" `
    -d "InstallerDir=$root\windows\installer" `
    -ext WixToolset.UI.wixext `
    -arch x64 `
    -o $msiPath
if ($LASTEXITCODE -ne 0) { throw "wix build failed" }
Write-Host "Wrote $msiPath"

Write-Host "`n== Building MSIX package =="
$msixPath = "$root\build\windows\ScreenTime-$version-windows-x64.msix"
& dart run msix:create `
    --build-windows false `
    --install-certificate false `
    --version "$version.0" `
    --output-path "$root\build\windows" `
    --output-name "ScreenTime-$version-windows-x64"
if ($LASTEXITCODE -ne 0) { throw "msix build failed" }
Write-Host "Wrote $msixPath"

# Best-effort convenience copy of the msix package's bundled self-signed
# test certificate (see this script's header) — not required for the
# .msix itself, which is already written above, so a pub cache layout
# this doesn't anticipate (e.g. a non-default PUB_CACHE) shouldn't fail
# the whole packaging run over a file that's only needed for the manual
# "trust this test cert" step on another machine.
$pubCacheRoot = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { "$env:LOCALAPPDATA\Pub\Cache" }
$testCert = Get-ChildItem -Path "$pubCacheRoot\hosted\pub.dev" -Filter "test_certificate.pfx" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\msix-[^\\]+\\' } |
    Select-Object -First 1
if ($testCert) {
    Copy-Item $testCert.FullName "$root\build\windows\ScreenTime-test.pfx" -Force
    Write-Host "Wrote $root\build\windows\ScreenTime-test.pfx"
} else {
    Write-Warning "Could not find the msix package's test_certificate.pfx under '$pubCacheRoot' — skipping the convenience copy; the .msix above is unaffected."
}

Write-Host "`nDone."
