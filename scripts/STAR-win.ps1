<#
.SYNOPSIS
Runs STAR on Windows after preparing gzipped or split input files.

.DESCRIPTION
This Windows wrapper avoids STAR's --readFilesCommand path. It expands .gz
files listed after --genomeFastaFiles, --sjdbGTFfile, or --readFilesIn,
concatenates comma-separated --readFilesIn lists per mate, runs STAR with the
prepared files, and removes temporary files after STAR exits.
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

function Write-Info { param([string]$Message) Write-Host "[STAR-win] $Message" }

function Write-Usage {
    Write-Host @"
Usage:
  .\STAR-win.ps1 [wrapper options] --runThreadN 8 --genomeDir .\genome_index --readFilesIn .\R1.fastq.gz .\R2.fastq.gz --outFileNamePrefix .\star_output\
  .\STAR-win.ps1 [wrapper options] --runMode genomeGenerate --genomeDir .\genome_index --genomeFastaFiles .\reference.fa.gz --sjdbGTFfile .\annotation.gtf.gz

Wrapper options:
  -StarExe <path>   Path to STAR.exe. Defaults to STAR.exe next to this script.
  -TempDir <path>   Directory under which temporary files are created.
  -KeepTemp         Keep temporary files after STAR exits.

Do not pass --readFilesCommand to this wrapper.
"@
}

function Resolve-StarExecutable {
    param([string]$Path)
    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf) -and [System.IO.Path]::GetFileName($Path) -eq "STAR.exe") {
        foreach ($candidate in @("win_x86_64\STAR.exe", "dist\STAR.exe")) {
            $candidatePath = Join-Path $script:ScriptDir $candidate
            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                $resolved = [System.IO.Path]::GetFullPath($candidatePath)
                break
            }
        }
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "STAR executable was not found: $resolved" }
    return $resolved
}

function New-StarTempDirectory {
    param([string]$Parent)
    if ([string]::IsNullOrWhiteSpace($Parent)) { $Parent = (Get-Location).Path }
    $parentFull = [System.IO.Path]::GetFullPath($Parent)
    New-Item -ItemType Directory -Path $parentFull -Force | Out-Null
    $name = "star-win-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
    $path = Join-Path $parentFull $name
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Ensure-StarTempDirectory {
    if ($null -eq $script:tempWorkDir) {
        $script:tempWorkDir = New-StarTempDirectory -Parent $TempDir
        Write-Info "Temporary directory: $script:tempWorkDir"
    }
    return $script:tempWorkDir
}

function New-StarTempFilePath {
    param([string]$Prefix, [string]$Name)
    $tempDir = Ensure-StarTempDirectory
    $script:tempFileCount++
    $safeName = [System.IO.Path]::GetFileName($Name)
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "input" }
    return (Join-Path $tempDir ("{0}_{1}_{2}" -f $Prefix, $script:tempFileCount, $safeName))
}

function Test-StarOption { param([string]$Value) return $Value.StartsWith("--", [System.StringComparison]::Ordinal) }

function Find-StarOptionIndex {
    param([string[]]$Arguments, [string]$OptionName)
    for ($i = 0; $i -lt $Arguments.Count; $i++) { if ($Arguments[$i] -eq $OptionName) { return $i } }
    return -1
}

function Get-StarOptionSingleValue {
    param([string[]]$Arguments, [string]$OptionName, [string]$DefaultValue)
    $index = Find-StarOptionIndex -Arguments $Arguments -OptionName $OptionName
    if ($index -lt 0) { return $DefaultValue }
    $valueIndex = $index + 1
    if ($valueIndex -ge $Arguments.Count -or (Test-StarOption $Arguments[$valueIndex])) { throw "$OptionName was found, but no value was provided." }
    return $Arguments[$valueIndex]
}

function Remove-StarOptionWithValue {
    param([string[]]$Arguments, [string[]]$OptionNames)
    $result = New-Object System.Collections.Generic.List[string]
    $index = 0
    while ($index -lt $Arguments.Count) {
        if ($OptionNames -contains $Arguments[$index]) {
            $index++
            if ($index -lt $Arguments.Count -and -not (Test-StarOption $Arguments[$index])) { $index++ }
            continue
        }
        $result.Add($Arguments[$index])
        $index++
    }
    return [string[]]$result.ToArray()
}

function Resolve-InputFilePath {
    param([string]$Path, [string]$ReadFilesPrefix)
    $effectivePath = $Path
    if (-not [string]::IsNullOrWhiteSpace($ReadFilesPrefix) -and $ReadFilesPrefix -ne "-") { $effectivePath = $ReadFilesPrefix + $Path }
    $resolved = [System.IO.Path]::GetFullPath($effectivePath)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Input file was not found: $resolved" }
    return $resolved
}

function Copy-StreamToStream {
    param([System.IO.Stream]$SourceStream, [System.IO.Stream]$DestinationStream)

    $buffer = New-Object byte[] 1048576
    $bytesWritten = [int64]0
    $lastByte = -1

    while (($bytesRead = $SourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $DestinationStream.Write($buffer, 0, $bytesRead)
        $bytesWritten += $bytesRead
        $lastByte = [int]$buffer[$bytesRead - 1]
    }

    return [pscustomobject]@{ BytesWritten = $bytesWritten; LastByte = $lastByte }
}

function New-GZipTestMemberBytes {
    param([byte[]]$Bytes)

    $memory = [System.IO.MemoryStream]::new()
    try {
        $gzip = [System.IO.Compression.GZipStream]::new($memory, [System.IO.Compression.CompressionMode]::Compress, $true)
        try { $gzip.Write($Bytes, 0, $Bytes.Length) } finally { $gzip.Dispose() }
        return $memory.ToArray()
    } finally {
        $memory.Dispose()
    }
}

function Test-GZipStreamMultiMemberSupport {
    try {
        $member1 = New-GZipTestMemberBytes -Bytes ([System.Text.Encoding]::ASCII.GetBytes("A`n"))
        $member2 = New-GZipTestMemberBytes -Bytes ([System.Text.Encoding]::ASCII.GetBytes("B`n"))
        $combined = [System.Array]::CreateInstance([byte], $member1.Length + $member2.Length)
        [System.Array]::Copy($member1, 0, $combined, 0, $member1.Length)
        [System.Array]::Copy($member2, 0, $combined, $member1.Length, $member2.Length)

        $source = [System.IO.MemoryStream]::new([byte[]]$combined)
        try {
            $gzip = [System.IO.Compression.GZipStream]::new($source, [System.IO.Compression.CompressionMode]::Decompress)
            try {
                $destination = [System.IO.MemoryStream]::new()
                try {
                    $null = Copy-StreamToStream -SourceStream $gzip -DestinationStream $destination
                    $text = [System.Text.Encoding]::ASCII.GetString($destination.ToArray())
                    return ($text -eq "A`nB`n")
                } finally {
                    $destination.Dispose()
                }
            } finally {
                $gzip.Dispose()
            }
        } finally {
            $source.Dispose()
        }
    } catch {
        return $false
    }
}

function Assert-GZipStreamMultiMemberSupport {
    if (-not $script:gzipMultiMemberChecked) {
        $script:gzipMultiMemberSupported = Test-GZipStreamMultiMemberSupport
        $script:gzipMultiMemberChecked = $true
    }

    if (-not $script:gzipMultiMemberSupported) {
        throw "This PowerShell/.NET runtime cannot safely decompress multi-member gzip files. Install PowerShell 7+ and run this wrapper with pwsh, or decompress inputs before running STAR."
    }
}

function Copy-InputFileToStream {
    param([string]$SourcePath, [System.IO.Stream]$DestinationStream)
    $source = [System.IO.File]::OpenRead($SourcePath)
    try {
        if ($SourcePath.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)) {
            Assert-GZipStreamMultiMemberSupport
            $gzip = [System.IO.Compression.GZipStream]::new($source, [System.IO.Compression.CompressionMode]::Decompress)
            try { return (Copy-StreamToStream -SourceStream $gzip -DestinationStream $DestinationStream) } finally { $gzip.Dispose() }
        } else {
            return (Copy-StreamToStream -SourceStream $source -DestinationStream $DestinationStream)
        }
    } finally {
        $source.Dispose()
    }
}

function Expand-GzipFile {
    param([string]$SourcePath, [string]$DestinationPath)
    $destination = [System.IO.File]::Create($DestinationPath)
    try { $null = Copy-InputFileToStream -SourcePath $SourcePath -DestinationStream $destination } finally { $destination.Dispose() }
}

function Split-StarCommaList {
    param([string]$Argument)
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($part in $Argument.Split([char[]]@(','), [System.StringSplitOptions]::None)) {
        $parts.Add($part)
    }
    if ($parts.Count -gt 1 -and $parts[$parts.Count - 1] -eq "") { $parts.RemoveAt($parts.Count - 1) }
    foreach ($part in $parts) {
        if ([string]::IsNullOrWhiteSpace($part)) { throw "Empty file name found in comma-separated input list: $Argument" }
    }
    return [string[]]$parts.ToArray()
}

function Convert-GzipArgument {
    param([string]$Argument, [string]$OptionName)
    if (-not $Argument.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)) { return $Argument }

    $sourcePath = [System.IO.Path]::GetFullPath($Argument)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Input file was not found: $sourcePath" }

    $sourceName = [System.IO.Path]::GetFileName($sourcePath)
    $outputName = if ($sourceName.Length -gt 3) { $sourceName.Substring(0, $sourceName.Length - 3) } else { "input" }
    $prefix = switch ($OptionName) {
        "--genomeFastaFiles" { "genome" }
        "--sjdbGTFfile" { "gtf" }
        default { "input" }
    }
    $destinationPath = New-StarTempFilePath -Prefix $prefix -Name $outputName
    $script:decompressedCount++

    Write-Info "Decompressing $sourceName for $OptionName"
    Expand-GzipFile -SourcePath $sourcePath -DestinationPath $destinationPath
    return $destinationPath
}

function Join-InputFiles {
    param([string[]]$InputPaths, [string]$OutputPrefix, [string]$OutputName)

    if ($InputPaths.Count -eq 0) { throw "No input files were provided for concatenation." }
    $destinationPath = New-StarTempFilePath -Prefix $OutputPrefix -Name $OutputName
    $destination = [System.IO.File]::Create($destinationPath)
    try {
        $insertNewlineBeforeNextFile = $false
        foreach ($inputPath in $InputPaths) {
            $inputName = [System.IO.Path]::GetFileName($inputPath)
            if ($inputPath.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)) { $script:decompressedCount++ }
            if ($insertNewlineBeforeNextFile) { $destination.WriteByte(10) }
            Write-Info "Adding $inputName to $([System.IO.Path]::GetFileName($destinationPath))"
            $copyResult = Copy-InputFileToStream -SourcePath $inputPath -DestinationStream $destination
            $insertNewlineBeforeNextFile = ($copyResult.BytesWritten -gt 0 -and $copyResult.LastByte -ne 10)
        }
    } finally {
        $destination.Dispose()
    }

    $script:concatenatedGroupCount++
    $script:concatenatedInputCount += $InputPaths.Count
    return $destinationPath
}

function Convert-OneReadFile {
    param([string]$Path, [string]$ReadFilesPrefix, [string]$OutputPrefix)

    if ($Path -eq "-") { return $Path }
    $sourcePath = Resolve-InputFilePath -Path $Path -ReadFilesPrefix $ReadFilesPrefix
    if ($sourcePath.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)) {
        $sourceName = [System.IO.Path]::GetFileName($sourcePath)
        $outputName = if ($sourceName.Length -gt 3) { $sourceName.Substring(0, $sourceName.Length - 3) } else { "read.fastq" }
        $destinationPath = New-StarTempFilePath -Prefix $OutputPrefix -Name $outputName
        $script:decompressedCount++
        Write-Info "Decompressing $sourceName for --readFilesIn"
        Expand-GzipFile -SourcePath $sourcePath -DestinationPath $destinationPath
        return $destinationPath
    }
    if (-not [string]::IsNullOrWhiteSpace($ReadFilesPrefix) -and $ReadFilesPrefix -ne "-") { return $sourcePath }
    return $Path
}

function Convert-ReadFilesInArgument {
    param([string]$Argument, [string]$ReadFilesPrefix, [int]$MateIndex)

    $parts = @(Split-StarCommaList -Argument $Argument)
    if ($parts.Count -eq 1) {
        return (Convert-OneReadFile -Path $parts[0] -ReadFilesPrefix $ReadFilesPrefix -OutputPrefix ("read{0}" -f $MateIndex))
    }

    $resolvedParts = New-Object System.Collections.Generic.List[string]
    foreach ($part in $parts) {
        if ($part -eq "-") { throw "STAR-win cannot concatenate standard input entries in --readFilesIn." }
        $resolvedParts.Add((Resolve-InputFilePath -Path $part -ReadFilesPrefix $ReadFilesPrefix))
    }

    $script:readFilesInWasConcatenated = $true
    $outputName = "read{0}.fastq" -f $MateIndex
    return (Join-InputFiles -InputPaths ([string[]]$resolvedParts.ToArray()) -OutputPrefix ("read{0}" -f $MateIndex) -OutputName $outputName)
}

function Convert-ReadFilesInArguments {
    param([string[]]$ReadArguments, [string]$ReadFilesPrefix)

    $readArgArray = @($ReadArguments)
    if ($readArgArray.Count -eq 0) { throw "--readFilesIn was found, but no input files were provided." }

    $splitByMate = New-Object System.Collections.Generic.List[object]
    foreach ($argument in $readArgArray) { $splitByMate.Add([string[]]@(Split-StarCommaList -Argument $argument)) }

    $expectedCount = ([string[]]$splitByMate[0]).Length
    for ($i = 1; $i -lt $splitByMate.Count; $i++) {
        $count = ([string[]]$splitByMate[$i]).Length
        if ($count -ne $expectedCount) {
            throw "The number of comma-separated input files must be the same for each mate. Mate 1 has $expectedCount file(s), mate $($i + 1) has $count file(s)."
        }
    }

    $converted = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $readArgArray.Count; $i++) {
        $converted.Add((Convert-ReadFilesInArgument -Argument $readArgArray[$i] -ReadFilesPrefix $ReadFilesPrefix -MateIndex ($i + 1)))
    }
    return [string[]]$converted.ToArray()
}

function Get-StarOptionValues {
    param([string[]]$Arguments, [string]$OptionName)

    $values = New-Object System.Collections.Generic.List[string]
    $index = Find-StarOptionIndex -Arguments $Arguments -OptionName $OptionName
    if ($index -lt 0) { return [string[]]$values.ToArray() }

    $index++
    while ($index -lt $Arguments.Count -and -not (Test-StarOption $Arguments[$index])) {
        $values.Add($Arguments[$index])
        $index++
    }
    return [string[]]$values.ToArray()
}

function Test-MultipleReadGroupsInCommandLine {
    param([string[]]$Arguments)

    $values = @(Get-StarOptionValues -Arguments $Arguments -OptionName "--outSAMattrRGline")
    foreach ($value in $values) {
        if ($value -eq ",") { return $true }
    }
    return $false
}

$exitCode = 1
$script:tempWorkDir = $null
$script:tempFileCount = 0
$script:decompressedCount = 0
$script:concatenatedGroupCount = 0
$script:concatenatedInputCount = 0
$script:readFilesInWasConcatenated = $false
$script:gzipMultiMemberChecked = $false
$script:gzipMultiMemberSupported = $false

try {
    if ($null -eq $StarArgs -or $StarArgs.Count -eq 0) {
        Write-Usage
        exit 64
    }

    if ((Find-StarOptionIndex -Arguments $StarArgs -OptionName "--readFilesCommand") -ge 0) {
        throw "Do not use --readFilesCommand with this Windows wrapper. Pass .gz files directly to --genomeFastaFiles, --sjdbGTFfile, or --readFilesIn instead."
    }

    $starPath = Resolve-StarExecutable -Path $StarExe
    $workingArgs = [string[]]$StarArgs
    if ((Find-StarOptionIndex -Arguments $workingArgs -OptionName "--readFilesManifest") -ge 0) {
        throw "STAR-win does not support --readFilesManifest. Use --readFilesIn instead; for split FASTQ files, pass comma-separated lists to --readFilesIn."
    }

    $readFilesPrefix = Get-StarOptionSingleValue -Arguments $workingArgs -OptionName "--readFilesPrefix" -DefaultValue "-"
    $readFilesInIndex = Find-StarOptionIndex -Arguments $workingArgs -OptionName "--readFilesIn"
    if ($readFilesInIndex -ge 0 -and $readFilesPrefix -ne "-") {
        $workingArgs = Remove-StarOptionWithValue -Arguments $workingArgs -OptionNames @("--readFilesPrefix")
    }

    $fileOptions = @("--genomeFastaFiles", "--sjdbGTFfile", "--readFilesIn")
    $patchedArgs = New-Object System.Collections.Generic.List[string]
    $index = 0

    while ($index -lt $workingArgs.Count) {
        $arg = $workingArgs[$index]
        $patchedArgs.Add($arg)

        if ($fileOptions -contains $arg) {
            $index++
            if ($index -ge $workingArgs.Count -or (Test-StarOption $workingArgs[$index])) { throw "$arg was found, but no input files were provided." }

            if ($arg -eq "--readFilesIn") {
                $readArgs = New-Object System.Collections.Generic.List[string]
                while ($index -lt $workingArgs.Count -and -not (Test-StarOption $workingArgs[$index])) {
                    $readArgs.Add($workingArgs[$index])
                    $index++
                }
                $convertedReadArgs = Convert-ReadFilesInArguments -ReadArguments ([string[]]$readArgs.ToArray()) -ReadFilesPrefix $readFilesPrefix
                foreach ($convertedArg in $convertedReadArgs) { $patchedArgs.Add($convertedArg) }
                continue
            }

            while ($index -lt $workingArgs.Count -and -not (Test-StarOption $workingArgs[$index])) {
                $patchedArgs.Add((Convert-GzipArgument -Argument $workingArgs[$index] -OptionName $arg))
                $index++
            }
            continue
        }

        $index++
    }

    $patchedArgArray = [string[]]$patchedArgs.ToArray()
    if ($script:readFilesInWasConcatenated -and (Test-MultipleReadGroupsInCommandLine -Arguments $patchedArgArray)) {
        throw "STAR-win cannot preserve multiple --outSAMattrRGline entries after concatenating comma-separated --readFilesIn files. Use one read group, or use a POSIX/Linux STAR build for per-file read groups."
    }

    if ($script:concatenatedGroupCount -gt 0) { Write-Info "Created $script:concatenatedGroupCount concatenated read file(s) from $script:concatenatedInputCount input file(s)." }
    if ($script:decompressedCount -gt 0) { Write-Info "Decompressed $script:decompressedCount gzipped input file(s)." }
    if ($script:tempFileCount -eq 0) { Write-Info "No temporary input files were needed. Running STAR with the original files." }

    & $starPath @patchedArgArray
    $exitCode = $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("[STAR-win] ERROR: " + $_.Exception.Message)
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
