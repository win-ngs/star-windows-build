# DLL License Information

This directory collects license information for DLL files bundled in the
release archive. Executable license information remains in the repository root
`LICENSE.md`.

| DLL files | MSYS2 package | Version | Upstream | License |
| --- | --- | --- | --- | --- |
| `msys-2.0.dll` | `msys2-runtime` | 3.6.9-1 | https://www.cygwin.com/ | GPL |
| `msys-z.dll` | `zlib` | 1.3.2-1 | https://www.zlib.net/ | custom zlib license |
| `msys-gcc_s-seh-1.dll`, `msys-gomp-1.dll`, `msys-stdc++-6.dll` | `gcc-libs` | 15.2.0-1 | https://gcc.gnu.org/ | GPL-3.0-or-later, GPL-2.0-or-later, LGPL-2.1-or-later, LGPL-3.0-or-later, GCC-exception-3.1, and GFDL-1.3-or-later components |

Package license files copied from `C:\msys64\usr\share\licenses` are stored in
package-named subdirectories when the package provides them. The local
`msys2-runtime` package metadata lists GPL but does not provide a separate file
under `C:\msys64\usr\share\licenses\msys2-runtime` in this installation.
