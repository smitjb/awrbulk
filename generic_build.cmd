@echo off
setlocal

set REPO=%1
set LABEL=%2
set TARGET=%3
set MODULE=%4

if not "%REPO%" == "" goto REPOSET
echo "No git repository specified, aborting"
goto :EOF
:REPOSET


if not "%LABEL%" == "" goto LABELSET
echo "No label specified, aborting"
goto :EOF
:LABELSET


if not "%TARGET%" == "" goto TARGETSET
set TARGET=%MODULE%

:TARGETSET

if not "%MODULE%" == "" goto MODULESET
echo "No module specified"


:MODULESET

git clone %REPO% %TARGET%
cd %TARGET%

git checkout %LABEL%

if not "%MODULE%" == "" cd %MODULE%

if not exist build.cmd goto nobuild
call build %LABEL%
goto :EOF
:nobuild
echo "No build script"

endlocal
