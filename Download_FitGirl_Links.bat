@echo off
setlocal EnableDelayedExpansion
title FitGirl ^& FuckingFast Link Extractor - by 0xdenzel
chcp 65001 >nul
color 0B

echo  =============================================================================
echo     ______ _ _    _____ _      _   _      _       _        
echo    ^|  ____(_) ^|  / ____(_)    ^| ^| ^| ^|    (_)     ^| ^|       
echo    ^| ^|__   _^| ^|_^| ^|  __ _ _ __^| ^| ^| ^|     _ _ __ ^| ^| _____ 
echo    ^|  __^| ^| ^| __^| ^| ^|_ ^| ^| '__^| ^| ^| ^|    ^| ^| '_ \^| ^|/ / __^|
echo    ^| ^|    ^| ^| ^|_^| ^|__^| ^| ^| ^|  ^| ^| ^| ^|____^| ^| ^| ^| ^|   ^<__ \
echo    ^|_^|    ^|_^|\__^|\_____^|_^|_^|  ^|_^| ^|______^|_^|_^| ^|_^|_^|\_\___/
echo.
echo                       ^>^>^> BY 0xDENZEL ^<^<^<
echo  =============================================================================
echo   Automated direct link resolver for IDM ^& JDownloader
echo   Supports:
echo    [+] FitGirl PrivateBin pastes (paste.fitgirl-repacks.site/?id#key)
echo    [+] FitGirl Repack game pages (fitgirl-repacks.site/game-name/)
echo    [+] Text files containing links (.txt)
echo    [+] Direct FuckingFast URLs
echo  =============================================================================
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
echo =============================================================================
echo  Step 2: Filters ^& Language Selection
echo =============================================================================
set "BONUS_OPT="
set /p "EX_BONUS=>> Exclude optional bonus content (soundtracks/credits)? [Y/N, default=N]: "
if /i "%EX_BONUS%"=="Y" set "BONUS_OPT=--no-bonus"

echo.
echo Language options:
echo   [Y] Keep ENGLISH ONLY (skip other language voiceovers: French, German, Russian, etc.)
echo   [N] Download ALL languages
echo   [Or type a specific language: e.g. spanish, japanese, french]
set /p "LANG_CHOICE=>> Your language choice [Y/N, default=Y]: "
if "%LANG_CHOICE%"=="" set "LANG_CHOICE=Y"

set "LANG_OPT="
if /i "%LANG_CHOICE%"=="Y" (
    set "LANG_OPT=--lang english"
) else if /i "%LANG_CHOICE%"=="N" (
    set "LANG_OPT="
) else (
    set "LANG_OPT=--lang %LANG_CHOICE%"
)

echo.
echo =============================================================================
echo  Step 3: Processing (Running Headless Stealth Browser...)
echo =============================================================================
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
echo =============================================================================
echo  Step 4: IDM Integration
echo =============================================================================
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
echo =============================================================================
echo  Done! Press any key to exit.
echo ==============================================================================
pause >nul
