# STAR MSI installer

This directory contains WiX authoring for the STAR MSI installer.
It uses the WiX standard minimal UI with fixed `en-US` localization and shows
`Installation completed successfully.` on the final dialog after a successful
first-time install.

The MSI installs files under:

```text
C:\Program Files\WinNGS-STAR\
  STAR.exe
  STARlong.exe
  STAR-win.cmd
  STARlong-win.cmd
  scripts\
    STAR-win.ps1
    STARlong-win.ps1
  MSYS2 runtime DLLs
  LICENSE.md
  THIRD_PARTY_NOTICES.txt
  LICENSES\
```

`C:\Program Files\WinNGS-STAR` is added to the system PATH by the MSI. This
standalone installer owns only the STAR install directory and its own PATH
entry, so uninstalling STAR does not affect other WinNGS tools.

Build the ZIP/package folder first, then build the MSI:

```powershell
wix extension add -g WixToolset.UI.wixext/7.0.0
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Build-StarMsi.ps1
```

WiX Toolset v7 requires accepting the WiX OSMF EULA before building. If it has
not already been accepted:

```powershell
wix eula accept wix7
```

or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Build-StarMsi.ps1 -AcceptWixEula
```

The output is:

```text
dist\win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi
```

The MSI `ProductVersion` is `2.7.11`, because Windows Installer versions are
numeric. The release asset name keeps the upstream label `2.7.11b`.

Validate the MSI without installing:

```powershell
wix msi validate .\dist\win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi
```

Record the MSI SHA256 and ProductCode before updating winget manifests:

```powershell
Get-FileHash -Algorithm SHA256 .\dist\win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi
$out = "C:\tmp\win-ngs-STAR-msi.wxs"
wix msi decompile .\dist\win-ngs-STAR-2.7.11b-windows-x86_64-msys.msi -o $out
rg -n "ProductCode|UpgradeCode|Environment|WinNGS-STAR" $out
```

For winget, this MSI must use `InstallerType: msi` even though it is authored
with WiX. Update `InstallerSha256`, `ProductCode`, and
`AppsAndFeaturesEntries` in the winget installer manifest after each MSI rebuild.

Local winget validation:

```powershell
winget validate --manifest .\winget\manifests\w\WinNGS\STAR\2.7.11b
winget install --manifest .\winget\manifests\w\WinNGS\STAR\2.7.11b `
  --silent `
  --accept-package-agreements `
  --accept-source-agreements `
  --verbose-logs `
  --log C:\tmp\winngs-star-winget-install.log
```

On some winget versions, local manifest install can stop after hash validation
while the diagnostic log ends at `Started applying motw using IAttachmentExecute`.
For local verification only, unblock the cached MSI and rerun the same command:

```powershell
$sha = "<installer-sha256-lowercase>"
$cache = "$env:TEMP\WinGet\WinNGS.STAR.2.7.11b\$sha"
Unblock-File -LiteralPath $cache
```

Install testing modifies `C:\Program Files\WinNGS-STAR` and the system PATH, so
do that only on a test machine or after taking a restore point.
