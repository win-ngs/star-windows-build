![STAR RNA-seq aligner for Windows](assets/banner.jpg)

## STAR RNA-seq aligner for Windows: Community-built Windows binaries

This repository provides a STAR build that runs natively on Windows.
The release archive includes pre-compiled STAR binaries that users can use without building from source.

This is **not an official STAR release**.  
Official STAR repository: https://github.com/alexdobin/STAR

This build is based on upstream STAR 2.7.11b.

This repository provides Windows executables for:

- `STAR.exe` for standard short-read alignment
- `STARlong.exe` for long-read alignment

built using [MSYS2 MSYS](https://www.msys2.org/docs/environments/).

### Contents

**User guide**

- [Installation](#installation)
- [Running STAR from PowerShell](#running-star-from-powershell)
- [Gzipped and split input files](#gzipped-and-split-input-files)
- [Supported and unsupported inputs](#supported-and-unsupported-inputs)
- [Performance](#performance)

**Technical details (for developers)**

- [Why gzipped and split inputs need the wrappers](#why-gzipped-and-split-inputs-need-the-wrappers)
- [Building from source](#building-from-source)
- [MSYS2-MSYS build notes](#msys2-msys-build-notes)
- [What the Makefile does](#what-the-makefile-does)
- [Runtime DLLs in the release archive](#runtime-dlls-in-the-release-archive)

[License](#license) · [Disclaimer](#disclaimer)

---

# User guide

## Installation

The recommended way to install STAR is Windows Package Manager (`winget`).
Open PowerShell and run:

```powershell
winget install WinNGS.STAR
```

The installer places STAR under `C:\Program Files\WinNGS-STAR` and adds that
folder to PATH. Open a new PowerShell window after installation, then run
`STAR` or `STARlong`.

Prebuilt MSI and ZIP packages are also available from the
[Releases](https://github.com/win-ngs/star-windows-build/releases) page of this
repository.

If `winget` is not available on your system, download the MSI file from the
Releases page and double-click it to install STAR.

<table>
  <tr>
    <td>
      <strong>Windows SmartScreen note</strong><br>
      If Windows shows a blue warning screen titled "Windows protected your PC",
      click the <strong>"More info"</strong> link, then click the
      <strong>"Run anyway"</strong> button to continue the installation.
    </td>
  </tr>
</table>

### Portable ZIP package

If the MSI cannot be installed on your system, or if you prefer not to use an
installer, download the portable ZIP package instead:

```text
win-ngs-STAR-2.7.11b-windows-x86_64-msys.zip
```

After extracting the ZIP archive, you should see:

```text
star-2.7.11b-windows-x86_64-msys/
  STAR.exe
  STARlong.exe
  msys-2.0.dll
  msys-z.dll
  msys-gcc_s-seh-1.dll
  msys-gomp-1.dll
  msys-stdc++-6.dll
  STAR-win.cmd
  STARlong-win.cmd
  scripts/
    STAR-win.ps1
    STARlong-win.ps1
  LICENSE.md
  THIRD_PARTY_NOTICES.txt
  LICENSES/
```

Keep the DLL files in the same folder as `STAR.exe` and `STARlong.exe`.

## Running STAR from PowerShell

STAR is a command-line program; the examples below show a minimal Windows workflow.
For detailed usage and options, refer to the
[official STAR documentation](https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf).

If you installed STAR with `winget` or the MSI installer, open a new PowerShell window.
The `STAR` and `STARlong` commands are available from any working directory:

```powershell
STAR --version
STARlong --version
```

If you are using the portable ZIP package instead, open PowerShell, move into
the extracted folder, and replace `STAR` with `.\STAR.exe` and `STARlong` with
`.\STARlong.exe` in the examples below.

Example short-read run:

```powershell
# Generate a genome index.
STAR --runThreadN 8 `
  --runMode genomeGenerate `
  --genomeDir .\genome_index `
  --genomeFastaFiles .\reference.fa `
  --sjdbGTFfile .\annotation.gtf `
  --sjdbOverhang 100

# Map paired-end short reads.
STAR --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\reads_R1.fastq .\reads_R2.fastq `
  --outFileNamePrefix .\star_output\
```

## Gzipped and split input files

For gzipped or split FASTQ input, do **not** call `STAR.exe` or `STARlong.exe`
directly. Use the included PowerShell wrapper commands instead:

- `STAR-win` in place of `STAR`
- `STARlong-win` in place of `STARlong`

With the portable ZIP package, run `.\STAR-win.cmd` or `.\STARlong-win.cmd`
from the extracted folder.

The wrappers accept gzipped files for `--genomeFastaFiles`, `--sjdbGTFfile`, and
`--readFilesIn`, and gzipped and uncompressed files can be mixed freely. For
FASTQ split across lanes or chunks, pass comma-separated `--readFilesIn` lists;
the wrapper concatenates the files of each mate, in the listed order, into one
temporary FASTQ file. The wrappers do not require an external `gzip.exe`.

For exactly which inputs are accepted (and which are not), see
[Supported and unsupported inputs](#supported-and-unsupported-inputs).

```powershell
# Generate a genome index from gzipped and uncompressed input files.
STAR-win --runThreadN 8 `
  --runMode genomeGenerate `
  --genomeDir .\genome_index `
  --genomeFastaFiles .\reference.fa.gz .\extra_reference.fa `
  --sjdbGTFfile .\annotation.gtf.gz `
  --sjdbOverhang 100
```

```powershell
# Map paired-end gzipped short reads.
STAR-win --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\reads_R1.fastq.gz .\reads_R2.fastq.gz `
  --outFileNamePrefix .\star_output\
```

```powershell
# Map paired-end reads split across lanes.
# Files for each mate are concatenated in the listed order.
STAR-win --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\R1_L001.fastq.gz,.\R1_L002.fastq.gz .\R2_L001.fastq.gz,.\R2_L002.fastq.gz `
  --outFileNamePrefix .\star_output\
```

For long-read alignment, use `STARlong-win` in the same way:

```powershell
STARlong-win --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\long_reads.fastq.gz `
  --outFileNamePrefix .\starlong_output\
```

### Choosing a temporary directory

The wrappers decompress and concatenate input into temporary files, which can be
large. By default these are created in the current directory. Use `-TempDir` to
place them on a drive with enough free space for the uncompressed, concatenated
input:

```powershell
STAR-win -TempDir D:\star_tmp --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\reads_R1.fastq.gz .\reads_R2.fastq.gz `
  --outFileNamePrefix .\star_output\
```

Other wrapper options:

- `-StarExe <path>` — path to `STAR.exe`; defaults to the executable next to the wrapper.
- `-KeepTemp` — keep the temporary files after STAR exits (useful for debugging).

## Supported and unsupported inputs

These Windows binaries are intended for STAR workflows where the executable
opens ordinary input files directly. STAR's Linux path for compressed or
multi-file input relies on a Unix shell, POSIX FIFOs, and helper commands, which
are not reliable in an ordinary PowerShell session. The `STAR-win` /
`STARlong-win` wrappers fill that gap by preparing temporary files *before* STAR
runs, so STAR can stay on its direct file-reading path.

Use this table to decide how to pass each input type:

| Input / feature | `STAR` / `STARlong` directly | `STAR-win` / `STARlong-win` |
| --- | --- | --- |
| Uncompressed FASTA / GTF / FASTQ | ✅ Supported | ✅ Supported |
| Gzipped FASTA / GTF / FASTQ (`.gz`) | ❌ Not supported | ✅ Decompressed to a temp file |
| Comma-separated FASTQ per mate (`R1_L001,R1_L002`) | ❌ Not supported | ✅ Concatenated per mate |
| `--readFilesCommand` (`gzip -cd`, `zcat`, `samtools view -h`, …) | ❌ Not supported | ❌ Not needed — pass `.gz` files directly |
| `--readFilesManifest` | ❌ Not supported | ❌ Not supported — use comma-separated `--readFilesIn` |
| BAM input via `--readFilesType SAM SE/PE` (needs `samtools view -h`) | ❌ Not supported | ❌ Not supported |

Notes:

- **Do not pass `--readFilesCommand`** in ordinary PowerShell workflows. It
  triggers a POSIX FIFO and helper-command path that is unreliable outside a
  full MSYS2-MSYS terminal, and it can hang rather than fail cleanly. With the
  wrappers it is unnecessary: pass `.gz` files directly.
- **PowerShell version:** the wrappers prefer PowerShell 7+ (`pwsh`) and fall
  back to Windows PowerShell 5.1. To decompress `.gz` input they require
  PowerShell 7+; under 5.1 they refuse `.gz` input rather than risk silently
  truncating multi-member gzip files. Uncompressed input and concatenation of
  uncompressed FASTQ still work on 5.1.
- For per-file read groups, multi-row manifests, or other shell-dependent input
  paths, use a POSIX/Linux STAR build.

The reasons behind these limits are described in
[Why gzipped and split inputs need the wrappers](#why-gzipped-and-split-inputs-need-the-wrappers).

## Performance

The following timings are from our validation environment and are provided as a
rough reference only.

Validation environment:

- CPU: Intel Core i9-12900K (16 cores, 24 threads)
- Memory: 64GB DDR4
- Storage: 2TB SSD
- OS: Windows 11 Pro

Test data:

- Genome FASTA: `GRCh38.p14.genome.fa`
- Annotation GTF: `gencode.v49.primary_assembly.annotation.gtf`
- Mapping input: `SRR33370091` (~20 million reads, 150 bp paired-end)

Observed runtimes:

- Genome index generation: **50 min**.
- Mapping, including sorted-by-coordinate BAM output: **3 min 18 sec**.

---

# Technical details (for developers)

## Why gzipped and split inputs need the wrappers

The limitations above come from a single fragile code path inside STAR. This
section documents it for developers and for anyone debugging STAR behavior on
Windows.

### The helper-command path

The fragile path is controlled by `readFilesCommandString` in
`STAR/source/Parameters_readFilesInit.cpp`. STAR sets this string when
`--readFilesCommand` is provided. It also sets it to `cat` when `readFilesN > 1`,
which happens with comma-separated `--readFilesIn` and with multi-row
`--readFilesManifest`.

Once `readFilesCommandString` is non-empty,
`STAR/source/Parameters_openReadsFiles.cpp` switches from direct file reading to
a helper-command pipeline. In that path, STAR:

1. creates temporary POSIX FIFO files with `mkfifo()`
2. probes each input file with `system("ls -lL ...")`
3. writes temporary command scripts such as `readsCommand_read1`
4. writes commands into those scripts, for example `gzip -cd "reads.fastq.gz"`
   or `cat "R1_L001.fastq"`
5. marks the scripts executable with `chmod()`
6. starts them with `vfork()` and `execlp()`
7. reads the resulting stream from the FIFO

`--sysShell` can affect the generated command script shebang, but it does not
control the earlier `system("ls -lL ...")` call. Therefore it does not make the
whole helper-command pipeline reliable in ordinary PowerShell sessions.

In a full MSYS2-MSYS terminal, the required shell, FIFO implementation, and
core utilities are provided by the same MSYS2 environment, so this path can
work. In a normal PowerShell session, and in Git Bash with these MSYS2-linked
STAR binaries, the STAR process may not see a compatible `/bin/sh`, `ls`,
`gzip`, `cat`, and FIFO runtime. The result can be a hang rather than a clean
error, because STAR waits for data from a FIFO whose producer process did not
start correctly.

The wrappers avoid this entirely: they decompress and concatenate inputs into
ordinary temporary files first, so STAR sees only uncompressed, single files
per mate and stays on its direct file-reading path.

### Why `--readFilesManifest` is not implemented

- STAR opens the manifest file itself as ordinary text, so `--readFilesCommand`
  does not decompress `manifest.tsv.gz`.
- Manifest rows may point to `.fastq.gz` files, but that still depends on
  `--readFilesCommand`, which is the unsupported helper-command path here.
- Manifest rows can carry per-file read groups. STAR preserves those through
  `readFilesIndex`; pre-concatenating manifest inputs would lose that per-file
  association. For this reason, the wrappers do not implement partial manifest
  support.

### Other POSIX-dependent code paths

STAR contains additional POSIX-specific system calls outside the read-input
path. They differ a lot in how likely they are to matter, so they are split
into two groups below.

**Avoided by default settings — not a concern for normal use**

- `STAR/source/Parameters_readSAMheader.cpp` — `mkfifo()` and `system()` for
  `--readFilesType SAM SE/PE` header handling when a read command is active.
  Only reached with SAM/BAM read input, which is already unsupported (see the
  table above).
- `STAR/source/Parameters_closeReadsFiles.cpp` — `kill(SIGKILL)` to stop helper
  processes created for `readFilesCommandString`. Only runs if the
  helper-command path ran in the first place; the wrappers never start it.
- `STAR/source/htslib/cram/zfio.c` — `popen()` for gzip-based CRAM helper I/O.
  Only reached with CRAM input through htslib.
- `STAR/source/SharedMemory.cpp` — `shm_open()` and `mmap()` for `--genomeLoad`
  modes other than the default `NoSharedMemory`. Avoided as long as you keep the
  default. If shared memory is requested and fails, STAR exits with a fatal
  error whose own suggested fix is `--genomeLoad NoSharedMemory`.

**Independent caveat — can be reached in an otherwise-supported workflow**

- `STAR/source/SoloFeature_outputResults.cpp` — STARsolo calls `symlink()` to
  link an output file to `SJ.out.tab`, and a failure is **fatal**
  (`exitWithError`). This is on the normal STARsolo (`--soloType`) path and does
  **not** depend on gzip or split input, so a single-cell run can reach it even
  when every input is otherwise supported. Under the bundled MSYS2 runtime,
  `symlink()` normally succeeds by falling back to a Cygwin/MSYS-style symlink
  file and does not require Administrator rights, so STARsolo is *expected* to
  work — but **this has not been verified on Windows in this build, and the
  repository has no automated STARsolo test yet.** If you rely on STARsolo,
  test it in your own environment first.

Apart from the STARsolo caveat above, the default `--genomeLoad NoSharedMemory`
setting and ordinary direct reads of uncompressed FASTA, GTF, and FASTQ files
keep STAR off the FIFO/helper-command and shared-memory paths.

## Building from source

This section is for users who want to build `STAR.exe` and `STARlong.exe` themselves.

Install [**MSYS2**](https://www.msys2.org/), then open the **MSYS2-MSYS** terminal by selecting **MSYS2-MSYS** from the Windows Start menu.

Use the **MSYS2-MSYS** environment, **not MSYS2-UCRT64** or any other
MSYS2 environment.

Install the required build tools:

```bash
pacman -S --needed base-devel git gcc zlib-devel vim
```

`vim` provides `xxd`, which is required by the STAR Makefile.

Build both STAR and STARlong:

```bash
make
```

The build outputs will be copied to:

```text
win_x86_64/
  STAR.exe
  STARlong.exe
```

Clean build outputs:

```bash
make clean
```

## MSYS2-MSYS build notes

The upstream STAR source does not build as-is in this MSYS2-MSYS setup because of two small compatibility issues.

First, the upstream Makefile uses:

```text
-std=c++11
```

This build changes it to:

```text
-std=gnu++11
```

This keeps C++11 support while enabling GNU extensions needed in this build environment.

Second, `SharedMemory.cpp` uses:

```cpp
SHM_NORESERVE
```

This macro is normally available on Linux, but may be undefined in MSYS2-MSYS.

This build passes the following option through STAR's `CXXFLAGSextra` variable:

```text
-DSHM_NORESERVE=0
```

This is equivalent to compiling with:

```cpp
#define SHM_NORESERVE 0
```

No direct edit is made to `SharedMemory.cpp`.

## What the Makefile does

The top-level `Makefile`:

1. copies `STAR/` to `build/STAR/`
2. copies `STAR/` to `build/STARlong/`
3. changes `-std=c++11` to `-std=gnu++11` in the copied Makefiles
4. passes `-DSHM_NORESERVE=0` via `CXXFLAGSextra`
5. passes `BUILD_PLACE=WinNGS` to avoid embedding a local build path
6. builds `STAR` and `STARlong` separately
7. copies the final executables to `win_x86_64/`

Building `STAR` and `STARlong` in separate directories avoids mixing object files compiled with different build options.

## Runtime DLLs in the release archive

The release archive includes the following MSYS2-MSYS runtime DLLs:

```text
msys-2.0.dll
msys-z.dll
msys-gcc_s-seh-1.dll
msys-gomp-1.dll
msys-stdc++-6.dll
```

These DLLs are required to run the MSYS2-MSYS build of `STAR.exe` and `STARlong.exe` outside the MSYS2 environment.
Keep them in the same folder as the executables.

The DLLs are redistributed unmodified from MSYS2 packages.

License information for these bundled DLLs is summarized in
[THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt), with package-level details
in [LICENSES/DLL_LICENSES.md](LICENSES/DLL_LICENSES.md).

---

## License

STAR is distributed under the MIT License.

This repository preserves the upstream STAR source and license.  
See the official STAR repository for the original source code and license information:

https://github.com/alexdobin/STAR

The release archive also includes MSYS2-MSYS runtime DLLs.  
See [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) for third-party package and license information.
Detailed DLL license metadata is provided in
[LICENSES/DLL_LICENSES.md](LICENSES/DLL_LICENSES.md).

## Disclaimer

This is a community build.

It is not provided, reviewed, or endorsed by the official STAR developers.  
Please verify the binaries and results in your own analysis environment.
