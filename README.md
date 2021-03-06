# PCRE

#### Building PCRE for Windows

This repository contains the necessary references and instructions to build PCRE (specifically PCRE2), from scratch, on a fresh Windows installation. The default build creates both 32-bit and 64-bit executables, built with the ANYCRLF end-of-line matching and "Just-In-Time" compilation options.

## Build

#### Requirements

PowerShell v3.0+ (included with Windows 8, or later)

To install PowerShell 3.0 for Windows 7, see [MS: Installing Windows PowerShell on Windows 7 and Windows Server 2008 R2](https://technet.microsoft.com/en-us/library/hh847837.aspx?f=255&MSPPError=-2147217396#BKMK_InstallingOnWindows7andWindowsServer2008R2) [[@](https://archive.is/DYvcd)] or [How to install/configure Powershell 3.0 in Windows 7 SP1](http://www.everonit.com/techtips/techtips/how-to-installconfigure-powershell-3-0-in-windows-7-sp1/) [[@](https://archive.is/UjaUC)].

Microsoft also provides testing VMs for multiple OS/VMhost/IE combinations at [MS: Download VMs](http://dev.modern.ie/tools/vms/windows/); see [Making Internet Explorer Testing Easier with new IE VMs](http://blog.reybango.com/2013/02/04/making-internet-explorer-testing-easier-with-new-ie-vms/) [[@](https://archive.is/kwJBs)]. The downloads can be used to create VMs which are licensed and fully functional for 90 days, after which the specific instance will expire. *But the downloads can be used to recreate a new VM at any time*, offering a continually free testing environment. Either the "Edge on Win10" or the "IE11 on Win8.1" VM will work easily out-of-the-box for this build.

#### Build Procedure

Start with a fresh basic installation of Windows with PowerShell 3.0+. From a shell (either CMD or PowerShell):

1. install the CMD-friendly fork of [`scoop`](https://github.com/rivy/scoop)

    * CMD Shell &middot; `C:\>`

        ```
        powershell -command "iex (new-object net.webclient).downloadstring( 'https://raw.github.com/rivy/scoop/master/bin/install.ps1' )"
        set PATH=%PATH%;%LOCALAPPDATA%\scoop\shims
        ```

    * PowerShell &middot; `PS C:\>`

        ```
        iex (new-object net.webclient).downloadstring( 'https://raw.github.com/rivy/scoop/master/bin/install.ps1' )
        ```

2. install support applications via `scoop`

    ```
    scoop install cmake git make
    scoop bucket add rivy "https://github.com/rivy/scoop-bucket"
    scoop install rivy/gcc
    ```

3. clone the PCRE repository into PCRE_REPO_DIR

    ```
    git clone --recursive "https://github.com/rivy/PCRE.git" "PCRE_REPO_DIR"
    ```

4. build PCRE

    ```
    cd "PCRE_REPO_DIR"
    .\build.bat
    ```

`build.bat` uses `cmake` and `make` to configure and build PCRE. The build script reads the source code from a mirror of the PCRE2 SVN repository (in ".\PCRE2-mirror") and compiles all artifacts, out-of-source, into the ".\@build" subdirectory.

Using a subsequent `.\build.bat realclean` or `git clean -fd` will remove all build artifacts.

Further configuration/customization of the build can be accomplished via user-configurable CMAKE build properties, which are detailed and annotated within [`build.bat`](https://github.com/rivy/pcre/blob/master/build.bat).
