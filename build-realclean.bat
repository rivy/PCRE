@setlocal
@echo off

set __dp0=%~dp0
set __ME=%~n0

set build_dir=%__dp0%.build

:: remove build directories
for /d %%D in (".build*") do rmdir /s /q "%%D" 2>NUL
