#!/usr/bin/env bash
set -u
cd -- "$(dirname -- "$0")" || exit 1
if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' 'Python 3.10 or newer is required. Install it from https://www.python.org/.'
    if [ -t 0 ]; then read -r -p 'Press Enter to exit...' _; fi
    exit 1
fi
if [ ! -f 'Download_FitGirl_Links.bat' ]; then
    printf '%s\n' 'Place Download_FitGirl_Links.bat beside this launcher.'
    exit 1
fi
exec python3 -x 'Download_FitGirl_Links.bat' "$@"
