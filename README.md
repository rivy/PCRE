# PCRE

#### Building PCRE for Windows

This repository contains the necessary references and instructions to build PCRE (specifically PCRE2), from scratch, on a fresh Windows installation. The default build creates both 32-bit and 64-bit executables, built with the ANYCRLF and "just-in-time" options (as well as including the default unicode/utf support).

## Build

#### Requirements

PowerShell v3+ (included with Windows 7-SP1, or later)

#### Build Procedure

Start with a fresh basic installation of Windows (version 7-SP1 or later). From a shell (either CMD or PowerShell):

1. install scoop (see http://scoop.sh)

    ```
    powershell -noninteractive -noprofile -executionpolicy unrestricted -command "iex (new-object net.webclient).downloadstring('https://get.scoop.sh')"
    ```

2. restart the shell
3. install support applications via scoop

    ```
    scoop bucket add rivy "https://github.com/rivy/scoop-bucket"
    scoop install cmake gcc-tdm git gow
    ```

4. restart the shell (NOTE: this is only really needed for CMD shells and will not be necessary with future versions of `scoop`)
5. clone the PCRE repository into PCRE_REPO_DIR

    ```
    git clone "https://github.com/rivy/PCRE2.git" "PCRE_REPO_DIR"
    ```

6. build PCRE

    ```
    cd "PCRE_REPO_DIR"
    .\build.bat
    ```

`.\build.bat` uses `cmake` and `make` to configure and build PCRE. The build uses the source code from a mirror of the PCRE2 SVN repository, compiling all artifacts out-of-source. Both 32-bit and 64-bit executables are built and placed into the `.build-x32` and `.build-x64` subdirectories, respectively.

A subsequent `.\build-realclean.bat` will remove all build artifacts.

User-configurable CMAKE properties for the PCRE build are contained within [`.\build.bat`](https://github.com/rivy/PCRE2/blob/master/build.bat), annotated and pre-populated for use.
