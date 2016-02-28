@:: build [TARGET [ARGS ...]]
@:: TARGET == realclean | <makefile target>
@:: ARGS == <makefile TARGET args>

@setlocal
@echo off

set __dp0=%~dp0
set __ME=%~n0

set build_dir=%__dp0%@build
rem set build_dir=%build_dir_base%-x^%%_bin_type^%%
set src_dir=%__dp0%PCRE2-mirror

call :$create_list build_bin_types 32 64

::

:: NOTE: using scoop (see "http://scoop.sh") to install/check `gcc` prereqs
:: scoop install git cmake gcc-tdw gow &:: install `cmake`, 'gcc-tdw' (multilib/32+64bit), and 'gow'

:: configuration

:: NOTES
:: Test #2: "API, errors, internals, and non-Perl stuff" FAILS with GPF if using stack recursion with default stack size
:: * use either "-D PCRE2_HEAP_MATCH_RECURSE:BOOL=ON" or increase stack size to pass

:: user-configurable cmake project properties
set "project_props="
::
:: ref: http://pcre.org/current/doc/html/pcre2build.html @@ https://archive.is/rbI5U
::
::set "project_props=%project_props% -D BUILD_SHARED_LIBS:BOOL=ON" &:: build shared/dynamic library; (default == OFF)
::
::set "project_props=%project_props% -D PCRE2_BUILD_PCRE2_8:BOOL=OFF" &:: build 8-bit PCRE library (default == ON; used by pcregrep)
set "project_props=%project_props% -D PCRE2_BUILD_PCRE2_16:BOOL=ON" &:: build 16-bit PCRE library
set "project_props=%project_props% -D PCRE2_BUILD_PCRE2_32:BOOL=ON" &:: build 32-bit PCRE library
::
::set "project_props=%project_props% -D PCRE2_EBCDIC:BOOL=ON" &:: use EBCDIC coding instead of ASCII; (default == OFF)
::set "project_props=%project_props% -D PCRE2_EBCDIC_NL25:BOOL=ON" &:: use 0x25 as EBCDIC NL character instead of 0x15; implies EBCDIC; (default == OFF)
::
::set "project_props=%project_props% -D PCRE2_LINK_SIZE:STRING=4" &:: internal link size (in bytes) [ 2 (maximum 64Ki compiled pattern size ("gigantic patterns")), 3 ("truly enormous"), 4 ("truly enormous"+) ]
::set "project_props=%project_props% -D PCRE2_PARENS_NEST_LIMIT:STRING=500" &:: maximum depth of nesting parenthesis within regex pattern (default == 250)
::set "project_props=%project_props% -D PCRE2GREP_BUFSIZE:STRING=51200" &:: internal buffer size (longest line length guaranteed to be processable) (default == 20480)
set "project_props=%project_props% -D PCRE2_NEWLINE:STRING=ANYCRLF" &:: EOLN matching [CR, LF, CRLF, ANYCRLF, ANY (any Unicode newline sequence)] (default == LF) (NOTE: always overridable at run-time)
::set "project_props=%project_props% -D PCRE2_HEAP_MATCH_RECURSE:BOOL=ON" &:: OFF == use stack recursion; ON == use heap for recursion (slower); (default == OFF == stack recursion)
set "project_props=%project_props% -D PCRE2_SUPPORT_JIT:BOOL=ON" &:: support for Just-In-Time compiling (default == OFF)
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

:: cmake settings

:: CMAKE_VERBOSE_MAKEFILE
::set "project_props=%project_props% -D CMAKE_VERBOSE_MAKEFILE:BOOL=ON" &:: create verbose makefile (default == OFF)

:: CMAKE_C_FLAGS
set "CMAKE_C_FLAGS="
set "CMAKE_GCC_C_FLAGS="
set "CMAKE_MSVC_C_FLAGS="

:: CMAKE_EXE_LINKER_FLAGS
set "CMAKE_EXE_LINKER_FLAGS="
set "CMAKE_GCC_EXE_LINKER_FLAGS="
set "CMAKE_MSVC_EXE_LINKER_FLAGS="

:: set increased stack size
set "stack_size=8388608" &:: set new stack size to 8MiB
:: set stack size for GCC
set "CMAKE_GCC_C_FLAGS=%CMAKE_GCC_C_FLAGS% -Wl,--stack,%stack_size%" &:: GCC ~ set stack size
:: set stack size for MSVC
::set "CMAKE_MSVC_C_FLAGS=%CMAKE_MSVC_C_FLAGS% /F%stack_size%" &:: ** not working ** MSVC ~ set stack size (via `cl`)
set "CMAKE_MSVC_EXE_LINKER_FLAGS=%CMAKE_MSVC_EXE_LINKER_FLAGS% /STACK:%stack_size%" &:: MSVC ~ set stack size (via `link`)

:: CMAKE_BUILD_TYPE
set "CMAKE_BUILD_TYPE=MinSizeRel" &:: [<empty/null>, "Debug", "Release", "RelWithDebInfo", "MinSizeRel"]

:: cmake / make
set "CC="
set "CFLAGS="
set "CXX="
set "CXXFLAGS="
set "LDFLAGS="

::

:: TARGET: realclean
if /i "%~1" == "realclean" (
rem :: remove build directories
rem for /d %%D in ("%build_dir%*") do rmdir /s /q "%%D"
if EXIST "%build_dir%" (
	rmdir /s /q "%build_dir%"
	echo "%build_dir%" removed
	)
exit /b 0
)

::

set "_exit_code="
set "compiler_found="

:: GCC build(s)
:GCC
:: call :$path_of_file_in_pathlist _path "gcc" "%PATH%" ".exe;.com;%PATHEXT%"
call :$path_of_file_in_pathlist _path "gcc.exe" "%PATH%" &:: ~50% faster than using "%PATHEXT%"
if NOT DEFINED _path goto :GCC_DONE
set "compiler_found=1"

setlocal

:: GCC clean PATH
:: remove PATH references to alternate compiler installations
:: ... CMAKE can get confused by alternate and incompatible headers/libraries if alternate GCC installations are in PATH (eg, `perl`'s included GCC)
:: NOTE: assumes PATH contains fully qualified paths (without trailing slashes)
call :$echo_color cyan "%__ME%: INFO: cleaning PATH for GCC"
set new_PATH=%PATH%
rem :: call :$path_of_file_in_pathlist _path "gcc" "%new_PATH%" ".exe;.com;%PATHEXT%"
rem call :$path_of_file_in_pathlist _path "gcc.exe" "%new_PATH%" &:: ~50% faster than using "%PATHEXT%"
call :$FQ_dir_of _dir "%_path%"
call :$remove_from_list new_PATH "%_dir%" "%new_PATH%"
set "prior_dir="
:GCC_clean_PATH_LOOP
::call :$path_of_file_in_pathlist _path "gcc" "%new_PATH%" ".exe;.com;%PATHEXT%"
call :$path_of_file_in_pathlist _path "gcc.exe" "%new_PATH%" &:: ~50% faster than using "%PATHEXT%"
if NOT DEFINED _path ( goto :GCC_clean_PATH_LOOP_DONE )
call :$FQ_dir_of _dir "%_path%"
if /I "%prior_dir%" == "%_dir%" ( goto :GCC_clean_PATH_LOOP_DONE ) &:: repeating same loop (PATH likely has non-matching trailing slashes)
call :$remove_from_list new_PATH "%_dir%" "%new_PATH%"
call :$remove_from_list PATH "%_dir%" "%PATH%"
goto :GCC_clean_PATH_LOOP
:GCC_clean_PATH_LOOP_DONE

set "_list=%build_bin_types%"
call :$first_of _bin_type "%_list%"
call :$remove_first _list "%_list%"
::GCC build loop
:GCC_build_LOOP
:: check for ability to compile
call :$tempfile _OUTFNAME gcc.test .exe
if NOT DEFINED _OUTFNAME ( call :$echo_color red "%__ME%: ERR!: unable to create temp file" & exit /b -1 )
if DEFINED _bin_type set "_bin_type_FLAG=-m%_bin_type%"
set "ERRORLEVEL="
echo void main(){} | gcc %_bin_type_FLAG% -x c -o"%_OUTFNAME%" - 2>NUL 1>&2
set _ERR=%ERRORLEVEL%
erase /q "%_OUTFNAME%" 2>NUL 1>&2
set "_bin_type_text="
if DEFINED _bin_type set "_bin_type_text=%_bin_type%-bit "
if NOT "%_ERR%" == "0" ( call :$echo_color darkyellow "%__ME%: WARN: `gcc` unable to create %_bin_type_text%binaries" & goto :GCC_build_LOOP_NEXT )
::
:: check/create directory
set "_dir=%build_dir%\MinGW"
:: hide redundant cmake output report if build directory already present (== initial build already complete)
set "_suppress_cmake_output=1"
if DEFINED _bin_type set "_dir=%_dir%-x%_bin_type%"
if DEFINED CMAKE_BUILD_TYPE set "_dir=%_dir%.%CMAKE_BUILD_TYPE%"
if NOT EXIST "%_dir%" ( mkdir "%_dir%" & set "_suppress_cmake_output=" )
cd %_dir%
call :$echo_color yellow "[%_dir%]"
::
call :$echo_color cyan "%__ME%: INFO: starting cmake"
set "CMAKE_BUILD_TYPE_OPTION="
if DEFINED CMAKE_BUILD_TYPE ( set "CMAKE_BUILD_TYPE_OPTION=-D CMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE%")
set "_bin_type_FLAG="
if DEFINED _bin_type set "_bin_type_FLAG=-m%_bin_type%"
set "_cmake_stdout="
if DEFINED _suppress_cmake_output ( set "_cmake_stdout=>NUL" )
set "ERRORLEVEL=" &:: clear any previous erroneus ERRORLEVEL overrides
cmake -G "MinGW Makefiles" %CMAKE_BUILD_TYPE_OPTION% -D CMAKE_MAKE_PROGRAM=make -D CMAKE_C_COMPILER=gcc -D CMAKE_C_FLAGS="%_bin_type_FLAG% %CMAKE_C_FLAGS% %CMAKE_GCC_C_FLAGS%" -D CMAKE_EXE_LINKER_FLAGS="%CMAKE_EXE_LINKER_FLAGS% %CMAKE_GCC_EXE_LINKER_FLAGS%" %project_props% "%src_dir%" %_cmake_stdout%
if NOT "%ERRORLEVEL%"=="0" ( set "_exit_code=%ERRORLEVEL%" & call :$echo_color red "%__ME%: ERR!: cmake error occurred" & goto :GCC_build_LOOP_NEXT )
set command=make & set args=%*
if DEFINED args (set command=`make %*`)
call :$echo_color cyan "%__ME%: INFO: starting %command%"
make %*
if NOT "%ERRORLEVEL%"=="0" ( set "_exit_code=%ERRORLEVEL%" & call :$echo_color red "%__ME%: ERR!: make error occurred" )
:GCC_build_LOOP_NEXT
if NOT DEFINED _list goto :GCC_build_LOOP_DONE
call :$first_of _bin_type "%_list%"
call :$remove_first _list "%_list%"
goto :GCC_build_LOOP
:GCC_build_LOOP_DONE

::
endlocal
:GCC_DONE
::

:: MSVC build
:MSVC
:: call :$path_of_file_in_pathlist _path "cl" "%PATH%" ".exe;.com;%PATHEXT%"
call :$path_of_file_in_pathlist _path "cl.exe" "%PATH%" &:: ~50% faster than using "%PATHEXT%"
if NOT DEFINED _path goto :MSVC_DONE
set "compiler_found=1"

setlocal
rem goto :MSVC_clean_PATH_LOOP_DONE

:: MSVC clean PATH
:: remove PATH references to alternate compiler installations
:: ... CMAKE can get confused by alternate and incompatible headers/libraries if alternate GCC installations are in PATH (eg, `perl`'s included GCC)
:: NOTE: assumes PATH contains fully qualified paths (without trailing slashes)
call :$echo_color cyan "%__ME%: INFO: cleaning PATH for MSVC"
set new_PATH=%PATH%
set "prior_dir="
:MSVC_clean_PATH_LOOP
::call :$path_of_file_in_pathlist _path "gcc" "%new_PATH%" ".exe;.com;%PATHEXT%"
call :$path_of_file_in_pathlist _path "gcc.exe" "%new_PATH%" &:: ~50% faster than using "%PATHEXT%"
if NOT DEFINED _path ( goto :MSVC_clean_PATH_LOOP_DONE )
call :$FQ_dir_of _dir "%_path%"
if /I "%prior_dir%" == "%_dir%" ( goto :MSVC_clean_PATH_LOOP_DONE ) &:: repeating same loop (PATH likely has non-matching trailing slashes)
call :$remove_from_list new_PATH "%_dir%" "%new_PATH%"
call :$remove_from_list PATH "%_dir%" "%PATH%"
goto :MSVC_clean_PATH_LOOP
:MSVC_clean_PATH_LOOP_DONE

::MSVC/nmake build
:MSVC_build
::check/create directory
set "_dir=%build_dir%\nmake"
if DEFINED VCvars_CL_VER set "_dir=%_dir%-cl@%VCvars_CL_VER%"
:: hide redundant cmake output report if build directories are already present (== initial build already complete)
set "_suppress_cmake_output=1"
if DEFINED CMAKE_BUILD_TYPE set "_dir=%_dir%.%CMAKE_BUILD_TYPE%"
if NOT EXIST "%_dir%" ( mkdir "%_dir%" & set "_suppress_cmake_output=" )
cd %_dir%
call :$echo_color yellow "[%_dir%]"
::
call :$echo_color cyan "%__ME%: INFO: starting cmake"
set "CMAKE_BUILD_TYPE_OPTION="
if DEFINED CMAKE_BUILD_TYPE ( set "CMAKE_BUILD_TYPE_OPTION=-D CMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE%")
set "_cmake_stdout="
if DEFINED _suppress_cmake_output ( set "_cmake_stdout=>NUL" )
set "ERRORLEVEL=" &:: clear any previous erroneus ERRORLEVEL overrides
cmake -G "NMake Makefiles" %CMAKE_BUILD_TYPE_OPTION% -D CMAKE_MAKE_PROGRAM=nmake -D CMAKE_C_COMPILER=cl -D CMAKE_C_FLAGS="%_bin_type_FLAG% %CMAKE_C_FLAGS% %CMAKE_MSVC_C_FLAGS%" -D CMAKE_EXE_LINKER_FLAGS="%CMAKE_EXE_LINKER_FLAGS% %CMAKE_MSVC_EXE_LINKER_FLAGS%" %project_props% "%src_dir%" %_cmake_stdout%
if NOT "%ERRORLEVEL%"=="0" ( set "_exit_code=%ERRORLEVEL%" & call :$echo_color red "%__ME%: ERR!: cmake error occurred" & goto :MSVC_build_DONE )
set command=nmake & set args=%*
if DEFINED args (set command=`nmake %*`)
call :$echo_color cyan "%__ME%: INFO: starting %command%"
nmake %*
if NOT "%ERRORLEVEL%"=="0" ( set "_exit_code=%ERRORLEVEL%" & call :$echo_color red "%__ME%: ERR!: nmake error occurred" )
:MSVC_build_DONE

::
endlocal
:MSVC_DONE
::

::
:DONE
if NOT DEFINED compiler_found ( set "_exit_code=-1" & call :$echo_color red "%__ME%: ERR!: no compiler found" )
exit /b %_exit_code%
::

::
goto :EOF
:: ### SUBs

::
:$echo_color ( [FORE_COLOR [BACK_COLOR]] TEXT )
:_echo_color ( [FORE_COLOR [BACK_COLOR]] TEXT )
:: echo TEXT to console with foreground FORE_COLOR and background BACK_COLOR (defaults to regular echo if powershell is not present)
:: FORE_COLOR == standard color name for foreground color
:: BACK_COLOR == standard color name for background color
:: TEXT == TEXT to echo
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=$echo_color"
call :$echo_color_NO_NEWLINE %*
echo:
endlocal
goto :EOF
::

::
:$echo_color_NO_NEWLINE ( [FORE_COLOR [BACK_COLOR]] TEXT )
:_echo_color_NO_NEWLINE ( [FORE_COLOR [BACK_COLOR]] TEXT )
:: echo TEXT to console with foreground FORE_COLOR and background BACK_COLOR (defaults to regular echo if powershell is not present)
:: FORE_COLOR == standard color name for foreground color
:: BACK_COLOR == standard color name for background color
:: TEXT == TEXT to echo
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=$echo_color"
set "fore_color=%~1"
set "back_color=%~2"
set "text=%~3"
if NOT DEFINED text ( set "text=%back_color%" & set "back_color=" )
if NOT DEFINED text ( set "text=%fore_color%" & set "fore_color=" )
set "options="
if DEFINED fore_color ( set "options=%options% -fore %fore_color%" )
if DEFINED back_color ( set "options=%options% -back %back_color%" )
::
set _POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
if EXIST "%_POWERSHELL%" ( goto :_echo_color_POWERSHELL_out )
echo text
goto :_echo_color_DONE
:_echo_color_POWERSHELL_out
"%_POWERSHELL%" -noprofile -ex unrestricted "write-host -nonewline %options% '%text%'"
:_echo_color_DONE
:_echo_color_RETURN
endlocal
goto :EOF
::

@::::
@:: FUNCTIONS (library:rev69) :: (C) 2010-2016, Roy Ivy III, MIT license
@call %*
@goto :EOF
::

:: NOTE: ToDO: add noLF versions to all $$echo... functions

:: NOTE: ToDO: add ability to store/use/rerturn double-quotes and semicolons (? using character replacements)
:: #.... use ref: https://sbjh.wordpress.com/2013/02/08/generate-any-control-character @@ https://archive.is/QYqgh

:: NOTE: fix bug working with ampersand (&) characters; any problems with redirection characters, etc?

:: NOTE: for use with TCC, _MUST_ have TCMD.INI "CMDVariables=Yes"; this, plus all the WAD ("works as designed") bugs & the interminably slow execution of large batch files makes the case for completely removing TCC compatibility

:: NOTE: BAT/CMD script files require PC (CRLF) line endings for correct function; ASCII/UTF-8 encoding should also be used

:: NOTES
:: DEFINITIONS
:: ITEMs are character strings which may contain no internal double quotes (and no characters outside the usual non-graphical, printable set [ ord(ch) > 31, ord(ch) < 128 ]
:: LISTs are a ';' seperated list of ITEMs
:: SETs or PATHLISTs are LISTs which contain unique individual ITEMs (and don't accept duplicate additions)
:: PATHLISTs don't accept NULL ITEM additions
:: PATHLISTs normalize all added ITEMs as PATHs (which removes any trailing backslashes [DOS/Win path dividers])
:: BOOLEAN values are defined as FALSE == NULL, TRUE == any non-NULL value (generally "1" or "true", but can be any non-NULL, including "0")
:: :: this makes testing for truth easy... if DEFINED foo ( echo true ) else ( echo false )
::
:: LISTs may contain NULL values, and are all defined as "" in the special case of containing a single NULL value
:: NULL valued ITEMs within LISTs may be either encoded as either "" or NULL, but will be returned as NULL when using functions returning individual elements within LISTs
::
:: NOTE: Don't use '(set %RETvar%=%RETval%)' for return values as internal close parenthesis in RETval will cause errors. Use 'set "%RETvar%=%RETval%"' instead.
:: NOTE: ... if RETval may contain double quotes, must use 'endlocal & set %RETvar%=%RETval%', as surrounding aa double quote with double quotes won't work.

:: ToDO: add new function "get_output( REF_VARNAME COMMAND )" that runs COMMAND & stores the last line output into VARNAME (initial plan is to use a temporary file)

:: ToDO: ( endlocal ... ) block and variations to bypass setlocal/endlocal walls
:: ToDO: BLOG needed parens for ifs in end ( endlocal ... ) block o/w only 1st if is evaluated

:: URLref: Use of $ as subroutine sigil @@ http://www.webcitation.org/5z4F3V9yk @ 2011-05-30.0754

:: ToDO: rethink returning values (using jeb's techinique @ http://www.dostips.com/forum/viewtopic.php?p=6930#p6930 @@ http://www.webcitation.org/6ADfeDSrJ)

:: ToDO: rethink PATH functions in reference to the following notes:
::     : [How-TO check if directory is within PATH] "http://stackoverflow.com/questions/141344/how-to-check-if-directory-exists-in-path/8046515#8046515"
::     : [How-TO split PATH on ';' - initial correct answer] http://stackoverflow.com/questions/5471556/pretty-print-windows-path-variable-how-to-split-on-in-cmd-shell/5472168#5472168
::     : [How-TO split PATH on ';' - slightly improved answer] http://stackoverflow.com/a/7940444/43774

:: ToDO: look at [DOS Function Collection] http://www.dostips.com/DtCodeFunctions.php @@ http://www.webcitation.org/6ADg2siao

:: ToDO: look at [Date Math] http://www.robvanderwoude.com/datetimentmath.php @@ http://www.webcitation.org/6Ei47MYcp AND http://www.powercram.com/2010/07/get-yesterdays-date-in-ms-dos-batch.html @@ http://www.webcitation.org/6ADgoDmWV

:: DONE: add is_dir [see http://stackoverflow.com/questions/8909355/how-to-check-if-target-of-path-is-a-directory]

:: ToDO: rethink PREinitialize ... currently, doesn't work as portrayed; %0 %* is NOT the main script and it's arguments; so, the script can't be re-run as written; additionally, environment variables and path changes are lost when returning from the subshell, so it's not correct; calling the script directly doesn't change the parse/comspec misalignment
::          :: possible, changing comspec and recalling directly after PREinitialize might work
::      NOTE: the only culprit known right now is Perl with a TCC shell and an empty Perl5SHELL environment variable
::          :: this is one Perl fix: `perl -e "if (not defined $ENV{PERL5SHELL}) {$ENV{COMSPEC}=q{c:\windows\system32\cmd.exe}}; system(q{gccvars perl});"`

:: ToDO: ?? change API function names to use sigil sign ($)?

:: NOTE: Use DEFINED and NOT DEFINED instead of comparison of vars to "" when possible to avoid quoting issues as much as possible
:: NOTE: "%_RETvar%" == "" comparision @ function RETURN is necessary because of endlocal which undefines _RETvar after the %% instantiation

:: DONE::ToDO: update API changes :: _echo_no_LF => _echo_noLF ; _path_of_first => _path_of_file
:: ToDO: !! change path_of_item_in_pathlist to either NOTE NULL item will be found in first existing path OR return NULL
:: ToDO: !! copy updated library to all other BATs
:: ToDO: update library documentation with a list of functions & short, one line explanations as a summary section

:: URLref: [CMD Syntax: Escape characters, delimiters, & quotes] http://ss64.com/nt/syntax-esc.html @@ http://archive.is/V92JZ
:: URLref: [CMD parsing (at command line & at batch file level)] http://stackoverflow.com/questions/4094699/how-does-the-windows-command-interpreter-cmd-exe-parse-scripts/4095133#4095133

:: URLref: [dbenham HOME - CharLib.BAT] https://sites.google.com/site/dbenhamfiles/home @@ http://archive.is/8KAbT
:: URLref: [BUG SOLVED! - Return any string across ENDLOCAL boundary; using %%2 ... in FOR] http://www.dostips.com/forum/viewtopic.php?f=3&t=1839 @@ http://archive.is/0QuYk
::
:__exec_self_as_BTM
:: NOTE: should NOT be called as a subroutine; ONLY use directly, with a guarded GOTO (eg, "if 1.0 == 01 if /i "%~x0" neq ".BTM" goto :__exec_self_as_BTM")
:: VARS: GLOBAL::__exec_self_as_BTM_localize; must be set prior to execution; BOOLEAN == is current script localized within SETlocal/ENDlocal block?; required to set up balanced SETlocal/ENDlocal blocks within newly incarnated BTM
:: VARS: GLOBAL::__ME, __ME_dir, __ME_fullpath; REQUIRED; these are passed on through to the new BTM script as pointers to the context of the original script
:: NOTE: Prior failed attempts at TCC speedup:
:: * @if 1.0 == 1 ( loadbtm on 1> nul 2> nul & cd . ) &:: only works for TCC (not TCC/LE) and DOESN'T work well at all, timing seems just as slow!! (Maybe this is because of the call's to subroutines?)
:: * @if 1.0 == 1 ( option //UpdateTitle=No ) &:: ToDO: TEST by timing -- speeds up TCC execution by disabling window title updates? -- NO, initial testing shows no differences
if NOT 01 == 1.0 ( echo %__ME%:__exec_self_as_BTM: ERROR: Console interpreter is NOT TCC/4NT; unable to execute script as BTM 1>&2 & @echo %__ME_echo% & @exit /B -1 )
if NOT defined __ME ( echo %__ME%:__exec_self_as_BTM: ERROR: __ME must be defined prior to call; unable to execute script as BTM 1>&2 & @echo %__ME_echo% & @exit /B -1 )
if NOT defined __ME_dir ( echo %__ME%:__exec_self_as_BTM: ERROR: __ME_dir must be defined prior to call; unable to execute script as BTM 1>&2 & @echo %__ME_echo% & @exit /B -1 )
if NOT defined __ME_fullpath ( echo %__ME%:__exec_self_as_BTM: ERROR: __ME_fullpath must be defined prior to call; unable to execute script as BTM 1>&2 & @echo %__ME_echo% & @exit /B -1 )
call :_tempfile __exec_self_as_BTM_TEMPFILE "%__ME_fullpath%" .BTM
if NOT exist "%__exec_self_as_BTM_TEMPFILE%" ( echo %__ME%:__exec_self_as_BTM: ERROR: unable to open temporary file for BTM creation 1>&2 & @echo %__ME_echo% & @exit /B -1 )
if DEFINED __exec_self_as_BTM_localize echo @setlocal>> "%__exec_self_as_BTM_TEMPFILE%"
echo @:: [dynamic BTM, created from "%__ME_fullpath%"]>> "%__exec_self_as_BTM_TEMPFILE%"
echo @set __exec_self_as_BTM_TEMPFILE=>> "%__exec_self_as_BTM_TEMPFILE%"
echo set __ME=%__ME%>> "%__exec_self_as_BTM_TEMPFILE%"
echo set __ME_dir=%__ME_dir%>> "%__exec_self_as_BTM_TEMPFILE%"
echo set __ME_fullpath=%__ME_fullpath%>> "%__exec_self_as_BTM_TEMPFILE%"
echo @goto :__BTM_ENTRY >> "%__exec_self_as_BTM_TEMPFILE%"
::type "%~dpnx0" >> "%__exec_self_as_BTM_TEMPFILE%"
::type "%~f0" >> "%__exec_self_as_BTM_TEMPFILE%"
type "%__ME_fullpath%" >> "%__exec_self_as_BTM_TEMPFILE%"
:: correct setlocal/endlocal imbalance
if NOT DEFINED __exec_self_as_BTM_localize goto :__exec_self_as_BTM_call
endlocal & set __exec_self_as_BTM_TEMPFILE=%__exec_self_as_BTM_TEMPFILE%
:__exec_self_as_BTM_call
:: call new BTM incarnation
call "%__exec_self_as_BTM_TEMPFILE%" %*
:__exec_self_as_BTM_END
:: clean up temporaries
if EXIST "%__exec_self_as_BTM_TEMPFILE%" erase "%__exec_self_as_BTM_TEMPFILE%" >NUL
set __exec_self_as_BTM_TEMPFILE=
goto :EOF
::

::
:$$echo_state ( ref_RETURN )
:$echo_state ( ref_RETURN )
:_echo_state ( ref_RETURN )
:: determine and return the current echo state [ON/OFF]
:: RETURN == ON _or_ OFF [corresponding to the current echo state and usable as "echo %RETval%"]
:: NOTE: subs generally expect echo ON/OFF to be set prior to call for debugging so don't use any subroutine calls
@setlocal
@set "__DEBUG_KEY=@"
@set "__MEfn=_echo_state"
@set "_RETval=OFF"
@set "_RETvar=%~1"
@if NOT DEFINED temp ( set "temp=%tmp%" )
@if NOT EXIST "%temp%" ( set "temp=%tmp%" )
@if NOT EXIST "%temp%" ( set "temp=%LocalAppData%\Temp" )
@if NOT EXIST "%temp%" ( set "temp=%SystemRoot%\Temp" )
@if NOT EXIST "%temp%" ( set "temp=." )
:_echo_state_find_unique_temp
@set "tempfile=%temp%\%~nx0.echo_state.%RANDOM%.%RANDOM%.txt"
@if EXIST %tempfile% ( @goto :_echo_state_find_unique_temp )
@echo > "%tempfile%"
@type "%tempfile%" | "%SystemRoot%\System32\findstr" /i /r " [(]*on[)]*\.$" >nul 2>&1
@if "%ERRORLEVEL%"=="0" ( set _RETval=ON )
::@erase "%tempfile%" /Q > nul 2>&1
@endlocal & @set %_RETvar%^=%_RETval%
@if NOT 01 == 1.0 (@exit /b 0) else (@quit 0)
::

::
:$$tempfile ( ref_RETURN [PREFIX [EXTENSION]])
:$tempfile ( ref_RETURN [PREFIX [EXTENSION]])
:_tempfile ( ref_RETURN [PREFIX [EXTENSION]])
:: open a unique temporary file
:: RETURN == full pathname of temporary file (with given PREFIX and EXTENSION) [NOTE: has NO surrounding quotes]
:: PREFIX == optional filename prefix for temporary file
:: EXTENSION == optional extension (including leading '.') for temporary file [default == '.bat']
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_tempfile"
set "_RETval="
set "_RETvar=%~1"
set "prefix=%~nx2"
set "extension=%~3"
if NOT DEFINED extension ( set "extension=.txt")
:: attempt to find a temp directory
:: NOTE: see [How-TO check for directory-only existence] http://stackoverflow.com/a/12037613/43774
if NOT DEFINED temp ( set "temp=%tmp%" )
if NOT EXIST "%temp%" ( set "temp=%tmp%" )
if NOT EXIST "%temp%" ( set "temp=%LocalAppData%\Temp" )
if NOT EXIST "%temp%" ( set "temp=%SystemRoot%\Temp" )
if NOT EXIST "%temp%" ( goto :_tempfile_RETURN )    &:: undefined TEMP, RETURN (with NULL filename)
:_tempfile_find_unique_temp
set "_RETval=%temp%\%prefix%.TEMPFILE.%RANDOM%.%RANDOM%%extension%"
if EXIST %_RETval% ( goto :_tempfile_find_unique_temp )
:: instantiate tempfile [NOTE: this is an unavoidable race condition]
if NOT 01 == 1.0 (
    set /p OUTPUT=<nul >"%_RETval%" 2>nul
    ) else (
    echos >"%_RETval%" 2>nul
    )
if NOT EXIST "%_RETval%" (
    echo %__ME%:%__MEfn%: ERROR: unable to open tempfile [%_RETval%] 1>&2
    set "_RETval="
    )
:_tempfile_find_unique_temp_DONE
:_tempfile_RETURN
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:__PREinitialize ( [ ref_RETURN ] )
:: RETURN == COMSPEC name ('cmd', 'tcc')
::
:: BAT/CMD preinitialization for alternative shell compatibility [TCC/4NT, etc]
:: get COMSPEC filename and determine shell parsing type
:: NOTE: COMSPEC and parsing shell could be different if, for example, this BAT is executed from perl (perl defaults to using 'cmd' for system commands despite %COMSPEC% [see PERL5SHELL references in URLrefs: http://perldoc.perl.org/perlwin32.html#Usage-Hints-for-Perl-on-Win32 , http://perldoc.perl.org/perlrun.html#ENVIRONMENT])
:: NOTE: MINIMIZE subroutine calls within __PREinitialize (and any called subroutines) to allow quick transition to BTM for TCC (especially, comment out "call :_echo_DEBUG_KEY ..." calls unless/until needed)
setlocal
set "__DEBUG_KEY=@@"
set "__MEfn=__PREinitialize"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
:__PREinitialize_CMDVARIABLES_CHECK
::TCC/4NT; expect "CMDVariables=Yes" in TCMD.ini to maximize compatibility
if NOT 01 == 1.0 ( goto :__PREinitialize_CMDVARIABLES_CHECK_DONE )
(set _TEMP=)
(set _TEMP(x86)=1)
set _TEMP=%_TEMP(x86)%
if "%_TEMP%" == "1" ( goto :__PREinitialize_CMDVARIABLES_CHECK_DONE )
echo %__ME%:%__MEfn%: ERROR: "CMDVariables=No" in TCMD.ini; make "CMDVariables=Yes" in TCMD.ini for CMD compatibility 1>&2
if 01 == 1.0 ( @echo %__ME_echo% & @quit -1 ) else ( @echo %__ME_echo% & @exit /B -1 ) &::TCC drops/ignores exit ERRORLEVEL from subroutines [so, use "quit" instead]
:__PREinitialize_CMDVARIABLES_CHECK_DONE
::check shell PARSE type vs COMSPEC
call :_filename_of _COMSPECNAME "%ComSpec%"
set "_PARSETYPE=%_COMSPECNAME%"
:: known parsers (CMD & TCC)
if 01 == 1.0 ( set "_PARSETYPE=tcc" ) else ( set "_PARSETYPE=cmd" )
call :_echo_DEBUG_KEY _COMSPECNAME="%_COMSPECNAME%"
call :_echo_DEBUG_KEY _PARSETYPE="%_PARSETYPE%"
:: if same, then assume user wants the current shell and continue
if /i [%_COMSPECNAME%]==[%_PARSETYPE%] ( goto :__PREinitialize_RETURN )
:: NOTE: this doesn't work ...
:: :: otherwise, restart using known COMSPEC with CMD.exe fallback (if found)
:: :: ?? use /d to avoid AutoRun for TCC and/or CMD shell execution
::if /i "%_COMSPECNAME%"=="tcc" (
::  "%ComSpec%" /x/c %0 %*
::  exit /B %ERRORLEVEL%
::  )
::set ComSpec=%SystemRoot%\\System32\\cmd.exe
::if EXIST "%ComSpec%" (
::  "%ComSpec%" /x/c %0 %*
::  exit /B %ERRORLEVEL%
::  )
:: echo %__ME%:%__MEfn%: ERROR: unmatched batch file parser and COMSPEC [unrecognized current COMSPEC and unable to find CMD.exe (at "%ComSpec%")]
:: exit /B -1
::
::
:__PREinitialize_RETURN
if /i NOT [%_COMSPECNAME%]==[%_PARSETYPE%] (
    echo %__ME%:%__MEfn%: ERROR: unmatched batch file parser and COMSPEC 1>&2
    if 01 == 1.0 ( @echo %__ME_echo% & @quit -1 ) else ( @echo %__ME_echo% & @exit /B -1 ) &::TCC drops/ignores exit ERRORLEVEL from subroutines [so, use "quit" instead]
    )
set "_RETval=%_COMSPECNAME%"
call :_echo_DEBUG_KEY _COMSPECNAME="%_COMSPECNAME%"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$filename_of ( ref_RETURN PATH )
:$filename_of ( ref_RETURN PATH )
:_filename_of ( ref_RETURN PATH )
:: RETURN == filename of PATH
:: NOTE: special processing to deal correctly with the case of "<DRIVE>:" ("<DRIVE>:" == "<DRIVE>:." == ".")
:: NOTE: _filename_of("") == ""
:: NOTE: _filename_of("\\") == _filename_of("\") == _filename_of("c:\") == _filename_of("c:\.") == ""
:: NOTE: _filename_of("c:") == _filename_of("c:.") == _filename_of(".")
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_filename_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "_path=%~2"
if NOT DEFINED _path ( goto :_filename_of_RETURN )
if "%_path%" == "\\" ( set "_path=\" )
::?:call :_drive_of drive "%~1"
::?:if /i "%drive%" == "%~1" ( set "_RETval=" & goto :_filename_of_RETURN )
::?:if /i "%drive%\" == "%~1" ( set "_RETval=" & goto :_filename_of_RETURN )
call :_rewrite_path_to_FQ_local _path _ "%_path%"
call :_echo_DEBUG_KEY _path="%_path%"
call :_echo_DEBUG_KEY _="%_%"
call :_param_tilde_N _RETval "%_path%"
:: remove trailing backslashes
call :_rtrim _RETval "%_RETval%" "\"
:_filename_of_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$rewrite_path_to_FQ_local ( ref_RETURN_path ref_RETURN_drive PATH )
:$rewrite_path_to_FQ_local ( ref_RETURN_path ref_RETURN_drive PATH )
:_rewrite_path_to_FQ_local ( ref_RETURN_path ref_RETURN_drive PATH )
:: RETURN_path == PATH, rewritten in a fully qualified (semi-canonical) form: removing extraneous trailing "\" or "\." and changing path to point to current drive (if a drive is specified)
:: RETURN_drive == original drive of PATH, "" if no drive was specified
:: NOTE:: changing PATH to refer to a similar "false" PATH on the local drive (for CMD and/or TCC) speeds up calculations for UNC network paths (avoiding network timeouts)
:: NOTE:: special processing is needed to deal with the fact that TCC acts out with almost unsuppressible errors for inaccessible and UNC PATHs [which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: NOTE:: changing PATH to refer to a local drive for TCC [avoids a loud & nasty TCC bug [URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://webcitation.org/63ua1bpOk]]
:: NOTE: assumes PATH has leading "X:", "\\...\...", "\...", or is a relative path (without leading "\")
:: NOTE: _rewrite_path_to_FQ_local("") => ("", "")
:: NOTE: _rewrite_path_to_FQ_local("\\") == _rewrite_path_to_FQ_local("\")
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_rewrite_path_to_FQ_local"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETvar_drive=%~2"
set "_RETval=%~3"
set "drive="
call :_echo_DEBUG_KEY PATH="%_RETval%"
if NOT DEFINED _RETval ( goto :_rewrite_path_to_FQ_local_RETURN )
set "_path=%_RETval%"
if "%_path%" == "." ( goto :_rewrite_path_to_FQ_local_RETURN )
set local_drive=
call :_split_drive_path_of drive _path "%_path%"
if NOT DEFINED _path ( set "_path=." )
call :_echo_DEBUG_KEY drive="%drive%"
call :_echo_DEBUG_KEY _path="%_path%"
:_rewrite_path_to_FQ_local_LOOP
if NOT DEFINED _path ( goto :_rewrite_path_to_FQ_local_LOOP_DONE )
if "%_path%" == "\\" ( set "_path=\" )
if "%_path%" == "\." ( set "_path=\" )
if "%_path%" == "\" ( goto :_rewrite_path_to_FQ_local_LOOP_DONE )
:: TCC doesn't handle trailing "\." or "\" correctly, so remove them
call :_echo_DEBUG_KEY 2_path="%_path%"
:_rewrite_path_to_FQ_local_LOOP_test_1
if NOT "%_path:~-2,2%" == "\." ( goto :_rewrite_path_to_FQ_local_LOOP_test_2 )
set "_path=%_path:~0,-2%"
goto :_rewrite_path_to_FQ_local_LOOP
:_rewrite_path_to_FQ_local_LOOP_test_2
call :_echo_DEBUG_KEY 3_path="%_path%"
if NOT "%_path:~-1,1%" == "\" ( goto :_rewrite_path_to_FQ_local_LOOP_test_3 )
set "_path=%_path:~0,-1%"
goto :_rewrite_path_to_FQ_local_LOOP
:_rewrite_path_to_FQ_local_LOOP_test_3
if NOT "%_path:~0,2%" == "\\" ( goto :_rewrite_path_to_FQ_local_LOOP_test_DONE )
set "_RETval=%_path:~1%"
:_rewrite_path_to_FQ_local_LOOP_test_DONE
:_rewrite_path_to_FQ_local_LOOP_DONE
call :_echo_DEBUG_KEY _RETval="%_RETval%"
if NOT DEFINED drive ( goto :_rewrite_path_to_FQ_local_DONE )
if NOT DEFINED local_drive ( set "local_drive=%SYSTEMDRIVE%" )
if NOT DEFINED local_drive ( set "local_drive=%SYSTEMROOT:~0,2%" )
if NOT DEFINED local_drive ( set "local_drive=%~d0" )
call :_echo_DEBUG_KEY local_drive="%local_drive%"
set "_RETval=%local_drive%%_path%"
:_rewrite_path_to_FQ_local_DONE
:_rewrite_path_to_FQ_local_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set "%_RETvar%=%_RETval%" & set "%_RETvar_drive%=%drive%"
goto :EOF
::

::
:$$drive_of ( ref_RETURN PATH )
:$drive_of ( ref_RETURN PATH )
:_drive_of ( ref_RETURN PATH )
:: RETURN == drive of PATH
:: NOTE: assumes PATH has leading "X:", "\\SERVER"; PATHs without a drive indicator return NULL
:: NOTE: drive_of("") == ""; drive_of("\\SERVER\PATH") == "\\SERVER"
:: NOTE: special UNC paths: drive_of("\\?\UNC\PATH") => drive_of("\\PATH"); drive_of("\\?\PATH") == drive_of("\\.\PATH") => drive_of("PATH")
:: URLref: [Naming Files, Paths, and Namespaces - MSDN] http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx @@ http://archive.is/EcTrM @@ http://webcitation.org/6IwYVd1Cn
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_drive_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "_path=%~2"
call :_split_drive_path_of _RETval _ "%_path%"
::if NOT DEFINED _RETval ( set "_RETval=%~d2" ) &:: causes TCC errors for non-existant PATHs
:_drive_of_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$FQ_drive_of ( ref_RETURN PATH )
:$FQ_drive_of ( ref_RETURN PATH )
:_FQ_drive_of ( ref_RETURN PATH )
:: RETURN == fully qualified (canonical) directory of PATH
:: NOTE: _FQ_drive_of("") == ""
:: NOTE: _FQ_drive_of("\\") == _FQ_drive_of("\") == _FQ_drive_of("\.")
:: NOTE: _FQ_drive_of("c:") == _FQ_drive_of("c:.")
:: NOTE: _FQ_drive_of("c:\") == _FQ_drive_of("c:\.") == "c:\"
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_FQ_drive_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: avoid TCC path parsing errors for null strings
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_FQ_drive_of_RETURN )
call :_rewrite_path_to_FQ_local _ drive "%_RETval%"
if NOT DEFINED drive ( goto :_FQ_drive_of_DONE )
:_FQ_drive_of_DONE
if NOT DEFINED drive ( set "drive=%SYSTEMDRIVE%" )
if NOT DEFINED drive ( set "drive=%SYSTEMROOT:~0,2%" )
if NOT DEFINED drive ( set "drive=%~d0" )
call :_echo_DEBUG_KEY drive="%drive%"
:_FQ_drive_of_DONE
set "_RETval=%drive%"
:_FQ_drive_of_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$split_drive_path_of ( ref_RETURN_DRIVE ref_RETURN_PATH PATH )
:$split_drive_path_of ( ref_RETURN_DRIVE ref_RETURN_PATH PATH )
:_split_drive_path_of ( ref_RETURN_DRIVE ref_RETURN_PATH PATH )
:: RETURN_DRIVE == drive of PATH
:: RETURN_PATH == PATH with drive prefix removed
:: NOTE: assumes PATH has leading "X:", "\\", "\...", or is a relative path (without leading "\")
:: NOTE: drive_of("") == ""; drive_of("\\SERVER\PATH") == "\\SERVER"
:: NOTE: special UNC paths: drive_of("\\?\UNC\PATH") => drive_of("\\PATH"); drive_of("\\?\PATH") => drive_of("PATH"); drive_of("\\.\DEVICE\PATH") => "\\.\DEVICE"
:: URLref: [Naming Files, Paths, and Namespaces - MSDN] http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx @@ http://archive.is/EcTrM @@ http://webcitation.org/6IwYVd1Cn
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_split_drive_path_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval_drive="
set "_RETvar_drive=%~1"
set "_RETvar_path=%~2"
set "_path=%~3"
:_split_drive_path_of_START
if NOT DEFINED _path ( goto :_split_drive_path_of_RETURN )
if "%_path%" == "\\" ( goto :_split_drive_path_of_RETURN )
if NOT "%_path:~0,2%" == "\\" ( goto :_split_drive_path_of_NONUNC )
set "_RETval_drive=\\"
set "_path=%_path:~2%"
:_split_drive_path_of_TEST_1
if NOT "%_path:~0,6%" == "?\UNC\" ( goto :_split_drive_path_of_TEST_2 )
set "_path=\\%_path:~6%"
goto :_split_drive_path_of_UNC_LOOP
:_split_drive_path_of_TEST_2
if NOT "%_path:~0,2%" == "?\" ( goto :_split_drive_path_of_TEST_3 )
set "_path=%_path:~2%"
goto :_split_drive_path_of_START
:_split_drive_path_of_TEST_3
if NOT "%_path:~0,2%" == ".\" ( goto :_split_drive_path_of_TEST_4 )
set "_RETval_drive=\\.\"
set "_path=%_path:~2%"
:_split_drive_path_of_TEST_4
:_split_drive_path_of_UNC_LOOP
if NOT DEFINED _path ( goto :_split_drive_path_of_UNC_LOOP_DONE )
if "%_path:~0,1%" == "\" ( goto :_split_drive_path_of_UNC_LOOP_DONE )
set "_RETval_drive=%_RETval_drive%%_path:~0,1%"
set "_path=%_path:~1%"
goto :_split_drive_path_of_UNC_LOOP
:_split_drive_path_of_UNC_LOOP_DONE
goto :_split_drive_path_of_RETURN
:_split_drive_path_of_NONUNC
if NOT "%_path:~1,1%" == ":" ( goto :_split_drive_path_of_TEST_6 )
set "_RETval_drive=%_path:~0,2%"
set "_path=%_path:~2%"
goto :_split_drive_path_of_RETURN
:_split_drive_path_of_TEST_6
::set "_RETval_drive=%~d3"
:_split_drive_path_of_RETURN
call :_echo_DEBUG_KEY _RETvar_drive="%_RETvar_drive%"
call :_echo_DEBUG_KEY _RETval_drive="%_RETval_drive%"
call :_echo_DEBUG_KEY _RETvar_path="%_RETvar_path%"
call :_echo_DEBUG_KEY _RETval_path="%_path%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
:: return values via a single line with surrounding double-quotes; this is fine here, given double-quotes are illegal in NTFS filenames
endlocal & set "%_RETvar_drive%=%_RETval_drive%" & set "%_RETvar_path%=%_path%"
goto :EOF
::

::
:$$rtrim ( ref_RETURN ITEM [CHARSET] )
:$rtrim ( ref_RETURN ITEM [CHARSET] )
:_rtrim ( ref_RETURN ITEM [CHARSET] )
:: trim characters in CHARSET from right-side of ITEM
:: RETURN = ITEM with rightmost CHARSET characters removed
:: URLrefs: [Variable editing] http://ss64.com/nt/syntax-substring.html, [How to trim whitespace from a string] http://www.experts-exchange.com/OS/Microsoft_Operating_Systems/MS_DOS/Q_23816304.html
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_rtrim"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "item=%~2"
if 1.0 == 01 (
    set item=%@unquotes[%2]
    )
set "charset=%~3"
if 1.0 == 01 (
    set charset=%@unquotes[%3]
    )
if NOT DEFINED charset ( set "charset=  " )     &:: NOTE: default charset = " \t"
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY charset="%charset%"
:: change any internal double quotes to chr(255) (avoids syntax errors during the character comparison and removal process) [ NOTE: may have internal double quotes, so no outer quotes for set; this also creates a problem with internal ()'s if the set is enclosed in a block, so use a goto around it as needed]
if NOT DEFINED item ( goto :_rtrim_LOOP_ch )
set "item=%item:"=¸%"
set "charset=%charset:"=¸%"
set "chars=%charset%"
:_rtrim_LOOP_ch
call :_echo_DEBUG_KEY LOOP.item="%item%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY LOOP.chars="%chars%"
set "ch="
if DEFINED chars ( set "ch=%chars:~0,1%" & set "chars=%chars:~1%" )
if NOT DEFINED ch ( goto :_rtrim_LOOP_DONE )
:_rtrim_LOOP_removal
if NOT DEFINED item ( goto :_rtrim_LOOP_DONE )
set "last_ch="
if DEFINED item ( set "last_ch=%item:~-1%" )
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY ch="%ch%"
call :_echo_DEBUG_KEY last_ch="%last_ch%"
if /i "%last_ch%" == "%ch%" (
    set "item=%item:~0,-1%"
    set "chars=%charset%"
    goto :_rtrim_LOOP_removal
    )
goto :_rtrim_LOOP_ch
:_rtrim_LOOP_DONE
:_rtrim_RETURN
if NOT DEFINED item ( goto :_rtrim_RETURN_translate_DONE )
:: return any double quotes to ITEM
set item=%item:¸=^"%
:: " [balance double quote for editor parsing]
:_rtrim_RETURN_translate_DONE
set _RETval=%item%
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_N ( ref_RETURN PATH )
:$param_tilde_N ( ref_RETURN PATH )
:_param_tilde_N ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on (or has been forced onto) an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == name of PATH
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_N"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
if NOT DEFINED _RETval ( goto :_param_tilde_N_RETURN )
set "_RETval=%~n2"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
:_param_tilde_N_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$echo_DEBUG ( [ TEXT ... ] )
:$echo_DEBUG ( [ TEXT ... ] )
:_echo_DEBUG ( [ TEXT ... ] )
:: used to help avoid the CMD/TCC BUG which causes a script breaking error if ()'s (more specifically, closed parens) are found within an IF() block
:: NOTE: __DEBUG is GLOBAL to this function (and MUST be, because the shift command doesn't change subsequent %* uses {so, there is no way to pass vars into the function with arbitrary following TEXT})
if NOT DEFINED __DEBUG ( goto :_echo_DEBUG_RETURN )
if NOT DEFINED __MEfn ( goto :_echo_DEBUG_NO_MEFN )
echo %__ME%:%__MEfn%: {{DEBUG}} %*
goto :_echo_DEBUG_RETURN
:_echo_DEBUG_NO_MEFN
echo %__ME%: {{DEBUG}} %*
goto :_echo_DEBUG_RETURN
:_echo_DEBUG_RETURN
goto :EOF
::

::
:$$echo_DEBUG_KEY ( [ TEXT ... ] )
:$echo_DEBUG_KEY ( [ TEXT ... ] )
:_echo_DEBUG_KEY ( [ TEXT ... ] )
:: used to help avoid the CMD/TCC BUG which causes a script breaking error if ()'s (more specifically, closed parens) are found within an IF() block
:: NOTE: __DEBUG and __DEBUG_KEY are GLOBAL to this function (and MUST be, because the shift command doesn't change subsequent %* uses {so, there is no way to pass vars into the function with arbitrary following TEXT})
if NOT DEFINED __DEBUG ( goto :_echo_DEBUG_KEY_RETURN )
if NOT "%__DEBUG%" == "%__DEBUG_KEY%" ( goto :_echo_DEBUG_KEY_RETURN )
if NOT DEFINED __MEfn ( goto :_echo_DEBUG_KEY_NO_MEFN )
echo %__ME%:%__MEfn%: {{DEBUG: %__DEBUG%}} %*
goto :_echo_DEBUG_KEY_RETURN
:_echo_DEBUG_KEY_NO_MEFN
echo %__ME%: {{DEBUG: %__DEBUG%}} %*
goto :_echo_DEBUG_KEY_RETURN
:_echo_DEBUG_KEY_RETURN
goto :EOF
::

::
:$$echo_item_DEBUG_KEY ( DEBUG DEBUG_KEY ME MEfn ITEM )
:$echo_item_DEBUG_KEY ( DEBUG DEBUG_KEY ME MEfn ITEM )
:_echo_item_DEBUG_KEY ( DEBUG DEBUG_KEY ME MEfn ITEM )
:: used to help avoid the CMD/TCC BUG which causes a script breaking error if ()'s (more specifically, closed parens) are found within an IF() block
:: NOTE: using a single echo'd item allows passage of other vars into the function
setlocal
set __DEBUG=%~1
set __DEBUG_KEY=%~2
set __ME=%~3
set __MEfn=%~4
set item=%~5
@call :_echo_DEBUG_KEY %item%
:_echo_item_DEBUG_KEY_RETURN
endlocal
goto :EOF
::

:::: [ end of __PREinitialize section (contains all required function dependencies) ]

::
:$$is_same_command ( ref_RETURN FILENAME1 FILENAME2 )
:$is_same_command ( ref_RETURN FILENAME1 FILENAME2 )
:_is_same_command ( ref_RETURN FILENAME1 FILENAME2 )
:: determine if FILENAME1 is the same as FILENAME2
:: RETURN == (BOOLEAN as undef/1) whether FILENAMEs are the same
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_same_command"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
:: more than 3 ARGS implies multiple parts for FILENAME1 and/or FILENAME2 (therefore, NOT testable and defined as NOT the same)
call :_echo_DEBUG_KEY 4thARG?="%~4"
if NOT "%~4"=="" ( goto :_is_same_command_RETURN )
:: deal with NULL extensions (if both NULL, leave alone; otherwise, use the non-NULL extension for both)
set "_f2=%~2"
set "_f3=%~3"
if "%~x2"=="" ( call :_path_of_file_in_PATH _p2 "%_f2%" "%PATHEXT%" ) else ( call :_path_in_PATH _p2 "%_f2%" )
if "%~x3"=="" ( call :_path_of_file_in_PATH _p3 "%_f3%" "%PATHEXT%" ) else ( call :_path_in_PATH _p3 "%_f3%" )
call :_echo_DEBUG_KEY p2="%_p2%"
call :_echo_DEBUG_KEY p3="%_p3%"
if /i "%_p2%"=="%_p3%" ( set "_RETval=1" )
:_is_same_command_RETURN
call :_echo_DEBUG_KEY _RETvar="%~1"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
endlocal & set "%~1=%_RETval%"
goto :EOF
::

::
:$$is_similar_command ( ref_RETURN FILENAME1 FILENAME2 )
:$is_similar_command ( ref_RETURN FILENAME1 FILENAME2 )
:_is_similar_command ( ref_RETURN FILENAME1 FILENAME2 )
:: determine if FILENAME1 is similar to FILENAME2
:: RETURN == (BOOLEAN as undef/1) whether FILENAMEs are similar
:: NOTE: not _is_SAME_command; that entails parsing PATHEXT and concatenating each EXT for any argument with a NULL extension
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_similar_command"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
:: more than 3 ARGS implies multiple parts for FILENAME1 and/or FILENAME2 (therefore, NOT testable and defined as NOT the same)
if NOT "%~4"=="" ( goto :_is_similar_command_RETURN )
:: deal with NULL extensions (if both NULL, leave alone; otherwise, use the non-NULL extension for both)
set _EXT_2=%~x2
set _EXT_3=%~x3
if NOT "%_EXT_2%"=="%_EXT_3%" if "%_EXT_2%"=="" (
    call :_is_similar_command _RETval "%~2%_EXT_3%" "%~3"
    goto :_is_similar_command_RETURN
    )
if NOT "%_EXT_2%"=="%_EXT_3%" if "%_EXT_3%"=="" (
    call :_is_similar_command _RETval "%~2" "%~3%_EXT_2%"
    goto :_is_similar_command_RETURN
    )
::if /i "%~dnpx2"=="%~dnpx3" ( set "_RETval=1" )  &:: FAILS for shells executed with non-fully qualified paths (eg, subshells called with 'cmd.exe' or 'tcc')
if /i "%~$PATH:2"=="%~$PATH:3" ( set "_RETval=1" )
:_is_similar_command_RETURN
endlocal & set "%~1=%_RETval%"
goto :EOF
::

::
:$$is_exec_from_console ( ref_RETURN )
:$is_exec_from_console ( ref_RETURN )
:_is_exec_from_console ( ref_RETURN )
:: determine if script is being executed directly from the console window (rather than from an explorer)
:: RETURN == (BOOLEAN as undef/1) whether script is executed from console
:: NOTE: if %cmdcmdline% has multiple parts, the script is NOT under direct console execution [!! except for elevate or run `cmd /k ...`]
:: NOTE: ToDO: check for ...\CMD.exe or ...\CMD.exe /k [elevate or run] vs ...\CMD.exe /c [explorer or run]
:: NOTE:   ... elevate.x32.exe uses C:\Windows\SysWOW64\CMD.exe on 64-bit systems; deal with C:\Windows\System32\CMD.exe and C:\Windows\SysWOW64\CMD.exe
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_exec_from_console"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval=0"
set _RETvar=%~1
call :_is_same_command _RETval "%COMSPEC%" %cmdcmdline%
:_is_exec_from_console_RETURN
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_transient_shell ( ref_RETURN )
:$is_transient_shell ( ref_RETURN )
:_is_transient_shell ( ref_RETURN )
:: determine if script is being executed in a transient shell console window
:: RETURN == (BOOLEAN as undef/1) whether script is executed from console
:: NOTE: known possibilities: `...\CMD.exe`, `...\CMD.exe /k` [via elevate or run], `...\CMD.exe /c` [via explorer or run]
:: NOTE: 32-bit commands (eg, elevate.x32.exe) may see `C:\Windows\SysWOW64\CMD.exe` on 64-bit systems; deal with `C:\Windows\System32\CMD.exe` and `C:\Windows\SysWOW64\CMD.exe`
:: [CMD/TCC] /C == transient shell carries out the command specified by string and then terminates
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=$is_transient_console"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval=0"
set _RETvar=%~1
call :_create_list ccl_token_list %cmdcmdline%
call :_is_in_list _RETval "/c" "%ccl_token_list%"
:_is_transient_shell_RETURN
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_elevated ( ref_RETURN )
:$is_elevated ( ref_RETURN )
:_is_elevated ( ref_RETURN )
:: determine if script is operating under privilege elevation
:: RETURN == (BOOLEAN as undef/1) whether script has elevated permissions
:: NOTE: pre-VISTA OS do not have UAC limited permissions and are therefore always considered "elevated"
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_elevated"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set _RETvar=%~1
shift
::
set _RETval=1
call :_win_os_version _version_name _version_N
IF /i %_version_N% LSS 6 ( goto :_is_elevated_RETURN )
call :_is_UAC_elevated _RETval
::
:_is_elevated_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_UAC_elevated ( ref_RETURN )
:$is_UAC_elevated ( ref_RETURN )
:_is_UAC_elevated ( ref_RETURN )
:: elevation check
:: URLref: http://blogs.technet.com/jhoward/archive/2008/11/19/how-to-detect-uac-elevation-from-vbscript.aspx @@ https://archive.today/nS90V
:: URLref: http://stackoverflow.com/questions/7985755/how-to-detect-if-cmd-is-running-as-administrator-has-elevated-privileges
:: RETURN == (BOOLEAN as undef/1) whether script has UAC elevated permissions
:: if VISTA+, run %SystemRoot%/System32/whoami.exe /groups and check for "Mandatory Label\High Mandatory Level" - if missing -> NOT elevated
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_UAC_elevated"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set _RETvar=%~1
call :_win_os_version _version_name _version_N
IF /i %_version_N% LSS 6 ( goto :_is_UAC_elevated_RETURN )
call "%SystemRoot%\\System32\\whoami" /groups | call "%SystemRoot%\\System32\\FINDSTR" /IL /C:"Mandatory Label\High Mandatory Level" > NUL
IF %ERRORLEVEL% EQU 0 ( SET "_RETval=true" )
:_is_UAC_elevated_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$has_privilege ( ref_RETURN PRIV_NAME )
:$has_privilege ( ref_RETURN PRIV_NAME )
:_has_privilege ( ref_RETURN PRIV_NAME )
:: privilege check
:: URLref: http://stackoverflow.com/questions/11607389/how-to-view-user-privileges-using-windows-cmd
:: URLref: https://social.technet.microsoft.com/Forums/windowsserver/en-US/e24a35b3-fb72-4918-8e51-562e2ad8d8f5/what-is-the-state-column-returned-by-whoami-priv?forum=winserversecurity @@ https://archive.today/uZMlX
:: RETURN == (BOOLEAN as undef/1) whether script has privilege by the name PRIV_NAME
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_has_privilege"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set _RETvar=%~1
set priv_name=%~2 &:: privilege name to search
::call :_win_os_version _version_name _version_N
::IF /i %_version_N% LSS 6 ( goto :_is_UAC_elevated_RETURN )
call "%SystemRoot%\\System32\\whoami" /priv | call "%SystemRoot%\\System32\\FINDSTR" /IL /C:"%priv_name%" > NUL
IF %ERRORLEVEL% EQU 0 ( SET "_RETval=true" )
:_has_privilege_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_exit_pause_needed ( ref_PAUSE_FLAG [in/out] )
:$is_exit_pause_needed ( ref_PAUSE_FLAG [in/out] )
:_is_exit_pause_needed ( ref_PAUSE_FLAG [in/out] )
:: determine if a pause is needed before script exit (if called from explorer via a transient shell, etc)
:: PAUSE_FLAG may be preset to a value (0==false/non-0==true) prior to calling this function is called to allow executor control of pause on exit, overriding normal logic as noted here
:: %PAUSE_FLAG% == not defined :: normal logic, PAUSE needed if script executed in a transient console shell
:: %PAUSE_FLAG% == 0 :: override, no PAUSE needed
:: %PAUSE_FLAG% == "1, will pause at top level", no PAUSE needed in current or called scripts
:: %PAUSE_FLAG% == 1 or <OTHER> :: override, PAUSE needed, but set return value to signal value ("1, will pause at top level")
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_exit_pause_needed"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval=1, will pause at top level"
set _RETvar=%~1
call set _INPUT_PAUSE=%%%_RETvar%%%
if DEFINED _INPUT_PAUSE ( if /I "%_INPUT_PAUSE%"=="0" ( set "_RETval=0" & goto :_is_exit_pause_needed_RETURN ) )
if DEFINED _INPUT_PAUSE ( if /I "%_INPUT_PAUSE%"=="1, will pause at top level" ( set "_RETval=0" & goto :_is_exit_pause_needed_RETURN ) )
if DEFINED _INPUT_PAUSE ( goto :_is_exit_pause_needed_RETURN )
call :_is_transient_shell _TRANSIENT
if NOT DEFINED _TRANSIENT ( set "_RETval=0" )
:_is_exit_pause_needed_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY "%_RETvar%"="%_INPUT_PAUSE%"
call :_echo_DEBUG_KEY _TRANSIENT="%_TRANSIENT%"
call :_echo_DEBUG_KEY _is_exit_pause_needed="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$win_os_version ( ref_RETURN_NAME ref_RETURN_N [ref_RETURN_V] )
:$win_os_version ( ref_RETURN_NAME ref_RETURN_N [ref_RETURN_V] )
:_win_os_version ( ref_RETURN_NAME ref_RETURN_N [ref_RETURN_V] )
:: ToDO: add notes about continuing maintainence needs for increasing Windows versions
:: ToDO: make more robust: 1) check for existence of used EXEs; 2) check for earlier versions
:: ToDO: ? change "XP.x64" to "XP" with N_bit == "64"
:: ToDO: add _ARCH, _V, _V_b, _V_Mm as optional return values
:: find Windows OS version (for Windows versions from Windows 2000 on)
:: RETURN_NAME == current OS name ["7", "2008.R2", "2008", "Vista", "2003", "XP.x64", "XP", NULL]
:: RETURN_N == current OS version [ 0 == unknown ]
:: URLref: http://serverfault.com/questions/124848/using-systeminfo-to-get-the-os-name
:: URLref: http://stackoverflow.com/questions/1792740/how-to-tell-what-version-of-windows-and-or-cmd-exe-a-batch-file-is-running-on
:: URLref: http://pario.no/2011/06/19/list-installed-windows-updates-using-wmic @@ http://www.webcitation.org/66a7J58OK
:: URLref: http://tech-wreckblog.blogspot.com/2009/11/wmic-command-line-kung-fu.html @@ http://www.webcitation.org/66a7MbiGf
:: URLref: http://roddotnet.blogspot.com/2008/08/how-to-detect-windows-vista-in-batch.html
:: URLref: [MS Windows Version Numbers] http://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx @@ http://www.webcitation.org/66FzghSQU
:: URLref: http://malektips.com/xp_dos_0025.html @@ http://www.webcitation.org/66G00alzC
:: URLref: http://en.wikipedia.org/wiki/List_of_Microsoft_Windows_versions @@ https://archive.today/JtQ5J
:: NOTE: "systeminfo 2> nul" is used to avoid spurious progress output from systeminfo
:: ToDO: investigate use of "%SystemRoot%\System32\cmd.exe" /x/d/c "VER instead
:: ToDO: investigate improved efficiency if VER and systeminfo could be executed just once with value saved into a variable with "ECHO %VAR% | findstr ..."
:: ToDO: DONE: change to use wmic
:: NOTE: not using FOR ... in order to use this same function in Autorun :: might be able to use for ('cmd /d ...')
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_win_os_version"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval_NAME="
set _RETval_N=0
set _RETvar=%~1
shift
set _RETvar_N=%~1
shift
set _RETvar_V=%~1
:: get temp file
call :_tempfile _win_os_version_TEMPFILE "%__MEfn%" .txt
::*::
:: URLref: http://serverfault.com/questions/124848/using-systeminfo-to-get-the-os-name
:: URLref: http://stackoverflow.com/questions/1792740/how-to-tell-what-version-of-windows-and-or-cmd-exe-a-batch-file-is-running-on
:: URLref: http://pario.no/2011/06/19/list-installed-windows-updates-using-wmic @@ http://www.webcitation.org/66a7J58OK
:: URLref: http://tech-wreckblog.blogspot.com/2009/11/wmic-command-line-kung-fu.html @@ http://www.webcitation.org/66a7MbiGf
::
:: default values for unknown windows version: version=NULL
SET _win_os_version=
SET _win_os_version_ARCH=32
SET _win_os_version_N=0
SET _win_os_version_FIND=%SystemRoot%\\System32\\FINDSTR
SET _win_os_version_INFO=%SystemRoot%\\System32\\WBEM\\wmic
"%SystemRoot%\System32\cmd.exe" /x/d/c "echo. | call "%_win_os_version_INFO%" os get osarchitecture /format:value 2> NUL | call "%_win_os_version_FIND%" /IR /C:"OSArchitecture=64.*" > NUL"
IF "%ERRORLEVEL%" == "0" (
    SET "_win_os_version_ARCH=64"
    )
"%SystemRoot%\System32\cmd.exe" /x/d/c "VER | call "%_win_os_version_FIND%" /IR /C:"Version *" > "%_win_os_version_TEMPFILE%""
set /p _win_os_version_CMDver= < "%_win_os_version_TEMPFILE%" > NUL
for /f "usebackq tokens=2 delims=[]" %%G in ('%_win_os_version_CMDver%') do set _win_os_version_V=%%G
set _win_os_version_V=%_win_os_version_V:Version =%
for /f "usebackq tokens=1,2,3* delims=." %%G in ('%_win_os_version_V%') do (
        set _win_os_version_N=%%G
        set _win_os_version_V_Mm=%%G.%%H
        set _win_os_version_V_b=%%I
        )
:_win_os_version_check_5_0
if NOT "%_win_os_version_V_Mm%" == "5.0" ( goto :_win_os_version_check_5_0_DONE )
:: : Windows 2000
SET "_win_os_version=2000"
goto :_win_os_version_FOUND
:_win_os_version_check_5_0_DONE
:_win_os_version_check_5_1
if NOT "%_win_os_version_V_Mm%" == "5.1" ( goto :_win_os_version_check_5_1_DONE )
:: : Windows XP
SET "_win_os_version=XP"
goto :_win_os_version_FOUND
:_win_os_version_check_5_1_DONE
:_win_os_version_check_5_2
if NOT "%_win_os_version_V_Mm%" == "5.2" ( goto :_win_os_version_check_5_2_DONE )
:: : Windows Server 2003 & Windows XP 64-bit
SET "_win_os_version=2003"
"%SystemRoot%\System32\cmd.exe" /x/d/c "echo. | call "%_win_os_version_INFO%" os get caption /format:value 2> NUL | call "%_win_os_version_FIND%" /IR /C:"Caption=.*Windows.XP.*" > NUL"
IF "%ERRORLEVEL%" == "0" (
    SET "_win_os_version=XP.x64"
    )
goto :_win_os_version_FOUND
:_win_os_version_check_5_2_DONE
:_win_os_version_check_6_0
if NOT "%_win_os_version_V_Mm%" == "6.0" ( goto :_win_os_version_check_6_0_DONE )
:: : Windows Vista & Windows Server 2008
SET "_win_os_version=Vista"
"%SystemRoot%\System32\cmd.exe" /x/d/c "echo. | call "%_win_os_version_INFO%" os get caption /format:value 2> NUL | call "%_win_os_version_FIND%" /IR /C:"Caption=.*Server.*" > NUL"
IF "%ERRORLEVEL%" == "0" (
    SET "_win_os_version=2008"
    )
goto :_win_os_version_FOUND
:_win_os_version_check_6_0_DONE
:_win_os_version_check_6_1
if NOT "%_win_os_version_V_Mm%" == "6.1" ( goto :_win_os_version_check_6_1_DONE )
:: : Windows 7 & Windows Server 2008 R2
SET "_win_os_version=7"
"%SystemRoot%\System32\cmd.exe" /x/d/c "echo. | call "%_win_os_version_INFO%" os get caption /format:value 2> NUL | call "%_win_os_version_FIND%" /IR /C:"Caption=.*Server.*" > NUL"
IF "%ERRORLEVEL%" == "0" (
    SET "_win_os_version=2008.R2"
    )
goto :_win_os_version_FOUND
:_win_os_version_check_6_1_DONE
:_win_os_version_check_6_2
if NOT "%_win_os_version_V_Mm%" == "6.2" ( goto :_win_os_version_check_6_2_DONE )
:: : Windows 8 & Windows Server 2012
SET "_win_os_version=8"
"%SystemRoot%\System32\cmd.exe" /x/d/c "echo. | call "%_win_os_version_INFO%" os get caption /format:value 2> NUL | call "%_win_os_version_FIND%" /IR /C:"Caption=.*Server.*" > NUL"
IF "%ERRORLEVEL%" == "0" (
    SET "_win_os_version=2012"
    )
goto :_win_os_version_FOUND
:_win_os_version_check_6_2_DONE
:_win_os_version_check_6_3
if NOT "%_win_os_version_V_Mm%" == "6.3" ( goto :_win_os_version_check_6_3_DONE )
:: : Windows 8.1 & Windows Server 2012 R2
SET "_win_os_version=8.1"
"%SystemRoot%\System32\cmd.exe" /x/d/c "echo. | call "%_win_os_version_INFO%" os get caption /format:value 2> NUL | call "%_win_os_version_FIND%" /IR /C:"Caption=.*Server.2008.R2.*" > NUL"
IF "%ERRORLEVEL%" == "0" (
    SET "_win_os_version=2012.R2"
    )
goto :_win_os_version_FOUND
:_win_os_version_check_6_3_DONE
:_win_os_version_check_6_4
if NOT "%_win_os_version_V_Mm%" == "6.4" ( goto :_win_os_version_check_6_4_DONE )
:: : Windows 10
SET "_win_os_version=10"
goto :_win_os_version_FOUND
:_win_os_version_check_6_4_DONE
:_win_os_version_check_10
if NOT "%_win_os_version_V_Mm%" == "10.0" ( goto :_win_os_version_check_10_0_DONE )
:: : Windows 10
SET "_win_os_version=10"
goto :_win_os_version_FOUND
:_win_os_version_check_10_0_DONE
:_win_os_version_check_11+
:: : Windows 11+
SET "_win_os_version=11+"
goto :_win_os_version_FOUND
:_win_os_version_check_11+_DONE
:_win_os_version_FIND_DONE
:_win_os_version_FOUND
::*::
:_win_os_version_RETURN
if EXIST "%_win_os_version_TEMPFILE%" ( erase "%_win_os_version_TEMPFILE%" > NUL )
call :_echo_DEBUG_KEY _win_os_version="%_win_os_version%"
call :_echo_DEBUG_KEY _win_os_version_N="%_win_os_version_N%"
::( endlocal
::  ( if NOT 1.0 == 1 (set "%_RETvar%=%_win_os_version%" & set "%_RETvar_N%=%_win_os_version_N%"
::          ) else (set "%_RETvar=%_win_os_version" & set "%_RETvar_N=%_win_os_version_N"
::              )
::      )
::@rem :::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
( endlocal
set %_RETvar%^=%_win_os_version%
set %_RETvar_N%^=%_win_os_version_N%
if NOT "%_RETvar_V%"=="" (set %_RETvar_V%^=%_win_os_version_V%)
)
goto :EOF
::

::
:$$echo_noLF ( [ TEXT ] )
:$echo_noLF ( [ TEXT ] )
:_echo_noLF ( [ TEXT ] )
setlocal
if 01 == 1.0 ( goto :_echo_noLF_TCC )
:_echo_noLF_CMD
set /p _OUTPUT=%*<nul
goto :_echo_noLF_RETURN
:_echo_noLF_TCC
echos %*
goto :_echo_noLF_RETURN
:_echo_noLF_RETURN
endlocal
goto :EOF
::

::
:$$echo_VERBOSE ( [ TEXT ... ] )
:: NOTE: __VERBOSE is GLOBAL to this function (and MUST be, because the shift command doesn't change subsequent %* uses {so, there is no way to pass vars into the function with arbitrary following TEXT})
if NOT DEFINED __VERBOSE ( goto :_echo_VERBOSE_RETURN )
echo %__ME%: %*
goto :_echo_VERBOSE_RETURN
:_echo_VERBOSE_RETURN
goto :EOF
::

::
:$$simple_dequote ( ref_RETURN ITEM )
:$simple_dequote ( ref_RETURN ITEM )
:_simple_dequote ( ref_RETURN ITEM )
:: strip outer double quotes from ITEM (NO attempt to check for or remove balanced quotes)
:: RETURN = dequoted ITEM
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_simple_dequote"
set "_RETvar=%~1"
set "_RETval=%~2"
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$length_of ( ref_RETURN ITEM )
:$length_of ( ref_RETURN ITEM )
:_length_of ( ref_RETURN ITEM )
:: determine length of ITEM
:: RETURN = length of ITEM
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_length_of"
set "_RETvar=%~1"
set "item=%~2"
set length=0
:_length_of_LOOP
if DEFINED item (
    set item=%item:~1%
    set /a length += 1
    goto :_length_of_LOOP
)
:_length_of_RETURN
set "_RETval=%length%"
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$trim ( ref_RETURN ITEM CHARSET )
:$trim ( ref_RETURN ITEM CHARSET )
:_trim ( ref_RETURN ITEM CHARSET )
:: trim characters from ITEM
:: RETURN == ITEM with CHARSET characters removed (from both sides)
:: NOTE: CHARSET defaults to "<SPACE><TAB>" if NULL/missing
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_trim"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if 1.0 == 01 (
    set _RETval=%@unquotes[%2]
    )
set "charset=%~3"
if 1.0 == 01 (
    set charset=%@unquotes[%3]
    )
if NOT DEFINED charset ( set "charset=  " )
call :_echo_DEBUG_KEY _RETVal/item="%_RETval%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_ltrim _RETval "%_RETval%" "%charset%"
call :_rtrim _RETval "%_RETval%" "%charset%"
:_trim_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$ltrim ( ref_RETURN ITEM [CHARSET] )
:$ltrim ( ref_RETURN ITEM [CHARSET] )
:_ltrim ( ref_RETURN ITEM [CHARSET] )
:: trim characters in CHARSET from left-side of ITEM
:: RETURN = ITEM with leftmost CHARSET characters removed
:: NOTE: CHARSET defaults to "<SPACE><TAB>" if NULL/missing
:: URLrefs: [Variable editing] http://ss64.com/nt/syntax-substring.html, [How to trim whitespace from a string] http://www.experts-exchange.com/OS/Microsoft_Operating_Systems/MS_DOS/Q_23816304.html
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_ltrim"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "item=%~2"
if 1.0 == 01 (
    set item=%@unquotes[%2]
    )
set "charset=%~3"
if 1.0 == 01 (
    set charset=%@unquotes[%3]
    )
if NOT DEFINED charset ( set "charset=  " )     &:: NOTE: default charset = " \t"
call :_echo_DEBUG_KEY *={%*}
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY charset="%charset%"
:: change any internal double quotes to chr(255) (avoids syntax errors during the character comparison and removal process) [ NOTE: may have internal double quotes, so no outer quotes for set; this also creates a problem with internal ()'s if the set is enclosed in a block, so use a goto around it as needed]
if NOT DEFINED item ( goto :_ltrim_LOOP_ch )
set "item=%item:"=¸%"
set "charset=%charset:"=¸%"
set "chars=%charset%"
call :_echo_DEBUG_KEY LOOP.item="%item%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY LOOP.chars="%chars%"
:_ltrim_LOOP_ch
set "ch="
if DEFINED chars ( set "ch=%chars:~0,1%" & set "chars=%chars:~1%" )
if NOT DEFINED ch ( goto :_ltrim_LOOP_DONE )
:_ltrim_LOOP_removal
if NOT DEFINED item ( goto :_ltrim_LOOP_DONE )
set "first_ch="
if DEFINED item (
    set "first_ch=%item:~0,1%"
    )
call :_echo_DEBUG_KEY LOOP.item="%item%"
call :_echo_DEBUG_KEY LOOP.item.first_ch="%first_ch%"
if /i "%first_ch%" == "%ch%" (
    set "item=%item:~1%"
    set "chars=%charset%"
    goto :_ltrim_LOOP_removal
    )
goto :_ltrim_LOOP_ch
:_ltrim_LOOP_DONE
:_ltrim_RETURN
if NOT DEFINED item ( goto :_ltrim_RETURN_translate_DONE )
:: return any double quotes to ITEM
set item=%item:¸=^"%
:_ltrim_RETURN_translate_DONE
set _RETval=%item%
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$translate_charset ( ref_RETURN ITEM CHARSET TRANS )
:$translate_charset ( ref_RETURN ITEM CHARSET TRANS )
:_translate_charset ( ref_RETURN ITEM CHARSET TRANS )
:: change all CHARSET characters to TRANS in ITEM
:: RETURN = ITEM with all characters in CHARSET changed to TRANS
:: NOTE: ITEM should have no internal double quotes; if present, double quotes are translated to single quotes(? TRUE, ?needed for CMD or TCC?) for the RETURN value
setlocal
set "__DEBUG_KEY=@1"
set "__MEfn=translate_charset"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "item=%~2"
set "charset_init=%~3"
set "trans=%~4"
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY trans="%trans%"
:: change any internal double quotes to chr(255) (avoids syntax errors during the character comparison and removal process) [ NOTE: may have internal double quotes, so no outer quotes for set; this also creates a problem with internal ()'s if the set is enclosed in a block, so use a goto around it as needed]
if NOT DEFINED item ( goto :_translate_charset_LOOP_ch )
set "item=%item:^"=¸%"
::
:translate_charset_LOOP
set "item_dest="
:_translate_charset_LOOP_item
if NOT DEFINED item ( goto :_translate_charset_LOOP_item_DONE )
set "first_ch=%item:~0,1%"
set "item=%item:~1%"
set "charset=%charset_init%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY first_ch="%first_ch%"
:_translate_charset_LOOP_ch
set "ch="
if DEFINED charset ( set "ch=%charset:~0,1%" & set "charset=%charset:~1%" )
if NOT DEFINED ch ( goto :_translate_charset_LOOP_ch_DONE )
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY ch="%ch%"
:_translate_charset_LOOP_change
if NOT "%first_ch%" == "%ch%" ( goto :_translate_charset_LOOP_ch )
set "item_dest=%item_dest%%trans%"
goto :_translate_charset_LOOP_item
:_translate_charset_LOOP_ch_DONE
set "item_dest=%item_dest%%first_ch%"
goto :_translate_charset_LOOP_item
:_translate_charset_LOOP_item_DONE
set "item=%item_dest%"
call :_echo_DEBUG_KEY item="%item%"
:_translate_charset_LOOP_DONE
::
:_translate_charset_RETURN
:: return any double quotes to ITEM
set "item=%item:¸=^"%"
set "_RETval=%item%"
call :_echo_DEBUG_KEY _RETVAL="%_RETVAL%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$translate_charset_nocase ( ref_RETURN ITEM CHARSET TRANS )
:$translate_charset_nocase ( ref_RETURN ITEM CHARSET TRANS )
:_translate_charset_nocase ( ref_RETURN ITEM CHARSET TRANS )
:: change all CHARSET characters to TRANS in ITEM
:: RETURN = ITEM with all characters in CHARSET changed to TRANS
:: NOTE: ITEM should have no internal double quotes; if present, double quotes are translated to single quotes(? TRUE, ?needed for CMD or TCC?) for the RETURN value
setlocal
set "__DEBUG_KEY=@1"
set "__MEfn=translate_charset_nocase"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "item=%~2"
set "charset_init=%~3"
set "trans=%~4"
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY trans="%trans%"
:: change any internal double quotes to chr(255) (avoids syntax errors during the character comparison and removal process) [ NOTE: may have internal double quotes, so no outer quotes for set; this also creates a problem with internal ()'s if the set is enclosed in a block, so use a goto around it as needed]
if NOT DEFINED item ( goto :_translate_charset_nocase_LOOP_ch )
set "item=%item:^"=¸%"
::
:translate_charset_LOOP
set "item_dest="
:_translate_charset_nocase_LOOP_item
if NOT DEFINED item ( goto :_translate_charset_nocase_LOOP_item_DONE )
set "first_ch=%item:~0,1%"
set "item=%item:~1%"
set "charset=%charset_init%"
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY first_ch="%first_ch%"
:_translate_charset_nocase_LOOP_ch
set "ch="
if DEFINED charset ( set "ch=%charset:~0,1%" & set "charset=%charset:~1%" )
if NOT DEFINED ch ( goto :_translate_charset_nocase_LOOP_ch_DONE )
call :_echo_DEBUG_KEY charset="%charset%"
call :_echo_DEBUG_KEY ch="%ch%"
:_translate_charset_nocase_LOOP_change
if /i "%first_ch%" NEQ "%ch%" ( goto :_translate_charset_nocase_LOOP_ch )
set "item_dest=%item_dest%%trans%"
goto :_translate_charset_nocase_LOOP_item
:_translate_charset_nocase_LOOP_ch_DONE
set "item_dest=%item_dest%%first_ch%"
goto :_translate_charset_nocase_LOOP_item
:_translate_charset_nocase_LOOP_item_DONE
set "item=%item_dest%"
call :_echo_DEBUG_KEY item="%item%"
:_translate_charset_nocase_LOOP_DONE
::
:_translate_charset_nocase_RETURN
:: return any double quotes to ITEM
set "item=%item:¸=^"%"
set "_RETval=%item%"
call :_echo_DEBUG_KEY _RETVAL="%_RETVAL%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_matching_item ( ref_RETURN ITEM_X [ ITEMs ... ] )
:$is_matching_item ( ref_RETURN ITEM_X [ ITEMs ... ] )
:_is_matching_item ( ref_RETURN ITEM_X [ ITEMs ... ] )
:: determine if ITEM_X matched any of the ITEMs
:: RETURN == false/true (aka ITEM# [1+]) [ false == NULL, true == 1+ ]
:: NOTE: NULL items as "" or """" are supported
:: NOTE: ITEM comparisons are case-independent
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_matching_item"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
shift
set "item_x=%~1"
if "%item_x%" EQU """" ( set "item_x=" )
set "item_n=0"
call :_echo_DEBUG_KEY item_n="%item_n%"
:_is_matching_item_LOOP
shift
set item_raw=%1
call :_echo_DEBUG_KEY item_raw='%item_raw%'
if NOT DEFINED item_raw ( set "item_n=" & goto :_is_matching_item_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
set /a item_n += 1 > nul
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY item_n="%item_n%"
if DEFINED item_raw ( if /I "%item%" NEQ "%item_x%" ( goto :_is_matching_item_LOOP ) )
:_is_matching_item_LOOP_DONE
:_is_matching_item_RETURN
set "_RETval=%item_n%"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
call :_echo_DEBUG_KEY [ %__MEfn% :: done ]
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$remove_matching_item ( ref_RETURN ITEM_X [ ITEMs ... ] )
:$remove_matching_item ( ref_RETURN ITEM_X [ ITEMs ... ] )
:_remove_matching_item ( ref_RETURN ITEM_X [ ITEMs ... ] )
:: remove ITEM_X from list of ITEMs
:: RETURN == SET of ITEMs with ITEM_X removed (all occurances)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_remove_matching_item"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
shift
set "item_x=%~1"
if "%item_x%" EQU """" ( set "item_x=" )
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
call :_echo_DEBUG_KEY item_x="%item_x%"
:_remove_matching_item_LOOP
shift
set item_raw=%1
call :_echo_DEBUG_KEY item_raw="%item_raw%"
if NOT DEFINED item_raw ( goto :_remove_matching_item_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
call :_echo_DEBUG_KEY item="%item%"
if /I "%item%" NEQ "%item_x%" ( call :_append_to_list _RETval "%item%" "%_RETval%" )
call :_echo_DEBUG_KEY _RETval="%_RETval%"
goto :_remove_matching_item_LOOP
:_remove_matching_item_LOOP_DONE
:_remove_matching_item_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$create_list_without_NULLs ( ref_RETURN [ ITEMs ... ] )
:$$create_list ( ref_RETURN [ ITEMs ... ] )
:$create_list ( ref_RETURN [ ITEMs ... ] )
:_create_list ( ref_RETURN [ ITEMs ... ] )
:: RETURN == LIST of ITEMs
setlocal
set "__DEBUG_KEY=@c"
set "__MEfn=_create_list"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:_create_list_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :_create_list_LOOP_DONE )
set item=%~1
if "%item%" EQU """" ( set "item=" )
call :_echo_DEBUG_KEY item_N="%item%"
if NOT DEFINED _RETval (
    set "_RETval=%item%"
    ) else (
    set "_RETval=%_RETval%;%item%"
    )
goto :_create_list_LOOP
:_create_list_LOOP_DONE
:_create_list_RETURN
if NOT DEFINED _RETval ( set "_RETval=""" )
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$create_list_with_NULLs ( ref_RETURN [ ITEMs ... ] )
:$create_list_with_NULLs ( ref_RETURN [ ITEMs ... ] )
:_create_list_with_NULLs ( ref_RETURN [ ITEMs ... ] )
:: RETURN == LIST of ITEMs
setlocal
set "__DEBUG_KEY=@c"
set "__MEfn=_create_list_with_NULLs"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "last_item_NULL="
:_create_list_with_NULLs_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :_create_list_with_NULLs_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
call :_echo_DEBUG_KEY item_N="%item%"
if NOT DEFINED _RETval (
    if DEFINED last_item_NULL (
        set "_RETval=%_RETval%;%item%"
        ) else (
        set "_RETval=%item%"
        )
    ) else (
    set "_RETval=%_RETval%;%item%"
    )
set "last_item_NULL="
if NOT DEFINED item ( set "last_item_NULL=1" )
goto :_create_list_with_NULLs_LOOP
:_create_list_with_NULLs_LOOP_DONE
:_create_list_with_NULLs_RETURN
if NOT DEFINED _RETval ( set "_RETval=""" )
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$list_to_items ( ref_RETURN LIST )
:: return separated LIST elements
:: RETURN == separated LIST ITEM elements
setlocal
set "_RETval="
set "_RETvar=%~1"
set "list=%~2"
if NOT DEFINED list ( goto :$$list_to_items_DONE )
call :_first_of arg "%list%"
call :_remove_first list "%list%"
call :$$count_of_items N %arg%
if NOT "%N%"=="1" set arg="%arg%"
set _RETval=%arg%
:$$list_to_items_LOOP
if NOT DEFINED list ( goto :$$list_to_items_DONE )
call :_first_of arg "%list%"
call :_remove_first list "%list%"
call :$$count_of_items N %arg%
if NOT "%N%"=="1" set arg="%arg%"
set _RETval=%_RETval% %arg%
goto :$$list_to_items_LOOP
:$$list_to_items_DONE
:$$list_to_items_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$count_of ( ref_RETURN [ LIST ] )
:: return number of ITEMs within LIST
:: RETURN == number of ITEM(s) within LIST
setlocal
set "_RETval=0"
set "_RETvar=%~1"
set "list=%~2"
call :$$count_of_items _RETval "%list:;=" "%"
:$$count_of_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$count_of_items ( ref_RETURN [ ITEMs ... ] )
:: return separated LIST elements
:: RETURN == number of ITEM(s)
setlocal
set "_RETval=0"
set "_RETvar=%~1"
:$$count_of_items_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :$$count_of_items_LOOP_DONE )
set /a _RETval += 1
goto :$$count_of_items_LOOP
:$$count_of_items_LOOP_DONE
:$$count_of_items_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_in_list ( ref_RETURN ITEM LIST )
:$is_in_list ( ref_RETURN ITEM LIST )
:_is_in_list ( ref_RETURN ITEM LIST )
:: determine if ITEM is within LIST
:: RETURN == (BOOLEAN: undef/1+ (ITEM# [1+])) whether ITEM is contained within the LIST
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_in_list"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set _RETvar=%~1
set "list=%~3"
set "item=%~2"
call :_echo_DEBUG_KEY list="%list%"
call :_echo_DEBUG_KEY item="%item%"
if DEFINED list ( call :_is_matching_item _RETval "%item%" "%list:;=" "%" )
:_is_in_list_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$prepend_to_list ( ref_RETURN ITEM LIST )
:$prepend_to_list ( ref_RETURN ITEM LIST )
:_prepend_to_list ( ref_RETURN ITEM LIST )
:: RETURN == LIST with ITEM prepended
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_prepend_to_list"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
set list=%~3
set item=%~2
if "%item%" EQU """" ( set "item=" )
set "_RETval=%item%"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
call :_echo_DEBUG_KEY list="%list%"
call :_echo_DEBUG_KEY item="%item%"
if NOT DEFINED list ( goto :_prepend_to_list_RETURN )
if "%list%" EQU """" ( set "list=" )
set "_RETval=%item%;%list%"
call :_echo_DEBUG_KEY 2
:_prepend_to_list_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
if NOT DEFINED _RETval ( set "_RETval=""" )
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$append_to_list ( ref_RETURN ITEM LIST )
:$append_to_list ( ref_RETURN ITEM LIST )
:_append_to_list ( ref_RETURN ITEM LIST )
:: RETURN == LIST with ITEM appended
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_append_to_list"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
set "list=%~3"
set "item=%~2"
if "%item%" EQU """" ( set "item=" )
set "_RETval=%item%"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY list="%list%"
call :_echo_DEBUG_KEY item="%item%"
if NOT DEFINED list ( goto :_append_to_list_RETURN )
if "%list%" EQU """" ( set "list=" )
set "_RETval=%list%;%item%"
:_append_to_list_RETURN
if NOT DEFINED _RETval ( set "_RETval=""" )
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$prepend_to_set ( ref_RETURN ITEM SET )
:$prepend_to_set ( ref_RETURN ITEM SET )
:_prepend_to_set ( ref_RETURN ITEM SET )
:: RETURN == SET/LIST with ITEM prepended (if not already in SET/LIST)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_prepend_to_set"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
set list=%~3
set item=%~2
set _RETval=%list%
call :_echo_DEBUG_KEY list="%list%"
call :_echo_DEBUG_KEY item="%item%"
call :_is_in_list IN_list "%item%" "%list%"
call :_echo_DEBUG_KEY 1
if NOT DEFINED IN_list ( call :_prepend_to_list _RETval "%item%" "%list%" )
:_prepend_to_set_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$append_to_set ( ref_RETURN ITEM SET )
:$append_to_set ( ref_RETURN ITEM SET )
:_append_to_set ( ref_RETURN ITEM SET )
:: RETURN == SET/LIST with ITEM appended (if not already in SET/LIST)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_append_to_set"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
set "list=%~3"
set "item=%~2"
set "_RETval=%list%"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY list="%list%"
call :_echo_DEBUG_KEY item="%item%"
call :_is_in_list IN_list "%item%" "%list%"
call :_echo_DEBUG_KEY IN_list="%IN_list%"
if NOT DEFINED IN_list ( call :_append_to_list _RETval "%item%" "%list%" )
:_append_to_set_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$prepend_to_pathlist ( ref_RETURN ITEM PATHLIST )
:$prepend_to_pathlist ( ref_RETURN ITEM PATHLIST )
:_prepend_to_pathlist ( ref_RETURN ITEM PATHLIST )
:: NOTE: PATHLIST is treated as a SET of PATHs
:: RETURN == PATHLIST with ITEM prepended (if not already in PATHLIST)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_prepend_to_pathlist"
set _RETvar=%~1
set list=%~3
set item=%~2
if "%item%" EQU """" ( set "item=" )
call :_rtrim item "%item%" "\"
set _RETval=%list%
if DEFINED item ( call :_prepend_to_set _RETval "%item%" "%list%" )
:_prepend_to_pathlist_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$append_to_pathlist ( ref_RETURN ITEM PATHLIST )
:$append_to_pathlist ( ref_RETURN ITEM PATHLIST )
:_append_to_pathlist ( ref_RETURN ITEM PATHLIST )
:: NOTE: PATHLIST is treated as a SET of PATHs
:: RETURN == PATHLIST with ITEM appended (if not already in PATHLIST)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_append_to_pathlist"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
set "list=%~3"
set "item=%~2"
if "%item%" EQU """" ( set "item=" )
call :_rtrim item "%item%" "\"
set "_RETval=%list%"
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY list="%list%"
if DEFINED item ( call :_append_to_set _RETval "%item%" "%list%" )
:_append_to_pathlist_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$remove_from_list ( ref_RETURN ITEM LIST )
:$remove_from_list ( ref_RETURN ITEM LIST )
:_remove_from_list ( ref_RETURN ITEM LIST )
:: RETURN == LIST with ITEM removed (all occurances)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_remove_from_list"
set "_RETval="
set _RETvar=%~1
set "list=%~3"
set "item=%~2"
if DEFINED list ( call :_remove_matching_item _RETval "%item%" "%list:;=" "%" )
:_remove_from_list_RETURN
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$create_pathlist ( ref_RETURN [ ITEMs ... ] )
:$create_pathlist ( ref_RETURN [ ITEMs ... ] )
:_create_pathlist ( ref_RETURN [ ITEMs ... ] )
:: NOTE: PATHLIST is a SET of PATHs (no NULL PATHs; PATHs are normalized ITEMs [no trailing backslashes] )
:: RETURN == PATHLIST of PATHs
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_create_pathlist"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval="
:_create_pathlist_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :_create_pathlist_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
call :_rtrim item "%item%" "\"
call :_append_to_pathlist _RETval "%item%" "%_RETval%"
goto :_create_pathlist_LOOP
:_create_pathlist_LOOP_DONE
:_create_pathlist_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$create_set ( ref_RETURN [ ITEMs ... ] )
:$create_set ( ref_RETURN [ ITEMs ... ] )
:_create_set ( ref_RETURN [ ITEMs ... ] )
:: NOTE: SET is a LIST of ITEMs (with no repeated ITEMs)
:: RETURN == SET of ITEMs
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_create_set"
set "_RETvar=%~1"
set "_RETval="
:_create_set_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :_create_set_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
call :_append_to_set _RETval "%item%" "%_RETval%"
goto :_create_set_LOOP
:_create_set_LOOP_DONE
:_create_set_RETURN
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$first_of ( ref_RETURN LIST )
:$first_of ( ref_RETURN LIST )
:_first_of ( ref_RETURN LIST )
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_first_of"
set "_RETval="
set _RETvar=%~1
set "list=%~2"
if DEFINED list ( call :_first_of_items _RETval "%list:;=" "%" )
:_first_of_RETURN
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$first_of_items ( ref_RETURN [ ITEMs ... ] )
:$first_of_items ( ref_RETURN [ ITEMs ... ] )
:_first_of_items ( ref_RETURN [ ITEMs ... ] )
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_first_of_items"
set _RETvar=%~1
set "item=%~2"
if "%item%" == """" ( set "item=" )
:_first_of_items_RETURN
set "_RETval=%item%"
::endlocal & if NOT 01 == 1.0 (set "%_RETvar%=%_RETval%") else (set "%_RETvar=%_RETval")
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$remove_first_item ( ref_RETURN [ ITEMs ... ] )
:$remove_first_item ( ref_RETURN [ ITEMs ... ] )
:_remove_first_item ( ref_RETURN [ ITEMs ... ] )
:: RETURN == LIST of all ITEMs excepting the initial ITEM
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_remove_first_item"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
shift
:_remove_first_item_LOOP
shift
set item_raw=%1
call :_echo_DEBUG_KEY item_raw="%item_raw%"
if NOT DEFINED item_raw ( goto :_remove_first_item_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
call :_echo_DEBUG_KEY item="%item%"
call :_append_to_list _RETval "%item%" "%_RETval%"
goto :_remove_first_item_LOOP
:_remove_first_item_LOOP_DONE
:_remove_first_item_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$remove_first ( ref_RETURN LIST )
:$remove_first ( ref_RETURN LIST )
:_remove_first ( ref_RETURN LIST )
:: RETURN == LIST with first ITEM removed
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_remove_first"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "list=%~2"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY list="%list%"
if DEFINED list ( call :_remove_first_item _RETval "%list:;=" "%" )
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$first_list_match ( ref_RETURN LIST1 LIST2 )
:$first_list_match ( ref_RETURN LIST1 LIST2 )
:_first_list_match ( ref_RETURN LIST1 LIST2 )
:: RETURN == first ITEM in LIST1 which is also contained in LIST2
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_first_list_match"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "list1=%~2"
set "list2=%~3"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY list1="%list1%"
call :_echo_DEBUG_KEY list2="%list2%"
:_first_list_match_LOOP
if NOT DEFINED list1 ( goto :_first_list_match_RETURN )
call :_first_of item "%list1%"
call :_remove_first list1 "%list1%"
call :_echo_DEBUG_KEY item="%item%"
call :_echo_DEBUG_KEY list="%list%"
call :_is_in_list IS_match "%item%" "%list2%"
if NOT DEFINED IS_match ( goto :_first_list_match_LOOP )
set "_RETval=%item%"
:_first_list_match_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$path_in_pathlist ( ref_RETURN FILENAME PATHLIST )
:$path_in_pathlist ( ref_RETURN FILENAME PATHLIST )
:_path_in_pathlist ( ref_RETURN FILENAME PATHLIST )
:: NOTE: FILENAME should be a simple filename, not a directory or filename with leading directory prefix. CMD will match these more complex paths, but TCC will not.
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_in_pathlist"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "pathlist=%~3"
set "PATH=%pathlist%"
call :_echo_DEBUG_KEY ref_RETURN="%~1"
call :_echo_DEBUG_KEY filename="%~2"
call :_echo_DEBUG_KEY pathlist="%pathlist%"
::call :_path_of_file_in_paths _RETval "%~2" "%pathlist:;=" "%"
set "_RETval=%~$PATH:2"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
:_path_in_pathlist_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$path_in_PATH ( ref_RETURN FILENAME )
:$path_in_PATH ( ref_RETURN FILENAME )
:_path_in_PATH ( ref_RETURN FILENAME )
:: NOTE: FILENAME should be a simple filename, not a directory or filename with leading directory prefix. CMD will match these more complex paths, but TCC will not.
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_in_PATH"
set "_RETvar=%~1"
call :_path_in_pathlist _RETval "%~2" ".;%PATH%"  &:: the current working directory is implied in %PATH% (and searched 1st); make this explicit for this search
:_path_in_PATH_RETURN
endlocal & set "%~1=%_RETval%"
goto :EOF
::

::
:$$path_of_file_in_pathlist ( ref_RETURN FILENAME PATHLIST [EXTENSIONLIST] )
:$path_of_file_in_pathlist ( ref_RETURN FILENAME PATHLIST [EXTENSIONLIST] )
:_path_of_file_in_pathlist ( ref_RETURN FILENAME PATHLIST [EXTENSIONLIST] )
:: NOTE: FILENAME should be a simple filename, not a directory or filename with leading directory prefix. CMD will match these more complex paths, but TCC will not.
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_of_file_in_pathlist"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
set "extensionList=%~4"
call :_echo_DEBUG_KEY _RETvar="%~1"
call :_echo_DEBUG_KEY filename="%~2"
call :_echo_DEBUG_KEY pathlist="%~3"
call :_echo_DEBUG_KEY extensionList="%extensionList%"
if NOT DEFINED extensionList ( goto :_path_of_file_in_pathlist_EXTS_NULL )
:_path_of_file_in_pathlist_EXTS
call :_path_of_file_in_pathlist_with_extensions _RETval "%~2" "%~3" "%extensionList:;=" "%"
goto :_path_of_file_in_pathlist_DONE
:_path_of_file_in_pathlist_EXTS_NULL
call :_path_in_pathlist _RETval "%~2" "%~3"
:_path_of_file_in_pathlist_DONE
call :_echo_DEBUG_KEY _RETval="%_RETval%"
:_path_of_file_in_pathlist_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$path_of_file_in_pathlist_with_extensions ( ref_RETURN FILENAME PATHLIST [[EXTENSION1] [EXTENSION2] ...]  )
:$path_of_file_in_pathlist_with_extensions ( ref_RETURN FILENAME PATHLIST [[EXTENSION1] [EXTENSION2] ...]  )
:_path_of_file_in_pathlist_with_extensions ( ref_RETURN FILENAME PATHLIST [[EXTENSION1] [EXTENSION2] ...]  )
:: NOTE: FILENAME should be a simple filename, not a directory or filename with leading directory prefix. CMD will match these more complex paths, but TCC will not.
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_of_file_in_pathlist_with_extensions"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set _RETvar=%~1
shift
set "_f=%~1"
shift
set "pathlist=%~1"
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY filename="%_f%"
call :_echo_DEBUG_KEY pathlist="%pathlist%"
set "_RETval_level="
:_path_of_file_in_pathlist_with_extensions_LOOP
shift
call :_echo_DEBUG_KEY ext_N="%~1"
if "%~1" == "" ( goto :_path_of_file_in_pathlist_with_extensions_RETURN )
call :_path_in_pathlist _f_path "%_f%%~1" "%pathlist%"
if "%_f_path%" EQU "" ( goto :_path_of_file_in_pathlist_with_extensions_LOOP )
call :_echo_DEBUG_KEY _f_path="%_f_path%"
call :_dir_of _f_dir "%_f_path%"
call :_echo_DEBUG_KEY _f_path="%_f_path%"
call :_is_in_list _f_level "%_f_dir%" "%pathlist%"
::if DEFINED _f_level ( if "%_RETval_level%" EQU "" ( set "_RETval_level=%_f_level%" & set "_RETval=%_f_path%" ) )
::if DEFINED _f_level ( if %_f_level%0 LSS %_RETval_level%0 ( set "_RETval_level=%_f_level%" & set "_RETval=%_f_path%" ) )
if NOT defined _RETval_level ( set "_RETval_level=%_f_level%" & set "_RETval=%_f_path%" )
if %_f_level%0 LSS %_RETval_level%0 ( set "_RETval_level=%_f_level%" & set "_RETval=%_f_path%" )
call :_echo_DEBUG_KEY _f_level="%_f_level%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
call :_echo_DEBUG_KEY _RETval_level="%_RETval_level%"
goto :_path_of_file_in_pathlist_with_extensions_LOOP
:_path_of_file_in_pathlist_with_extensions_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$path_of_file_in_PATH ( ref_RETURN FILENAME EXTENSIONLIST )
:$path_of_file_in_PATH ( ref_RETURN FILENAME EXTENSIONLIST )
:_path_of_file_in_PATH ( ref_RETURN FILENAME EXTENSIONLIST )
:: NOTE: FILENAME should be a simple filename, not a directory or filename with leading directory prefix. CMD will match these more complex paths, but TCC will not.
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_of_file_in_PATH"
call :_path_of_file_in_pathlist _RETval "%~2" "%PATH%" "%~3"
:_path_of_file_in_PATH_RETURN
endlocal & set "%~1=%_RETval%"
goto :EOF
::

::
:$$path_of_item_in_pathlist ( ref_RETURN ITEMNAME PATHLIST )
:$path_of_item_in_pathlist ( ref_RETURN ITEMNAME PATHLIST )
:_path_of_item_in_pathlist ( ref_RETURN ITEMNAME PATHLIST )
:: RETURN == PATH of first ITEMNAME found within PATHLIST (NULL if not found)
:: NOTE: ITEMNAME can be a simple filename, a path, or filename with leading prefix
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_of_item_in_pathlist"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "item=%~2"
set "pathlist=%~3"
set "_RETval="
call :_echo_DEBUG_KEY ref_RETURN="%_RETvar%"
call :_echo_DEBUG_KEY itemname="%item%"
call :_path_of_item_in_paths _RETval "%item%" "%pathlist:;=" "%"
:_path_of_file_in_paths_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$path_of_item_in_paths ( ref_RETURN ITEMNAME PATH1 [[PATH2] ...] )
:$path_of_item_in_paths ( ref_RETURN ITEMNAME PATH1 [[PATH2] ...] )
:_path_of_item_in_paths ( ref_RETURN ITEMNAME PATH1 [[PATH2] ...] )
:: RETURN == PATH of ITEMNAME from within PATHs (NULL if not found)
:: NOTE: ITEMNAME can be a simple filename, a path, or filename with leading partial prefix
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_path_of_item_in_paths"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
shift
set "item=%~1"
set "_RETval="
call :_echo_DEBUG_KEY ref_RETURN="%_RETvar%"
call :_echo_DEBUG_KEY itemname="%item%"
:_path_of_item_in_paths_LOOP
shift
call :_echo_DEBUG_KEY path_N="%~1"
if "%~1" == "" ( goto :_path_of_item_in_paths_RETURN )
if EXIST "%~1\%item%" ( set "_RETval=%~1\%item%" & goto :_path_of_item_in_paths_RETURN )
goto :_path_of_item_in_paths_LOOP
:_path_of_item_in_paths_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$fullname_of ( ref_RETURN PATH )
:$fullname_of ( ref_RETURN PATH )
:_fullname_of ( ref_RETURN PATH )
:$$FQ_name_of
:$$FQ_fullname_of
:$$fully_qualified_form_of
:$FQ_name_of
:$FQ_fullname_of
:$fully_qualified_form_of
:_FQ_name_of
:_FQ_fullname_of
:_fully_qualified_form_of
:: RETURN == fully qualified name of PATH
:: ToDO: ? pull out _fullname_of to seperate function in keeping with _drive_of / _FQ_drive_of and _dir_of / _FQ_dir_of
:: NOTE: special processing to deal correctly with the case of "<DRIVE>:" ("<DRIVE>:" == "<DRIVE>:" == "<DRIVE>:.", NOT "<DRIVE>:.")
:: NOTE: _fullname_of("") == ""
:: NOTE: _fullname_of("\\") == _fullname_of("\") == _fullname_of("\.") == "<CURRENTDRIVE>:\"
:: NOTE: _fullname_of("c:") == _fullname_of("c:.")
:: NOTE: special processing is needed to deal with the fact that TCC acts out with almost unsuppressible errors for inaccessible and UNC PATHs [which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_fullname_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
call :_echo_DEBUG_KEY 2="%~2"
:: avoid TCC path parsing errors for null strings
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_fullname_of_RETURN )
if "%_RETval%" == "\\" ( set "_RETval=\" )
::
::?:call :_drive_of drive "%~2"
call :_echo_DEBUG_KEY drive="%drive%"
::?:if /i "%drive%" == "%~2" ( set "_RETval=%~2" & goto :_fullname_of_RETURN )
call :_rewrite_path_to_FQ_local _RETval drive "%_RETval%"
if NOT DEFINED drive ( set "drive=%SYSTEMDRIVE%" )
if NOT DEFINED drive ( set "drive=%SYSTEMROOT:~0,2%" )
if NOT DEFINED drive ( set "drive=%~d0" )
call :_echo_DEBUG_KEY drive="%drive%"
call :_echo_DEBUG_KEY _RETval_local="%_RETval%"
call :_param_tilde_PNX _RETval "%_RETval%"
call :_echo_DEBUG_KEY _RETval_PNX="%_RETval%"
set "_RETval=%drive%%_RETval%"
call :_echo_DEBUG_KEY _RETval_DR="%_RETval%"
::?:call :_rtrim _RETval "%_RETval%" "\\"
:_fullname_of_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$shortname_of ( ref_RETURN PATH )
:$shortname_of ( ref_RETURN PATH )
:_shortname_of ( ref_RETURN PATH )
:: RETURN == fully qualified short name of PATH
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_shortname_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
call :_param_tilde_SF _RETval "%~2"
call :_FQ_fullname_of _RETval "%_RETval%"
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$dir_of ( ref_RETURN PATH )
:$dir_of ( ref_RETURN PATH )
:_dir_of ( ref_RETURN PATH )
:: RETURN == directory of PATH
:: NOTE: uses the PATH as is without changing it to fully qualified form
:: NOTE: special processing to deal correctly with the case of "<DRIVE>:" ("<DRIVE>:" == "<DRIVE>:."; "DRIVE:\" == "<DRIVE>:\.")
:: NOTE: _dir_of("") == ""
:: NOTE: _dir_of("\\") == _dir_of("\") == "\"
:: NOTE: _dir_of("c:") == _dir_of("c:.")
:: NOTE: _dir_of("c:\") == _dir_of("c:\.") == "\"
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_dir_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: avoid TCC path parsing errors for null strings
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_dir_of_RETURN )
if "%_RETval%" == "\\" ( set "_RETval=\" )
::
::?:call :_drive_of drive "%~2"
::?:call :_echo_DEBUG_KEY drive="%drive%"
::?:if /i "%drive%" == "%~2" ( set "_RETval=%~2" & goto :_dir_of_RETURN )
call :_rewrite_path_to_FQ_local _path drive "%_RETval%"
call :_param_tilde_P _RETval "%_path%"
::?:call :_param_tilde_N NAME "%_path%"
call :_echo_DEBUG_KEY _P="%_RETval%"
call :_rtrim _RETval "%_RETval%" "\"
::?:if NOT DEFINED _RETval if DEFINED NAME (set _RETval=\)
if NOT DEFINED _RETval (set _RETval=\)
::set "_RETval=%drive%%_RETval%"
:_dir_of_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$FQ_dir_of ( ref_RETURN PATH )
:$FQ_dir_of ( ref_RETURN PATH )
:_FQ_dir_of ( ref_RETURN PATH )
:: RETURN == fully qualified directory of PATH
:: NOTE: _FQ_dir_of("") == ""
:: NOTE: _FQ_dir_of("\\") == _FQ_dir_of("\")
:: NOTE: _FQ_dir_of("c:") == _FQ_dir_of("c:.")
:: NOTE: _FQ_dir_of("c:\") == _FQ_dir_of("c:\.") == "c:\"
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_FQ_dir_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: avoid TCC path parsing errors for null strings
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_FQ_dir_of_RETURN )
if "%_RETval%" == "\\" ( set "_RETval=\" )
call :_rewrite_path_to_FQ_local _RETval drive "%_RETval%"
::?:call :_dir_of _RETval "%_RETval%"
if NOT DEFINED _RETval ( goto :_FQ_dir_of_RETURN )
call :_param_tilde_P _RETval "%_RETval%"
call :_echo_DEBUG_KEY _P="%_RETval%"
call :_rtrim _RETval "%_RETval%" "\"
if NOT DEFINED _RETval ( set "_RETval=\" )
:_FQ_dir_of_DONE
if NOT DEFINED drive ( set "drive=%SYSTEMDRIVE%" )
if NOT DEFINED drive ( set "drive=%SYSTEMROOT:~0,2%" )
if NOT DEFINED drive ( set "drive=%~d0" )
call :_echo_DEBUG_KEY drive="%drive%"
set "_RETval=%drive%%_RETval%"
:_FQ_dir_of_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$extension_of ( ref_RETURN PATH )
:$extension_of ( ref_RETURN PATH )
:_extension_of ( ref_RETURN PATH )
:: RETURN == extension of PATH
:: NOTE: _extension_of "" == "" ; _extension_of "c:" == "" ; _extension_of "\\" == "" _extension_of "\" == ""
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_extension_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: avoid TCC path parsing errors for null strings
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_extension_of_RETURN )
::
call :_rewrite_path_to_FQ_local _RETval _ "%_RETval%"
call :_param_tilde_X _RETval "%_RETval%"
call :_rtrim _RETval "%_RETval%" "\"
:_extension_of_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_PNX ( ref_RETURN PATH )
:$param_tilde_PNX ( ref_RETURN PATH )
:_param_tilde_PNX ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on (or has been forced onto) an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == path, name, and extension of PATH
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_PNX"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_PNX_RETURN )
set "_RETval=%~pnx2"
:_param_tilde_PNX_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_P ( ref_RETURN PATH )
:$param_tilde_P ( ref_RETURN PATH )
:_param_tilde_P ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on (or has been forced onto) an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == directory of PATH
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_P"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_P_RETURN )
set "_RETval=%~p2"
call :_echo_DEBUG_KEY 1="%~1"
call :_echo_DEBUG_KEY 2="%~2"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
:_param_tilde_P_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_NX ( ref_RETURN PATH )
:$param_tilde_NX ( ref_RETURN PATH )
:_param_tilde_NX ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == name & extension of PATH
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_NX"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_NX_RETURN )
set "_RETval=%~nx2"
:_param_tilde_NX_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_X ( ref_RETURN PATH )
:$param_tilde_X ( ref_RETURN PATH )
:_param_tilde_X ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == extension of PATH
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_X"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_X_RETURN )
set "_RETval=%~x2"
:_param_tilde_X_RETURN
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_SF ( ref_RETURN PATH )
:$param_tilde_SF ( ref_RETURN PATH )
:_param_tilde_SF ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on (or has been forced onto) an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == short full name of PATH [ PATH is either absolute or assumed to be relative to %CD%]
:: URLref: [Bug and workaround in %~sf0 ] https://groups.google.com/d/topic/alt.msdos.batch.nt/CrLJbBzgdkk/discussion
:: URLref: [Discussion of bug in %~s0 syntax ] https://groups.google.com/d/topic/alt.msdos.batch.nt/TkUsCQuL_bg/discussion
:: URLref: [CMD percent-tilde Syntax] http://ss64.com/nt/syntax-args.html @@ http://www.webcitation.org/67qH4Ri09
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_SF"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_SF_RETURN )
set "_RETval=%~sf2"
:_param_tilde_SF_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_A ( ref_RETURN PATH )
:$param_tilde_A ( ref_RETURN PATH )
:_param_tilde_A ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on (or has been forced onto) an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == attributes of full name of PATH [ PATH is either absolute or assumed to be relative to %CD%]
:: URLref: [CMD percent-tilde Syntax] http://ss64.com/nt/syntax-args.html @@ http://www.webcitation.org/67qH4Ri09
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_param_tilde_A"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_SF_RETURN )
set "_RETval=%~a2"
:_param_tilde_A_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$param_tilde_DPNX ( ref_RETURN PATH )
:$param_tilde_DPNX ( ref_RETURN PATH )
:_param_tilde_DPNX ( ref_RETURN PATH )
:: NOTE: for TCC, assume that PATH is on (or has been forced onto) an accessible drive and not a UNC pathname [necessary to avoid unsupressable TCC parsing errors; which is "WAD" per developer [meh, see URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://www.webcitation.org/63ua1bpOk]]
:: RETURN == drive, path, name, and extension of PATH
setlocal
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_param_tilde_PNX_RETURN )
set "_RETval=%~dpnx2"
:_param_tilde_PNX_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$attributes_of ( ref_RETURN PATH )
:$attributes_of ( ref_RETURN PATH )
:_attributes_of ( ref_RETURN PATH )
:: RETURN == attribute string for PATH ("", if PATH not accessible)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_attributes_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set _RETvar=%~1
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_attributes_of_RETURN )
set "_RETval=%~a2"
:_attributes_of_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$size_of ( ref_RETURN FILE )
:$size_of ( ref_RETURN FILE )
:_size_of ( ref_RETURN FILE )
:: RETURN == size of FILE
:: NOTE: _size_of(FILE; FILE not accessible) == ""
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_size_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_size_of_RETURN )
set "_RETval=%~z2"
:_size_of_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$filetime_of ( ref_RETURN FILE )
:$filetime_of ( ref_RETURN FILE )
:_filetime_of ( ref_RETURN FILE )
:: RETURN == file time of FILE ("", if FILE is missing)
:: NOTE: file time is returned in "YYYY-MM-DD.HHmm" format [this format is comparable using usual string comparisons for time ordering; and has no illegal file characters, allowing use in a filename]
:: NOTE: _filetime_of(PATH; PATH not accessible) == ""
:: ToDO: check assumptions regarding leading zeros in "~tN" substitution for all time sections
:: ToDO: FIX: time changes by 60 minutes with change in DST ... leave this as LOCAL time ... create _filetime_GMT_of()
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_filetime_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
if NOT EXIST "%~2" ( goto :_filetime_of_RETURN )
set "_RETval=%~t2"
if NOT DEFINED _RETval ( goto :_filetime_of_RETURN )
:: transform to comparable strings
if 1.0 == 1 ( goto :_filetime_of_TCC_transform ) &:: TCC uses a different format for ~tN time/date values
:_filetime_of_CMD_transform
set "year=%_RETval:~6,4%"
set "month=%_RETval:~0,2%"
set "day=%_RETval:~3,2%"
set "hour=%_RETval:~11,2%"
set "minute=%_RETval:~14,2%"
set "ampm=%_RETval:~17,1%"
if "%hour%" == "12" ( set "hour=00" )
if /i "%ampm%" == "p" (
    set /a hour += 12
    )
goto :_filetime_of_SET_RETval
:_filetime_of_TCC_transform
set _RETval=%@filedate["%~2",w,4] %@filetime["%~2"]
set "year=%_RETval:~0,4%"
set "month=%_RETval:~5,2%"
set "day=%_RETval:~8,2%"
set "hour=%_RETval:~11,2%"
set "minute=%_RETval:~14,2%"
if "%hour%" == "12" ( set "hour=00" )
goto :_filetime_of_SET_RETval
:_filetime_of_SET_RETval
set "_RETval=%year%-%month%-%day%.%hour%%minute%"
:_filetime_of_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
call :_echo_DEBUG_KEY ~t2="%~t2"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_archive ( ref_RETURN PATH )
:$is_archive ( ref_RETURN PATH )
:_is_archive ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is a directory
:: NOTE: URLref: http://stackoverflow.com/a/3728742/43774 from http://stackoverflow.com/questions/138981/how-do-i-test-if-a-file-is-a-directory-in-a-batch-script
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_archive"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_is_archive_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~2,1%"
if /i "%attr_bit%"=="a" (set "_RETval=1")
:_is_archive_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_dir ( ref_RETURN PATH )
:$is_dir ( ref_RETURN PATH )
:_is_dir ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is a directory
:: NOTE: URLref: http://stackoverflow.com/a/3728742/43774 from http://stackoverflow.com/questions/138981/how-do-i-test-if-a-file-is-a-directory-in-a-batch-script
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_dir"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_is_dir_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~0,1%"
if /i "%attr_bit%"=="d" (set "_RETval=1")
:_is_dir_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_file ( ref_RETURN PATH )
:$is_file ( ref_RETURN PATH )
:_is_file ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is a directory
:: NOTE: URLref: http://stackoverflow.com/a/3728742/43774 from http://stackoverflow.com/questions/138981/how-do-i-test-if-a-file-is-a-directory-in-a-batch-script
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_file"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_is_file_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~0,1%"
if /i "%attr_bit%"=="-" (set "_RETval=1")
:_is_file_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_hidden ( ref_RETURN PATH )
:$is_hidden ( ref_RETURN PATH )
:_is_hidden ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is hidden
:: NOTE: URLref: http://stackoverflow.com/a/3728742/43774 from http://stackoverflow.com/questions/138981/how-do-i-test-if-a-file-is-a-directory-in-a-batch-script
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_hidden"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_is_hidden_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~3,1%"
if /i "%attr_bit%"=="h" (set "_RETval=1")
:_is_hidden_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_readonly ( ref_RETURN PATH )
:$is_readonly ( ref_RETURN PATH )
:_is_readonly ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is readonly (locked)
:: NOTE: URLref: http://stackoverflow.com/a/3728742/43774 from http://stackoverflow.com/questions/138981/how-do-i-test-if-a-file-is-a-directory-in-a-batch-script
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_readonly"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_is_readonly_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~1,1%"
if /i "%attr_bit%"=="r" (set "_RETval=1")
:_is_readonly_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_system ( ref_RETURN PATH )
:$is_system ( ref_RETURN PATH )
:_is_system ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is a directory
:: NOTE: URLref: http://stackoverflow.com/a/3728742/43774 from http://stackoverflow.com/questions/138981/how-do-i-test-if-a-file-is-a-directory-in-a-batch-script
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_is_system"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETval="
set "_RETvar=%~1"
:: TCC can't handle nonexistant PATHs (especially non-existant drives)
if NOT EXIST "%~2" ( goto :_is_system_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~4,1%"
if /i "%attr_bit%"=="s" (set "_RETval=1")
:_is_system_RETURN
call :_echo_DEBUG_KEY _RETvar="%_RETvar%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
::( endlocal
::  ( if "%_RETvar%" NEQ "" ( if NOT 01 == 1.0 (
::      set "%_RETvar%=%_RETval%"
::      ) else (
::      set %_RETvar=%_RETval
::      ))
::call :_echo_item_DEBUG_KEY "%__DEBUG%" "%__DEBUG_KEY%" "%__ME%" "%__MEfn%" "[ %__MEfn% :: done ]"
::)
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_link ( ref_RETURN PATH )
:$is_link ( ref_RETURN PATH )
:_is_link ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is a link (symbolic link, includes junctions)
:: NOTE: TCC attibute expansion is bugged, and doesn't display the link attribute correctly
setlocal
set "_RETval="
set "_RETvar=%~1"
if NOT EXIST "%~2" ( goto :_is_link_RETURN )
set "attr=%~a2"
set "attr_bit=%attr:~-1,1%"
:: NOTE: TCC ~aN is no longer compatible with CMD (does not show the link attribute)
if NOT 01 == 1.0 ( goto :_is_link_TEST )
set "attr_bit=-"
set "attr=%@lower[%@attrib[%~2]]"
if %@wild[%attr%,*l*] == 1 (
    set "attr_bit=l"
    )
:_is_link_TEST
if /i "%attr_bit%"=="l" (set "_RETval=1")
:_is_link_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$is_junction ( ref_RETURN PATH )
:$is_junction ( ref_RETURN PATH )
:_is_junction ( ref_RETURN PATH )
:: RETURN == (BOOLEAN as undef/1) whether PATH is a junction
setlocal
set "_RETval="
set "_RETvar=%~1"
if NOT EXIST "%~2" ( goto :_is_junction_RETURN )
call :_is_link is_link "%~2"
if NOT DEFINED is_link ( goto :_is_junction_RETURN )
set path_basename=%~nx2
set path_abs=%~dpnx2
:: use ...* to avoid searching within a directory (also, works fine for files)
:: only need 1st match
set "DIRCMD=" &:: remove DIRCMD as it could interfere
:: NOTE: TCC dir formats time as 24 hour (HH:mm) vs CMD 12 hour (HH:mm A/PM)
if 01 == 1.0 ( goto :_readsymlink_TCC )
:_is_junction_CMD
FOR /F "tokens=1,2,3,4*" %%G IN ('dir /A:L "%path_abs%*" ^| "%SystemRoot%\system32\findstr.EXE" "<JUNCTION"') DO (
    set "_dir_entry=%%K"
    goto :_is_junction_DIR_DONE
    )
:_is_junction_TCC
FOR /F "tokens=1,2,3*" %%G IN ('dir /A:L "%path_abs%*" ^| "%SystemRoot%\system32\findstr.EXE" "<JUNCTION"') DO (
    set "_dir_entry=%%J"
    goto :_is_junction_DIR_DONE
    )
:_is_junction_DIR_DONE
if NOT DEFINED _dir_entry ( goto :_is_junction_RETURN )
:: find symlink portion and pull it off the entry, then match pathnames
call set symlink=%%_dir_entry:*%path_basename% [=%%
set symlink= [%symlink%
call set path_name=%%_dir_entry:%symlink%=%%
if "%path_basename%" == "%path_name%" ( set _RETval=1 )
:_is_junction_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$readsymlink_of ( ref_RETURN PATH )
:$readsymlink_of ( ref_RETURN PATH )
:_readsymlink_of ( ref_RETURN PATH )
:: RETURN == target path of PATH (in raw, non-fully-qualified / non-canonicalized form); NULL if PATH is not a link/junction
:: NOTE: only follows a single link (if present)
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_readsymlink_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_readsymlink_of_RETURN )
set path_basename=%~nx2
set path_abs=%~dpnx2
call :_is_link is_link "%~2"
call :_echo_DEBUG_KEY path_basename="%path_basename%"
if NOT DEFINED is_link ( set "_RETval=" & goto :_readsymlink_of_FOUND )
:: use ...* to avoid searching within a directory (also, works fine for files)
:: the 1st match is correct, take it and stop looking (avoids collisions with similar link names)
:: NOTE: TCC dir formats time as 24 hour (HH:mm) vs CMD 12 hour (HH:mm A/PM)
if 01 == 1.0 ( goto :_readsymlink_TCC )
:_readsymlink_CMD
FOR /F "tokens=1,2,3,4*" %%G IN ('dir /A:L "%path_abs%*" ^| "%SystemRoot%\system32\findstr.EXE" "<SYMLINK <JUNCTION"') DO (
    set "_dir_entry=%%K"
    goto :_readsymlink_of_DIR_DONE
    )
:_readsymlink_TCC
FOR /F "tokens=1,2,3*" %%G IN ('dir /A:L "%path_abs%*" ^| "%SystemRoot%\system32\findstr.EXE" "<SYMLINK <JUNCTION"') DO (
    set "_dir_entry=%%J"
    goto :_readsymlink_of_DIR_DONE
    )
:_readsymlink_of_DIR_DONE
call set _RETval=%%_dir_entry:*%path_basename% [=%%
set _RETval=%_RETval:~0,-1%
:_readsymlink_of_FOUND
:_readsymlink_of_DONE
:_readsymlink_of_RETURN
call :_echo_DEBUG_KEY _RETval=%_RETVal%
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$readlink_of ( ref_RETURN PATH )
:$readlink_of ( ref_RETURN PATH )
:_readlink_of ( ref_RETURN PATH )
:: RETURN == fully qualified target path of PATH; NULL if PATH is not a link/junction
:: NOTE: only follows a single link (if present)
:: NOTE: using _fq_fullname for full qualification to deal with difficult special cases (and nasty TCC drive/UNC bugs [URLref: http://jpsoft.com/forums/threads/using-dp1-for-paths-with-unavailable-drives.3450 @@ http://webcitation.org/63ua1bpOk])
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_readlink_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
if NOT DEFINED _RETval ( goto :_readlink_of_RETURN )
call :_readsymlink_of _RETval "%_RETval%"
if NOT DEFINED _RETval ( goto :_readlink_of_RETURN )
::call :_split_drive_path_of _drive _path "%_RETval%"
::if DEFINED _drive ( goto :_readlink_of_FOUND )
::if NOT "%_path:~0,1%" == "\" ( set "_RETval=%~dp2%_path%" )
:_readlink_of_FOUND
call :_FQ_fullname_of _RETval "%_RETval%"
:_readlink_of_DONE
:_readlink_of_RETURN
call :_echo_DEBUG_KEY _RETval=%_RETVal%
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$$realpath_of ( ref_RETURN PATH [MAX_DEPTH] )
:$realpath_of ( ref_RETURN PATH [MAX_DEPTH] )
:_realpath_of ( ref_RETURN PATH [MAX_DEPTH] )
:: RETURN == fully qualified & canonical real/final path of PATH (to MAX_DEPTH level [default=9]; NULL if still not at final, non-link/junction PATH by MAX_DEPTH)
:: NOTE: MAX_DEPTH is used to avoid an infinite loop for circular link references
:: NOTE: similar to "realpath" or "readlink -f"
:: NOTE: ToDO: research changing all parent directories into real paths (for a true canonical real_path); currently, symbolic links in PARENTs are not dereferenced
setlocal
set "__DEBUG_KEY=@"
set "__MEfn=_realpath_of"
call :_echo_DEBUG_KEY [ %__MEfn% :: start ]
set "_RETvar=%~1"
set "_RETval=%~2"
set "max_depth=%~3"
if NOT DEFINED max_depth ( set max_depth=9 )
call :_echo_DEBUG_KEY _RETvar=%_RETvar%
call :_echo_DEBUG_KEY _RETval=%_RETval%
call :_echo_DEBUG_KEY max_depth=%max_depth%
:_realpath_of_LOOP
call :_is_link is_link "%_RETval%"
if NOT DEFINED is_link ( goto :_realpath_of_FOUND )
if NOT %max_depth% GTR 0 ( set "_RETval=" & goto :_realpath_of_DONE )
call :_readlink_of _RETval "%_RETval%"
call :_echo_DEBUG_KEY _RETval="%_RETval%"
set /a max_depth -= 1
goto :_realpath_of_LOOP
:_realpath_of_FOUND
call :_FQ_fullname_of _RETval "%_RETval%"
:_realpath_of_DONE
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

:: end :: FUNCTIONS (library:rev69)
