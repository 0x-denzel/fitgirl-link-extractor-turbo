#!/usr/bin/env bash
cd "$(dirname "$0")"
echo "Starting FitGirl & FuckingFast Link Extractor..."
if ! command -v python3 &>/dev/null; then
    echo "[!] Python 3 is not installed. Please install Python 3 from https://www.python.org/"
    read -p "Press [Enter] to exit..."
    exit 1
fi

if [ -f "Download_FitGirl_Links.bat" ]; then
    python3 -x "Download_FitGirl_Links.bat" "$@"
elif [ -f "extract_ff_links.py" ]; then
    python3 "extract_ff_links.py" "$@"
else
    echo "[!] Engine script not found."
    read -p "Press [Enter] to exit..."
    exit 1
fi
