<#
.SYNOPSIS
Runs STARlong with gzipped FASTA/FASTQ/GTF files by temporarily decompressing them first.

.DESCRIPTION
This is a STARlong wrapper around STAR-gz.ps1. It uses STARlong.exe instead of
STAR.exe while keeping the same temporary decompression behavior.
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

$wrapper = Join-Path $PSScriptRoot "STAR-gz.ps1"
$starLong = Join-Path $PSScriptRoot "STARlong.exe"
if (-not (Test-Path -LiteralPath $starLong -PathType Leaf)) {
    $repoBuildPath = Join-Path $PSScriptRoot "win_x86_64\STARlong.exe"
    if (Test-Path -LiteralPath $repoBuildPath -PathType Leaf) {
        $starLong = $repoBuildPath
    }
}

if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
    throw "STAR-gz.ps1 was not found next to this script: $wrapper"
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
