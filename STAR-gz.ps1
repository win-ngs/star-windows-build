<#
.SYNOPSIS
Runs STAR with gzipped FASTA/FASTQ files by temporarily decompressing them first.

.DESCRIPTION
This wrapper avoids STAR's --readFilesCommand path on Windows. It expands any
.gz files listed after --genomeFastaFiles, --sjdbGTFfile, or --readFilesIn into
a temporary directory, runs STAR with the decompressed files, and removes the
temporary files after STAR exits.
#>

[CmdletBinding()]
param(
    [string]$StarExe,
    [string]$TempDir,
    [switch]$KeepTemp,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$StarArgs
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$script:ScriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
} elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
} else {
    (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($StarExe)) {
    $StarExe = Join-Path $script:ScriptDir "STAR.exe"
}

function Write-Info {
    param([string]$Message)
    Write-Host "[STAR-gz] $Message"
}

function Write-Usage {
    Write-Host @"
Usage:
  .\STAR-gz.ps1 [wrapper options] --runThreadN 8 --genomeDir .\genome_index --readFilesIn .\R1.fastq.gz .\R2.fastq.gz --outFileNamePrefix .\star_output\
  .\STAR-gz.ps1 [wrapper options] --runMode genomeGenerate --genomeDir .\genome_index --genomeFastaFiles .\reference.fa.gz --sjdbGTFfile .\annotation.gtf.gz

Wrapper options:
  -StarExe <path>   Path to STAR.exe. Defaults to STAR.exe next to this script.
  -TempDir <path>   Directory under which temporary decompressed files are created.
  -KeepTemp         Keep temporary decompressed files after STAR exits.

Do not pass --readFilesCommand to this wrapper.
"@
}

function Resolve-StarExecutable {
    param([string]$Path)

    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf) -and [System.IO.Path]::GetFileName($Path) -eq "STAR.exe") {
        $repoBuildPath = Join-Path $script:ScriptDir "win_x86_64\STAR.exe"
        if (Test-Path -LiteralPath $repoBuildPath -PathType Leaf) {
            $resolved = [System.IO.Path]::GetFullPath($repoBuildPath)
        }
    }

    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "STAR executable was not found: $resolved"
    }
    return $resolved
}

function New-StarTempDirectory {
    param([string]$Parent)

    if ([string]::IsNullOrWhiteSpace($Parent)) {
        $Parent = (Get-Location).Path
    }

    $parentFull = [System.IO.Path]::GetFullPath($Parent)
    New-Item -ItemType Directory -Path $parentFull -Force | Out-Null

    $name = "star-gz-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
    $path = Join-Path $parentFull $name
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Expand-GzipFile {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    $source = [System.IO.File]::OpenRead($SourcePath)
    try {
        $gzip = [System.IO.Compression.GzipStream]::new($source, [System.IO.Compression.CompressionMode]::Decompress)
        try {
            $destination = [System.IO.File]::Create($DestinationPath)
            try {
                $gzip.CopyTo($destination)
            } finally {
                $destination.Dispose()
            }
        } finally {
            $gzip.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

function Test-StarOption {
    param([string]$Value)
    return $Value.StartsWith("--", [System.StringComparison]::Ordinal)
}

function Convert-GzipArgument {
    param(
        [string]$Argument,
        [string]$OptionName
    )

    $parts = @($Argument -split ",")
    $patchedParts = @()

    foreach ($part in $parts) {
        if ($part.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($null -eq $script:tempWorkDir) {
                $script:tempWorkDir = New-StarTempDirectory -Parent $TempDir
                Write-Info "Temporary directory: $script:tempWorkDir"
            }

            $sourcePath = [System.IO.Path]::GetFullPath($part)
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                throw "Input file was not found: $sourcePath"
            }

            $script:decompressedCount++
            $sourceName = [System.IO.Path]::GetFileName($sourcePath)
            $outputName = $sourceName.Substring(0, $sourceName.Length - 3)
            $prefix = switch ($OptionName) {
                "--genomeFastaFiles" { "genome" }
                "--sjdbGTFfile" { "gtf" }
                default { "read" }
            }
            $destinationPath = Join-Path $script:tempWorkDir ("{0}_{1}_{2}" -f $prefix, $script:decompressedCount, $outputName)

            Write-Info "Decompressing $sourceName for $OptionName"
            Expand-GzipFile -SourcePath $sourcePath -DestinationPath $destinationPath
            $patchedParts += $destinationPath
        } else {
            $patchedParts += $part
        }
    }

    return ($patchedParts -join ",")
}

$exitCode = 1
$script:tempWorkDir = $null
$script:decompressedCount = 0

try {
    if ($null -eq $StarArgs -or $StarArgs.Count -eq 0) {
        Write-Usage
        $exitCode = 64
        return
    }

    if ($StarArgs -contains "--readFilesCommand") {
        throw "Do not use --readFilesCommand with this Windows wrapper. Pass .gz files directly to --genomeFastaFiles, --sjdbGTFfile, or --readFilesIn instead."
    }

    $starPath = Resolve-StarExecutable -Path $StarExe

    $fileOptions = @("--genomeFastaFiles", "--sjdbGTFfile", "--readFilesIn")
    $patchedArgs = New-Object System.Collections.Generic.List[string]
    $index = 0

    while ($index -lt $StarArgs.Count) {
        $arg = $StarArgs[$index]
        $patchedArgs.Add($arg)

        if ($fileOptions -contains $arg) {
            $index++
            if ($index -ge $StarArgs.Count -or (Test-StarOption $StarArgs[$index])) {
                throw "$arg was found, but no input files were provided."
            }

            while ($index -lt $StarArgs.Count -and -not (Test-StarOption $StarArgs[$index])) {
                $patchedArgs.Add((Convert-GzipArgument -Argument $StarArgs[$index] -OptionName $arg))
                $index++
            }
            continue
        }

        $index++
    }

    if ($script:decompressedCount -eq 0) {
        Write-Info "No .gz input files found. Running STAR with the original files."
    } else {
        Write-Info "Running STAR with $script:decompressedCount decompressed input file(s)."
    }

    $patchedArgArray = [string[]]$patchedArgs.ToArray()
    & $starPath @patchedArgArray
    $exitCode = $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("[STAR-gz] ERROR: " + $_.Exception.Message)
    $exitCode = 1
} finally {
    if ($null -ne $script:tempWorkDir -and (Test-Path -LiteralPath $script:tempWorkDir)) {
        if ($KeepTemp) {
            Write-Info "Keeping temporary directory: $script:tempWorkDir"
        } else {
            Write-Info "Removing temporary directory: $script:tempWorkDir"
            Remove-Item -LiteralPath $script:tempWorkDir -Recurse -Force
        }
    }
}

exit $exitCode
