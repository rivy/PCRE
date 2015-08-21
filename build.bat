@setlocal
@echo off

set __dp0=%~dp0
set __ME=%~n0

set build_dir=%__dp0%.build
set src_dir=%__dp0%PCRE2-mirror

:: scoop install cmake gcc gow

:: create and move to build directory
mkdir "%build_dir%"
cd "%build_dir%"

:: project properties

:: cmake
cmake -G "Unix Makefiles" -D CMAKE_C_COMPILER=gcc "%src_dir%"
