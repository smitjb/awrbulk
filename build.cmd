@echo off
setlocal
set DRIVE=%~d0
set DIR=%~p0

set THISDIR=%DRIVE%%DIR%
rem THISDIR is assumed to be the root of the source tree.

set PROJNAME=awrbulk
set LABEL=%1

echo Building %PROJNAME% (%LABEL%) from %THISDIR%

rem 3   zip it up.

echo Removing old zip files
del %PROJNAME%*.zip
echo Creating new zip file %PROJNAME%_%LABEL%.zip
zip -r %PROJNAME%_%LABEL%.zip . -x backup/*
rem 4   put it in artifactory
set AFURL="http://dml.bpweb.bp.com:8088/artifactory/bp-aesdba-snapshot-local/"
set AFPATH=utilities/unsupported/%PROJNAME%

rem curl -u%USERNAME% -T  "http://dml.bpweb.bp.com:8088/artifactory/bp-test-cbafdba-generic/%AFPATH%/%PROJNAME%_%LABEL%.zip"
powershell Invoke-RestMethod -uri "%AFURL%%AFPATH%/%PROJNAME%_%LABEL%.zip"  -Method Put -InFile %PROJNAME%_%LABEL%.zip -Credential %USERNAME% -ContentType "multipart/form-data"



endlocal
