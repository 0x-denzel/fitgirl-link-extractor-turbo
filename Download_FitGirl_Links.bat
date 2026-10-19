@echo off
setlocal EnableDelayedExpansion
title FitGirl ^& FuckingFast Direct Link Extractor for IDM
chcp 65001 >nul
color 0B

echo ==============================================================================
echo                 FITGIRL ^& FUCKINGFAST BATCH LINK EXTRACTOR
echo ==============================================================================
echo  This tool automatically extracts direct, IDM-ready download links from:
echo   [1] FitGirl PrivateBin pastes  (e.g. paste.fitgirl-repacks.site/?id#key)
echo   [2] FitGirl Repack game pages  (e.g. fitgirl-repacks.site/game-name/)
echo   [3] Text files containing links (.txt)
echo   [4] Raw FuckingFast links
echo ==============================================================================
echo.

:GET_INPUT
set "INPUT="
set /p "INPUT=>> Step 1: Paste your URL or drag-and-drop a text file here: "
if "%INPUT%"=="" (
    echo.
    echo [!] Input cannot be empty. Please paste a URL or file path.
    goto GET_INPUT
)

:: Strip surrounding quotes if present
set "INPUT=%INPUT:"=%"

echo.
echo ==============================================================================
echo  Step 2: Optional Filters
echo ==============================================================================
set "BONUS_OPT="
set /p "EX_BONUS=>> Exclude optional bonus content (soundtracks/trailers)? [Y/N, default=N]: "
if /i "%EX_BONUS%"=="Y" set "BONUS_OPT=--no-bonus"

set "LANG_OPT="
set /p "EX_LANG=>> Exclude selective/extra language packs? [Y/N, default=N]: "
if /i "%EX_LANG%"=="Y" set "LANG_OPT=--no-lang"

echo.
echo ==============================================================================
echo  Step 3: Processing (Running Headless Stealth Browser...)
echo ==============================================================================
echo.

set "SCRIPT_PATH=%USERPROFILE%\Downloads\extract_ff_links.py"
if not exist "%SCRIPT_PATH%" (
    echo [!] Error: extract_ff_links.py not found in Downloads folder.
    pause
    exit /b 1
)

python "%SCRIPT_PATH%" "%INPUT%" %BONUS_OPT% %LANG_OPT%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] An error occurred during extraction.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ==============================================================================
echo  Step 4: IDM Integration
echo ==============================================================================
set "IDM_EXE=C:\Program Files (x86)\Internet Download Manager\IDMan.exe"
if not exist "%IDM_EXE%" set "IDM_EXE=C:\Program Files\Internet Download Manager\IDMan.exe"

if exist "%IDM_EXE%" (
    echo [!] Internet Download Manager (IDM) detected!
    echo All links have been copied to your clipboard.
    set /p "OPEN_IDM=>> Would you like to launch IDM now? [Y/N, default=Y]: "
    if /i "!OPEN_IDM!"=="" set "OPEN_IDM=Y"
    if /i "!OPEN_IDM!"=="Y" (
        start "" "%IDM_EXE%"
        echo [+] IDM launched.
        echo [+] In IDM, click: Tasks -^> Add batch download from clipboard
        echo     or Tasks -^> Import -^> From text file
    )
) else (
    echo [!] Open IDM manually and import: "%USERPROFILE%\Downloads\idm_links.txt"
)

echo.
echo Opening Downloads folder with your links file...
explorer.exe /select,"%USERPROFILE%\Downloads\idm_links.txt"

echo.
echo ==============================================================================
echo  Done! Press any key to exit.
echo ==============================================================================
pause >nul
