[CmdletBinding()]
param(
    [string] $VersionLabel = "2.7.11b",
    [string] $ProductVersion = "2.7.11",
    [string] $PackageFolderName = "star-2.7.11b-windows-x86_64-msys",
    [string] $OutputName = "win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi",
    [string] $Culture = "en-US",
    [switch] $AcceptWixEula
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Join-FullPath {
    param(
        [Parameter(Mandatory = $true)] [string] $Base,
        [Parameter(Mandatory = $true)] [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Assert-PathExists {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

function Resolve-WixExe {
    $envPath = [Environment]::GetEnvironmentVariable("WIX_EXE")
    if (-not [string]::IsNullOrWhiteSpace($envPath)) {
        Assert-PathExists -Path $envPath -Label "WIX_EXE"
        return [System.IO.Path]::GetFullPath($envPath)
    }

    $command = Get-Command "wix.exe" -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return [System.IO.Path]::GetFullPath($command.Source)
    }

    $defaultPath = "C:\Program Files\WiX Toolset v7.0\bin\wix.exe"
    if (Test-Path -LiteralPath $defaultPath -PathType Leaf) {
        return [System.IO.Path]::GetFullPath($defaultPath)
    }

    throw "Could not find wix.exe. Put it on PATH or set WIX_EXE."
}

function New-CmdLauncher {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Command
    )

    Set-Content -LiteralPath $Path -Value $Command -Encoding ASCII
}

$installerDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $installerDir
$distDir = Join-FullPath -Base $repoRoot -Path "dist"
$packageDir = Join-FullPath -Base $distDir -Path $PackageFolderName
$msiRoot = Join-FullPath -Base $distDir -Path "msi-root"
$toolRoot = Join-FullPath -Base $msiRoot -Path "WinNGS-STAR"
$wxsPath = Join-FullPath -Base $installerDir -Path "star.wxs"
$licenseRtfPath = Join-FullPath -Base $installerDir -Path "LICENSE.rtf"
$outputMsi = Join-FullPath -Base $distDir -Path $OutputName

Assert-PathExists -Path $packageDir -Label "STAR release package folder"
Assert-PathExists -Path $wxsPath -Label "WiX source"
Assert-PathExists -Path $licenseRtfPath -Label "WiX UI license RTF"

if (Test-Path -LiteralPath $msiRoot) {
    $distFull = [System.IO.Path]::GetFullPath($distDir).TrimEnd('\') + '\'
    $msiRootFull = [System.IO.Path]::GetFullPath($msiRoot)
    if (-not $msiRootFull.StartsWith($distFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to delete unsafe MSI staging directory: $msiRootFull"
    }
    Remove-Item -LiteralPath $msiRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $toolRoot | Out-Null

# Copy the ZIP package folder as the installed STAR directory. This standalone
# MSI owns only C:\Program Files\WinNGS-STAR and its own PATH entry.
foreach ($item in (Get-ChildItem -LiteralPath $packageDir -Force)) {
    Copy-Item -LiteralPath $item.FullName -Destination $toolRoot -Recurse -Force
}

New-CmdLauncher -Path (Join-Path $toolRoot "STAR-win.cmd") -Command @"
@echo off
where pwsh.exe >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\STAR-win.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\STAR-win.ps1" %*
)
exit /b %ERRORLEVEL%
"@

New-CmdLauncher -Path (Join-Path $toolRoot "STARlong-win.cmd") -Command @"
@echo off
where pwsh.exe >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\STARlong-win.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\STARlong-win.ps1" %*
)
exit /b %ERRORLEVEL%
"@

$wixExe = Resolve-WixExe
if ($AcceptWixEula) {
    & $wixExe eula accept wix7
    if ($LASTEXITCODE -ne 0) {
        throw "wix eula accept failed with exit code $LASTEXITCODE"
    }
}

$wixArgs = @(
    "build",
    $wxsPath,
    "-arch", "x64",
    "-culture", $Culture,
    "-ext", "WixToolset.UI.wixext",
    "-d", "ProductVersion=$ProductVersion",
    "-d", "VersionLabel=$VersionLabel",
    "-d", "MsiRoot=$msiRoot",
    "-d", "InstallerLicenseRtf=$licenseRtfPath",
    "-o", $outputMsi
)

& $wixExe @wixArgs
if ($LASTEXITCODE -ne 0) {
    throw "wix build failed with exit code $LASTEXITCODE"
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $outputMsi
Write-Host ("Wrote {0}" -f $outputMsi)
Write-Host ("SHA256 {0}  {1}" -f $hash.Hash, (Split-Path -Leaf $outputMsi))
