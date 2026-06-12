<#
.SYNOPSIS
Runs STARlong on Windows after preparing gzipped or split input files.

.DESCRIPTION
This is the STARlong companion wrapper for STAR-win.ps1. It uses STARlong.exe instead of
STAR.exe while keeping the same temporary file preparation behavior.
#>

[CmdletBinding()]
param(
    [string]$TempDir,
    [switch]$KeepTemp,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$StarArgs
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$scriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
} elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
} else {
    (Get-Location).Path
}
$packageDir = Split-Path -Parent $scriptDir

$wrapper = Join-Path $scriptDir "STAR-win.ps1"
$starLong = Join-Path $scriptDir "STARlong.exe"
if (-not (Test-Path -LiteralPath $starLong -PathType Leaf)) {
    foreach ($baseDir in @($scriptDir, $packageDir)) {
        foreach ($candidate in @("STARlong.exe", "win_x86_64\STARlong.exe", "dist\STARlong.exe")) {
            $candidatePath = Join-Path $baseDir $candidate
            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                $starLong = [System.IO.Path]::GetFullPath($candidatePath)
                break
            }
        }
        if (Test-Path -LiteralPath $starLong -PathType Leaf) { break }
    }
}
if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
    throw "STAR-win.ps1 was not found next to this script: $wrapper"
}

if (-not (Test-Path -LiteralPath $starLong -PathType Leaf)) {
    throw "STARlong.exe was not found next to this script: $starLong"
}

$powerShellExe = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($powerShellExe)) {
    $powerShellExe = "powershell.exe"
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $wrapper,
    "-StarExe", $starLong
)

if ($PSBoundParameters.ContainsKey("TempDir")) {
    $arguments += @("-TempDir", $TempDir)
}

if ($KeepTemp) {
    $arguments += "-KeepTemp"
}

if ($null -ne $StarArgs -and $StarArgs.Count -gt 0) {
    $arguments += $StarArgs
}

& $powerShellExe @arguments
exit $LASTEXITCODE
