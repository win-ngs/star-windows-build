![STAR RNA-seq aligner for Windows](assets/banner.jpg)

## STAR RNA-seq aligner for Windows: Community-built Windows binaries

This repository provides a STAR build that runs natively on Windows.
The release archive includes pre-compiled STAR binaries that users can use without building from source.


### [Click here to download](https://github.com/win-ngs/star-windows-build/releases/download/v2.7.11b-windows/win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi)

This is **not an official STAR release**.  
Official STAR repository: https://github.com/alexdobin/STAR

This build is based on upstream STAR 2.7.11b.

This repository provides Windows executables for:

- `STAR.exe` for standard short-read alignment
- `STARlong.exe` for long-read alignment

built using [MSYS2 MSYS](https://www.msys2.org/docs/environments/).

## Downloading STAR for Windows

Prebuilt Windows binaries are available from the
[Releases](https://github.com/win-ngs/star-windows-build/releases) page
of this repository.

Recommended installer:

```text
win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi
```

Download the MSI file and double-click it to install STAR. The installer places
STAR under `C:\Program Files\WinNGS\STAR` and adds `C:\Program Files\WinNGS\bin`
to PATH. Open a new PowerShell window after installation, then run `STAR` or
`STARlong`.

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
  STAR-gz.ps1
  STARlong-gz.ps1
  LICENSE.md
  THIRD_PARTY_NOTICES.txt
  LICENSES/
```

Keep the DLL files in the same folder as `STAR.exe` and `STARlong.exe`.

## Running STAR from PowerShell

STAR is a command-line program; the examples below show a minimal Windows workflow.
For detailed usage and options, refer to the
[official STAR documentation](https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf).

Open PowerShell, then move into the extracted folder before running STAR:

```powershell
# Replace this path with the folder where you extracted the ZIP file.
# For example:
cd C:\Users\your_name\Downloads\star-2.7.11b-windows-x86_64-msys
```

Example short-read run:

```powershell
# Generate a genome index.
.\STAR.exe --runThreadN 8 `
  --runMode genomeGenerate `
  --genomeDir .\genome_index `
  --genomeFastaFiles .\reference.fa `
  --sjdbGTFfile .\annotation.gtf `
  --sjdbOverhang 100

# Map paired-end short reads.
.\STAR.exe --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\reads_R1.fastq .\reads_R2.fastq `
  --outFileNamePrefix .\star_output\
```

## Working with gzipped input files

The STAR binaries in this Windows release cannot read gzip-compressed input
files directly; see [Limitations](#limitations). If your genome FASTA,
annotation GTF, or FASTQ files are gzipped, use the included PowerShell wrapper
scripts: `STAR-gz.ps1` for `STAR.exe`, or `STARlong-gz.ps1` for
`STARlong.exe`. These wrappers temporarily decompress `.gz` files passed to
`--genomeFastaFiles`, `--sjdbGTFfile`, or `--readFilesIn`, run STAR with the
decompressed files, and remove the temporary files after STAR exits.
Non-gzipped files can be used alongside gzipped files; they are passed to STAR
unchanged.

Use one FASTQ file per mate with these wrappers. If your reads are split across
lanes or chunks, combine them before running STAR; see
[Limitations](#limitations).

```powershell
# Generate a genome index from gzipped and uncompressed input files.
.\STAR-gz.ps1 --runThreadN 8 `
  --runMode genomeGenerate `
  --genomeDir .\genome_index `
  --genomeFastaFiles .\reference.fa.gz .\extra_reference.fa `
  --sjdbGTFfile .\annotation.gtf.gz `
  --sjdbOverhang 100
```

```powershell
# Map paired-end gzipped short reads.
.\STAR-gz.ps1 --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\reads_R1.fastq.gz .\reads_R2.fastq.gz `
  --outFileNamePrefix .\star_output\
```

Temporary decompressed files can be large. To place them on a specific drive,
use `-TempDir`:

```powershell
.\STAR-gz.ps1 -TempDir D:\star_tmp --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\reads_R1.fastq.gz .\reads_R2.fastq.gz `
  --outFileNamePrefix .\star_output\
```

For long-read alignment, use `STARlong-gz.ps1` in the same way:

```powershell
.\STARlong-gz.ps1 --runThreadN 8 `
  --genomeDir .\genome_index `
  --readFilesIn .\long_reads.fastq.gz `
  --outFileNamePrefix .\starlong_output\
```

## Performance

The following timings are from our validation environment and are provided as a
rough reference only.

Validation environment:

- CPU: Intel Core i9-12900K (16 cores, 24 threads)
- Memory: 64GB DDR4
- Storage: 2TB SSD
- OS: Windows 11 Pro

Test data:

- Genome FASTA: `GRCh38.primary_assembly.genome.fa`
- Annotation GTF: `gencode.v49.primary_assembly.annotation.gtf`
- Mapping input: `SRR33370091` (~20 million reads, 150 bp paired-end)

Observed runtimes:

- Genome index generation: **31 min 31 sec**.
- Mapping, including sorted-by-coordinate BAM output: **3 min 4 sec (426.12 million reads/hour)**

## Limitations

Do not use `--readFilesCommand` with this Windows release.

STAR implements `--readFilesCommand` by creating POSIX FIFO files and temporary
shell scripts, such as `gzip -cd "reads.fastq.gz" > FIFO`. This depends on
Unix-style shell behavior and FIFO support, which are not reliable in the
MSYS2-MSYS Windows build.

Also avoid giving multiple FASTQ files for one mate as a comma-separated list,
such as `--readFilesIn R1_L001.fastq,R1_L002.fastq R2_L001.fastq,R2_L002.fastq`.
When multiple files are provided this way, STAR internally uses `cat`, which
goes through the same FIFO and temporary shell script path. If reads are split
across lanes or chunks, combine them into one R1 file and one R2 file before
running STAR.

For gzipped input files, use `STAR-gz.ps1` or `STARlong-gz.ps1` instead of
`--readFilesCommand`. These wrapper scripts avoid STAR's `--readFilesCommand`
path by temporarily decompressing gzipped input files before running `STAR.exe`
or `STARlong.exe`.

In addition, `STAR-gz.ps1` and `STARlong-gz.ps1` can accept gzipped genome
FASTA and annotation GTF files for `--genomeFastaFiles` and `--sjdbGTFfile`.
This is not supported directly by the original STAR command-line options.

## Runtime DLLs included in the release archive

The release archive includes the following MSYS2-MSYS runtime DLLs:

```text
msys-2.0.dll
msys-z.dll
msys-gcc_s-seh-1.dll
msys-gomp-1.dll
msys-stdc++-6.dll
```

These DLLs are required to run the MSYS2-MSYS build of `STAR.exe` and `STARlong.exe` outside the MSYS2 environment.

The DLLs are redistributed unmodified from MSYS2 packages.

License information for these bundled DLLs is summarized in
[THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt), with package-level details
in [LICENSES/DLL_LICENSES.md](LICENSES/DLL_LICENSES.md).

## Build from source

This section is for users who want to build `STAR.exe` and `STARlong.exe` themselves.

Install [**MSYS2**](https://www.msys2.org/), then open the **MSYS2-MSYS** terminal by selecting **MSYS2-MSYS** from the Windows Start menu.

Use the **MSYS2-MSYS** environment, **not MSYS2-UCRT64** or any other
MSYS2 environment.

Update MSYS2:

```bash
pacman -Syu
```

If MSYS2 asks you to close the terminal, close it, reopen **MSYS2-MSYS**, and run again:

```bash
pacman -Syu
```

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
dist/
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
5. builds `STAR` and `STARlong` separately
6. copies the final executables to `dist/`

Building `STAR` and `STARlong` in separate directories avoids mixing object files compiled with different build options.

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
