@setlocal
@echo off

set __dp0=%~dp0
set __ME=%~n0

set build_dir=%__dp0%.build
set src_dir=%__dp0%PCRE2-mirror

:: NOTE: Test #2: "API, errors, internals, and non-Perl stuff" FAILS with GPF if using stack recursion with default stack size
::   ... so, either use "-D PCRE2_HEAP_MATCH_RECURSE:BOOL=ON" or increase stack size to pass

:: user-configurable cmake project properties
set "project_props="
::
:: ref: http://pcre.org/current/doc/html/pcre2build.html @@ https://archive.is/rbI5U
::
::set "project_props=%project_props% -D PCRE2_BUILD_PCRE2_8:BOOL=OFF" &:: build 8-bit PCRE library (default == ON; used by pcregrep)
::set "project_props=%project_props% -D PCRE2_BUILD_PCRE2_16:BOOL=ON" &:: build 16-bit PCRE library
::set "project_props=%project_props% -D PCRE2_BUILD_PCRE2_32:BOOL=ON" &:: build 32-bit PCRE library
::
::set "project_props=%project_props% -D PCRE2_EBCDIC:BOOL=ON" &:: use EBCDIC coding instead of ASCII; (default == OFF)
::set "project_props=%project_props% -D PCRE2_EBCDIC_NL25:BOOL=ON" &:: use 0x25 as EBCDIC NL character instead of 0x15; implies EBCDIC; (default == OFF)
::
::set "project_props=%project_props% -D PCRE2_LINK_SIZE:STRING=4" &:: internal link size (in bytes) [ 2 (maximum 64Ki compiled pattern size ("gigantic patterns")), 3 ("truly enormous"), 4 ("truly enormous"+) ]
::set "project_props=%project_props% -D PCRE2_PARENS_NEST_LIMIT:STRING=500" &:: maximum depth of nesting parenthesis within regex pattern (default == 250)
::set "project_props=%project_props% -D PCRE2GREP_BUFSIZE:STRING=51200" &:: internal buffer size (longest line length guaranteed to be processable) (default == 20480)
set "project_props=%project_props% -D PCRE2_NEWLINE:STRING=ANYCRLF" &:: EOLN matching [CR, LF, CRLF, ANYCRLF, ANY (any Unicode newline sequence)] (default == LF) (NOTE: always overridable at run-time)
::set "project_props=%project_props% -D PCRE2_HEAP_MATCH_RECURSE:BOOL=ON" &:: OFF == use stack recursion; ON == use heap for recursion (slower); (default == OFF == stack recursion)
::set "project_props=%project_props% -D PCRE2_SUPPORT_JIT:BOOL=ON" &:: support for Just-In-Time compiling (default == OFF)
::set "project_props=%project_props% -D PCRE2_SUPPORT_PCRE2GREP_JIT:BOOL=OFF" &:: support for Just-In-Time compiling in pcre2grep (default == ON)
::set "project_props=%project_props% -D PCRE2_SUPPORT_UNICODE:BOOL=OFF" &:: enable support for Unicode and UTF-8/UTF-16/UTF-32 encoding (default == ON)
::set "project_props=%project_props% -D PCRE2_SUPPORT_BSR_ANYCRLF:BOOL=ON" &:: ON=Backslash-R matches only LF CR and CRLF, OFF=Backslash-R matches all Unicode Linebreaks; (default == OFF)
::set "project_props=%project_props% -D PCRE2_SUPPORT_VALGRIND:BOOL=ON" &:: enable Valgrind support (default == OFF)
::
::set "project_props=%project_props% -D PCRE2_SHOW_REPORT:BOOL=OFF" &:: show configuration report (default == ON)
::set "project_props=%project_props% -D PCRE2_BUILD_PCRE2GREP:BOOL=OFF" &:: build pcre2grep (default == ON)
::set "project_props=%project_props% -D PCRE2_BUILD_TESTS:BOOL=OFF" &:: build tests (default == ON)
::
:: MinGW
::set "project_props=%project_props% -D NON_STANDARD_LIB_PREFIX:BOOL=ON" &:: ON=Shared libraries built in mingw will be named pcre2.dll, etc., instead of libpcre2.dll, etc (default == OFF)
::set "project_props=%project_props% -D NON_STANDARD_LIB_SUFFIX:BOOL=ON" &:: ON=Shared libraries built in mingw will be named libpcre2-0.dll, etc., instead of libpcre2.dll, etc. (default == OFF)
::
:: MSVC
::set "project_props=%project_props% -D INSTALL_MSVC_PDB:BOOL=ON" &:: ON=Install .pdb files built by MSVC, if generated (default == OFF)

:: CMAKE_C_FLAGS
set "CMAKE_C_FLAGS="
:: host architecture
::set "CMAKE_C_FLAGS=%CMAKE_C_FLAGS% -m64" &:: generate 64-bit (default)
::set "CMAKE_C_FLAGS=%CMAKE_C_FLAGS% -m32" &:: generate 32-bit
:: increase stack size
set "CMAKE_C_FLAGS=%CMAKE_C_FLAGS% -Wl,--stack,8388608" &:: 8Mi

:: CMAKE_BUILD_TYPE
set "CMAKE_BUILD_TYPE=-D CMAKE_BUILD_TYPE=MinSizeRel" &:: [<empty/null>, "-D CMAKE_BUILD_TYPE=Debug", "-D CMAKE_BUILD_TYPE=Release", "-D CMAKE_BUILD_TYPE=RelWithDebInfo", "-D CMAKE_BUILD_TYPE=MinSizeRel"]

:: using scoop (see "http://scoop.sh")
:: `scoop install cmake gcc-tdw git gow` &:: install 'cmake', 'gcc-tdw' (multilib/32+64bit), and 'gow'

:: create build directories
mkdir "%build_dir%-x32"
mkdir "%build_dir%-x64"

:: cmake / make
set "CC="
set "CFLAGS="
set "CXX="
set "CXXFLAGS="
set "LDFLAGS="
::
cd "%build_dir%-x32" & cmake -G "Unix Makefiles" %CMAKE_BUILD_TYPE% -D CMAKE_MAKE_PROGRAM=make -D CMAKE_C_COMPILER=gcc -D CMAKE_C_FLAGS="-m32 %CMAKE_C_FLAGS%" %project_props% "%src_dir%" & make
cd "%build_dir%-x64" & cmake -G "Unix Makefiles" %CMAKE_BUILD_TYPE% -D CMAKE_MAKE_PROGRAM=make -D CMAKE_C_COMPILER=gcc -D CMAKE_C_FLAGS="-m64 %CMAKE_C_FLAGS%" %project_props% "%src_dir%" & make
