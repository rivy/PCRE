@setlocal
@echo off

set __dp0=%~dp0
set __ME=%~n0

set build_dir=%__dp0%.build

:: remove build directory
rmdir /s /q "%build_dir%" 2>NUL
