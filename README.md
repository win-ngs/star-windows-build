# STAR Windows Build

Community Windows build of the STAR RNA-seq aligner.

This is **not an official STAR release**.  
Official STAR repository: https://github.com/alexdobin/STAR

This repository provides Windows executables for:

- `STAR.exe`
- `STARlong.exe`

built using **MSYS2-MSYS**.

## Download prebuilt binaries

Prebuilt Windows binaries are available from the **Releases** page of this repository.

Download the latest release archive, for example:

```text
STAR-windows-x86_64-msys.zip
```

After extracting the archive, you should see:

```text
STAR.exe
STARlong.exe
msys-2.0.dll
msys-z.dll
msys-gcc_s-seh-1.dll
msys-gomp-1.dll
msys-stdc++-6.dll
THIRD_PARTY_NOTICES.txt
```

Keep the DLL files in the same folder as `STAR.exe` and `STARlong.exe`.

Check the version with:

```bash
./STAR.exe --version
./STARlong.exe --version
```

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

License information for these bundled DLLs is provided in:

```text
THIRD_PARTY_NOTICES.txt
```

## Build from source

This section is for users who want to build `STAR.exe` and `STARlong.exe` themselves.

Open **MSYS2 MSYS**.

Update MSYS2:

```bash
pacman -Syu
```

If MSYS2 asks you to close the terminal, close it, reopen **MSYS2 MSYS**, and run again:

```bash
pacman -Syu
```

Install the required build tools:

```bash
pacman -S --needed git make gcc zlib-devel vim
```

`vim` provides `xxd`, which is required by the STAR Makefile.

Build both STAR and STARlong:

```bash
make
```

The executables will be copied to:

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
5. builds `STAR` and `STARlong` separately
6. copies the final executables to `win_x86_64/`

Building `STAR` and `STARlong` in separate directories avoids mixing object files compiled with different build options.

## License

STAR is distributed under the MIT License.

This repository preserves the upstream STAR source and license.  
See the official STAR repository for the original source code and license information:

https://github.com/alexdobin/STAR

The release archive also includes MSYS2-MSYS runtime DLLs.  
See `THIRD_PARTY_NOTICES.txt` for third-party package and license information.

## Disclaimer

This is a community build.

It is not provided, reviewed, or endorsed by the official STAR developers.  
Please verify the binaries and results in your own analysis environment.