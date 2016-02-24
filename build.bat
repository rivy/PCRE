@:: build [TARGET [ARGS ...]]
@:: TARGET == realclean | <makefile target>
@:: ARGS == <makefile TARGET args>

@setlocal
@echo off

set __dp0=%~dp0
set __ME=%~n0

set build_dir_base=%__dp0%.build
set build_dir=%build_dir_base%-x^%%_bin_type^%%
set src_dir=%__dp0%PCRE2-mirror

call :$create_list build_bin_types 32 64

::

:: TARGET: realclean
if /i "%~1" == "realclean" (
:: remove build directories
for /d %%D in ("%build_dir_base%*") do rmdir /s /q "%%D"
exit /b 0
)

:: configuration

:: NOTES
:: Test #2: "API, errors, internals, and non-Perl stuff" FAILS with GPF if using stack recursion with default stack size
:: * use either "-D PCRE2_HEAP_MATCH_RECURSE:BOOL=ON" or increase stack size to pass

:: user-configurable cmake project properties
set "project_props="
::
:: ref: http://pcre.org/current/doc/html/pcre2build.html @@ https://archive.is/rbI5U
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
:: set stack size
set "CMAKE_C_FLAGS=%CMAKE_C_FLAGS% -Wl,--stack,8388608" &:: increase stack size to 8MiB

:: CMAKE_BUILD_TYPE
set "CMAKE_BUILD_TYPE=-D CMAKE_BUILD_TYPE=MinSizeRel" &:: [<empty/null>, "-D CMAKE_BUILD_TYPE=Debug", "-D CMAKE_BUILD_TYPE=Release", "-D CMAKE_BUILD_TYPE=RelWithDebInfo", "-D CMAKE_BUILD_TYPE=MinSizeRel"]

:: using scoop (see "http://scoop.sh")
:: `scoop install cmake gcc-tdw git gow` &:: install 'cmake', 'gcc-tdw' (multilib/32+64bit), and 'gow'

:: hide redundant cmake output report if build directories are already present (== initial build already complete)
set "_suppress_cmake_output=1"
:: check/create build directories
set "_list=%build_bin_types%"
:create_build_dir_LOOP
if NOT DEFINED _list (goto :create_build_dir_LOOP_DONE)
call :$first_of _bin_type "%_list%"
call :$remove_first _list "%_list%"
call set "_dir=%build_dir%"
if NOT EXIST "%_dir%" ( mkdir "%_dir%" & set "_suppress_cmake_output=" )
goto :create_build_dir_LOOP
:create_build_dir_LOOP_DONE

:: cmake / make
set "CC="
set "CFLAGS="
set "CXX="
set "CXXFLAGS="
set "LDFLAGS="
::
set "_cmake_stdout="
if DEFINED _suppress_cmake_output ( set "_cmake_stdout=>NUL" )
set "ERRORLEVEL=" &:: clear any previous erroneus ERRORLEVEL overrides
::
set "_list=%build_bin_types%"
:cmake_make_build_LOOP
if NOT DEFINED _list (goto :cmake_make_build_LOOP_DONE)
call :$first_of _bin_type "%_list%"
call :$remove_first _list "%_list%"
call set "_dir=%build_dir%"
cd %_dir%
echo [%_dir%]
cmake -G "MinGW Makefiles" %CMAKE_BUILD_TYPE% -D CMAKE_MAKE_PROGRAM=make -D CMAKE_C_COMPILER=gcc -D CMAKE_C_FLAGS="-m%_bin_type% %CMAKE_C_FLAGS%" %project_props% "%src_dir%" %_cmake_stdout%
make %*
goto :cmake_make_build_LOOP
:cmake_make_build_LOOP_DONE
::
if NOT "%ERRORLEVEL%" == "0" ( set "_exit_code=%ERRORLEVEL%" )

exit /b %_exit_code%

::
goto :EOF
:: ### SUBs

::
:$create_list ( ref_RETURN [ ITEMs ... ] )
:_create_list ( ref_RETURN [ ITEMs ... ] )
:: RETURN == LIST of ITEMs
setlocal
set "_RETval="
set "_RETvar=%~1"
:_create_list_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :_create_list_LOOP_DONE )
set item=%~1
if "%item%" EQU """" ( set "item=" )
if NOT DEFINED _RETval (
    set "_RETval=%item%"
    ) else (
    set "_RETval=%_RETval%;%item%"
    )
goto :_create_list_LOOP
:_create_list_LOOP_DONE
:_create_list_RETURN
if NOT DEFINED _RETval ( set "_RETval=""" )
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$first_of ( ref_RETURN LIST )
:_first_of ( ref_RETURN LIST )
setlocal
set "_RETval="
set _RETvar=%~1
set "list=%~2"
if DEFINED list ( call :_first_of_items _RETval "%list:;=" "%" )
:_first_of_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$first_of_items ( ref_RETURN [ ITEMs ... ] )
:_first_of_items ( ref_RETURN [ ITEMs ... ] )
setlocal
set _RETvar=%~1
set "item=%~2"
if "%item%" == """" ( set "item=" )
:_first_of_items_RETURN
set "_RETval=%item%"
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$remove_first ( ref_RETURN LIST )
:_remove_first ( ref_RETURN LIST )
:: RETURN == LIST with first ITEM removed
setlocal
set "_RETval="
set "_RETvar=%~1"
set "list=%~2"
if DEFINED list ( call :_remove_first_item _RETval "%list:;=" "%" )
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$remove_first_item ( ref_RETURN [ ITEMs ... ] )
:_remove_first_item ( ref_RETURN [ ITEMs ... ] )
:: RETURN == LIST of all ITEMs excepting the initial ITEM
setlocal
set "_RETval="
set "_RETvar=%~1"
shift
:_remove_first_item_LOOP
shift
set item_raw=%1
if NOT DEFINED item_raw ( goto :_remove_first_item_LOOP_DONE )
set "item=%~1"
if "%item%" EQU """" ( set "item=" )
call :_append_to_list _RETval "%item%" "%_RETval%"
goto :_remove_first_item_LOOP
:_remove_first_item_LOOP_DONE
:_remove_first_item_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

::
:$append_to_list ( ref_RETURN ITEM LIST )
:_append_to_list ( ref_RETURN ITEM LIST )
:: RETURN == LIST with ITEM appended
setlocal
set _RETvar=%~1
set "list=%~3"
set "item=%~2"
if "%item%" EQU """" ( set "item=" )
set "_RETval=%item%"
if NOT DEFINED list ( goto :_append_to_list_RETURN )
if "%list%" EQU """" ( set "list=" )
set "_RETval=%list%;%item%"
:_append_to_list_RETURN
if NOT DEFINED _RETval ( set "_RETval=""" )
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::
