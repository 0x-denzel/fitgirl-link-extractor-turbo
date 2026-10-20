@echo off & (python -x "%~f0" %* || (echo. & echo [!] Python is not installed or not in PATH. Please install Python 3.8+ from https://www.python.org/ & echo [Make sure to check 'Add Python to PATH' during installation] & echo. & pause)) & exit /b
# =============================================================================
#  FITGIRL TURBO LINK EXTRACTOR - MULTI-HOSTER ENGINE
#  Author: 0xdenzel (chideraokonkwo.com)
#  Hosters: FuckingFast, FileKeeper, DataNodes
# =============================================================================
import asyncio
import sys
import os
import re
import datetime
import subprocess
import argparse
import random
import webbrowser
import urllib.request

# Enable Windows ANSI Virtual Terminal Colors and UTF-8 output
if sys.platform == "win32":
    os.system('')
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# Color Palette
C_CYAN = "\033[96m"
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_RED = "\033[91m"
C_MAGENTA = "\033[95m"
C_WHITE = "\033[97m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_RESET = "\033[0m"

# Auto-check and install required dependencies on first launch
REQUIRED_PACKAGES = {
    "playwright": "playwright",
    "playwright_stealth": "playwright-stealth",
    "bs4": "beautifulsoup4",
    "requests": "requests",
}

missing_pkgs = []
for mod, pkg in REQUIRED_PACKAGES.items():
    try:
        __import__(mod)
    except ImportError:
        missing_pkgs.append(pkg)

if missing_pkgs:
    print(f"\n{C_YELLOW}[!] First-time setup: Installing required libraries ({', '.join(missing_pkgs)})...{C_RESET}")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install"] + missing_pkgs, check=True)
        print(f"{C_GREEN}[+] Dependencies successfully installed!{C_RESET}\n")
    except Exception as e:
        print(f"{C_RED}[!] Warning: Could not auto-install dependencies: {e}{C_RESET}")

from playwright.async_api import async_playwright
from playwright_stealth import Stealth
from bs4 import BeautifulSoup

DOWNLOAD_DIR = os.path.join(os.path.expanduser("~"), "Downloads")


def make_link(text: str, url: str) -> str:
    """Render clickable OSC 8 hyperlink everywhere; modern conhost, Windows Terminal & macOS parse cleanly without wrapping"""
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"


LINK_SITE = make_link("Website", "https://chideraokonkwo.com")
LINK_COFFEE = make_link("Buy Me a Coffee", "https://chideraokonkwo.gumroad.com/coffee")

BANNER = f"""
{C_CYAN}{C_BOLD} =============================================================================
    ______ _ _    _____ _      _   _______             _           
   |  ____(_) |  / ____(_)    | | |__   __|           | |          
   | |__   _| |_| |  __ _ _ __| |    | | _   _ _ __   | |__   ___  
   |  __| | | __| | |_ | | '__| |    | || | | | '__|  | '_ \\ / _ \\ 
   | |    | | |_| |__| | | |  | |    | || |_| | |     | |_) | (_) |
   |_|    |_|\\__|\\_____|_|_|  |_|    |_| \\__,_|_|     |_.__/ \\___/ 

             {C_YELLOW}>>> BY 0xDENZEL | {LINK_SITE} | {LINK_COFFEE} <<<{C_CYAN}{C_BOLD}
 ============================================================================={C_RESET}
  {C_WHITE}Automated direct link resolver for IDM, JDownloader & Free Download Manager{C_RESET}
  {C_DIM}Supported Hosters & Mirrors:
   [+] FuckingFast (fuckingfast.co) - Instant CDN Direct Links
   [+] FileKeeper (filekeeper.net) - High-Speed Turbo Tunnel Mirrors
   [+] DataNodes (datanodes.to) - Direct Cloud Storage Mirrors
   [+] Torrent & Magnet Mirrors (1337x, Magnet URI, .torrent file download)
   [+] FitGirl PrivateBin pastes (paste.fitgirl-repacks.site/?id#key)
   [+] FitGirl Repack game pages with interactive mirror selector
   [+] Instant passthrough for already direct links (.dlproxy.uk, /dl/, /d/){C_RESET}
{C_CYAN}{C_BOLD} ============================================================================={C_RESET}
"""


def clear_screen():
    """Clear terminal screen to keep the header static at the top"""
    if sys.platform == "win32":
        os.system("cls")
    else:
        os.system("clear")


def get_clipboard_text() -> str:
    """Cross-platform fast clipboard reader (ctypes Win32 on Windows, pbpaste on macOS, xclip on Linux)"""
    try:
        if sys.platform == "darwin":
            cmd = subprocess.run(["pbpaste"], capture_output=True, text=True, timeout=2)
            return cmd.stdout.strip()
        elif sys.platform == "win32":
            # 1. Native ctypes Win32 read: 0ms, zero process spawning, no timeouts
            try:
                import ctypes
                user32 = ctypes.windll.user32
                kernel32 = ctypes.windll.kernel32
                user32.OpenClipboard.argtypes = [ctypes.c_void_p]
                user32.OpenClipboard.restype = ctypes.c_bool
                user32.GetClipboardData.argtypes = [ctypes.c_uint]
                user32.GetClipboardData.restype = ctypes.c_void_p
                user32.CloseClipboard.argtypes = []
                user32.CloseClipboard.restype = ctypes.c_bool
                kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
                kernel32.GlobalLock.restype = ctypes.c_void_p
                kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
                kernel32.GlobalUnlock.restype = ctypes.c_bool

                if user32.OpenClipboard(None):
                    try:
                        h = user32.GetClipboardData(13)  # CF_UNICODETEXT
                        if h:
                            ptr = kernel32.GlobalLock(h)
                            if ptr:
                                text = ctypes.c_wchar_p(ptr).value
                                kernel32.GlobalUnlock(h)
                                if text:
                                    return text.strip()
                    finally:
                        user32.CloseClipboard()
            except Exception:
                pass

            # 2. PowerShell fallback
            try:
                cmd = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", "Get-Clipboard"],
                                     capture_output=True, text=True, timeout=5)
                return cmd.stdout.strip()
            except Exception:
                pass
            return ""
        else:
            cmd = subprocess.run(["xclip", "-selection", "clipboard", "-o"], capture_output=True, text=True, timeout=2)
            return cmd.stdout.strip()
    except Exception:
        return ""


def copy_to_clipboard(text: str):
    """Cross-platform clipboard writer (Windows & macOS & Linux)"""
    try:
        if sys.platform == "darwin":
            subprocess.run(["pbcopy"], input=text.strip().encode("utf-8"), check=True)
            print(f"  {C_GREEN}[+] Copied all direct links to macOS Clipboard!{C_RESET}")
        elif sys.platform == "win32":
            subprocess.run(["clip.exe"], input=text.strip().encode("utf-8"), check=True)
            print(f"  {C_GREEN}[+] Copied all direct links to Windows Clipboard!{C_RESET}")
        else:
            subprocess.run(["xclip", "-selection", "clipboard"], input=text.strip().encode("utf-8"), check=True)
            print(f"  {C_GREEN}[+] Copied all direct links to Clipboard!{C_RESET}")
    except Exception:
        pass


def get_installed_download_managers() -> list[tuple[str, str, str]]:
    """Detect installed download managers across Windows and macOS.
    Returns: list of (Name, LaunchPath, LaunchCommandType)
    """
    managers = []

    if sys.platform == "win32":
        # Internet Download Manager (IDM)
        idm_paths = [
            r"C:\Program Files (x86)\Internet Download Manager\IDMan.exe",
            r"C:\Program Files\Internet Download Manager\IDMan.exe"
        ]
        for p in idm_paths:
            if os.path.isfile(p):
                managers.append(("Internet Download Manager (IDM)", p, "win_exec"))
                break

        # JDownloader 2 on Windows
        local_app = os.environ.get("LOCALAPPDATA", "")
        prog_files = os.environ.get("ProgramFiles", "")
        prog_files_x86 = os.environ.get("ProgramFiles(x86)", "")
        jd_paths = [
            os.path.join(local_app, "JDownloader 2.0", "JDownloader2.exe"),
            os.path.join(prog_files, "JDownloader 2.0", "JDownloader2.exe"),
            os.path.join(prog_files_x86, "JDownloader 2.0", "JDownloader2.exe")
        ]
        for p in jd_paths:
            if p and os.path.isfile(p):
                managers.append(("JDownloader 2", p, "win_exec"))
                break

        # Free Download Manager on Windows
        fdm_paths = [
            os.path.join(prog_files, "Softdeluxe", "Free Download Manager", "fdm.exe"),
            os.path.join(prog_files, "FreeDownloadManager", "fdm.exe"),
            os.path.join(local_app, "Programs", "Free Download Manager", "fdm.exe")
        ]
        for p in fdm_paths:
            if p and os.path.isfile(p):
                managers.append(("Free Download Manager", p, "win_exec"))
                break

    elif sys.platform == "darwin":
        # macOS Applications
        mac_apps = [
            ("JDownloader 2", "/Applications/JDownloader 2.app"),
            ("Free Download Manager", "/Applications/Free Download Manager.app"),
            ("Neat Download Manager", "/Applications/NeatDownloadManager.app"),
            ("Folx", "/Applications/Folx.app")
        ]
        for name, app_path in mac_apps:
            if os.path.exists(app_path):
                managers.append((name, app_path, "mac_open"))

    return managers


def parse_links_from_text(raw_text: str) -> list[str]:
    """Extract all supported hoster URLs (FuckingFast, FileKeeper, DataNodes) from raw text"""
    patterns = [
        r'https?://(?:dl\.)?fuckingfast\.co/[^\s"\'<>]+',
        r'https?://(?:www\.)?filekeeper\.net/[^\s"\'<>]+',
        r'https?://(?:www\.)?datanodes\.to/[^\s"\'<>]+',
    ]
    seen = set()
    links = []
    for pat in patterns:
        for l in re.findall(pat, raw_text):
            clean = l.rstrip('.,;*)\'"')
            if clean not in seen:
                seen.add(clean)
                links.append(clean)
    return links


def detect_hoster(url: str) -> str:
    """Identify which hoster service hosts the given URL"""
    lower = url.lower()
    if "filekeeper.net" in lower:
        return "filekeeper"
    elif "datanodes.to" in lower:
        return "datanodes"
    return "fuckingfast"


def is_direct_link(url: str) -> bool:
    """Check if a URL is already an instant direct CDN download link"""
    lower = url.lower()
    if "dl.fuckingfast.co/dl/" in lower:
        return True
    if "dlproxy.uk" in lower or ("/download/" in lower and "tunnel" in lower):
        return True
    if "/d/" in lower and "datanodes.to" in lower:
        return True
    return False


def inspect_input(raw_text: str):
    """Inspect text and find all pastebin links, repack page links, and hoster links"""
    paste_links = re.findall(r'https?://paste\.fitgirl-repacks\.site/[^\s"\'<>]+', raw_text)
    repack_links = [u for u in re.findall(r'https?://fitgirl-repacks\.site/[^\s"\'<>]+', raw_text)
                    if not u.startswith("https://paste.") and not u.startswith("http://paste.")]
    hoster_links = parse_links_from_text(raw_text)
    return paste_links, repack_links, hoster_links


def detect_game_name(urls: list[str], input_source: str = "") -> str | None:
    """Detect game name from repack page URL, anchors (#Game_Name_--_...), or URL filename"""
    if "fitgirl-repacks.site" in input_source and "paste." not in input_source:
        clean = input_source.strip().rstrip('/')
        slug = clean.split('/')[-1]
        if slug and slug != "fitgirl-repacks.site":
            return slug.replace("-", "_")

    for u in urls:
        # 1. Anchor format: #Game_Name_--_...
        if '#' in u:
            anchor = u.split('#')[-1]
            m = re.match(r'^([A-Za-z0-9_.\-]+?)(?:_--_|--|\.part\d|\.rar|\.bin)', anchor, re.IGNORECASE)
            if m:
                name = m.group(1).rstrip('_.-')
                if name and not name.lower().startswith("fg-"):
                    return name

        # 2. Path filename format: /<id>/Game_Name_--_...
        filename = u.split('/')[-1].split('?')[0].split('#')[0]
        m_file = re.match(r'^([A-Za-z0-9_.\-]+?)(?:_--_|--|\.part\d|\.rar|\.bin)', filename, re.IGNORECASE)
        if m_file:
            name = m_file.group(1).rstrip('_.-')
            if name and not name.lower().startswith("fg-"):
                return name

    if os.path.isfile(input_source):
        base = os.path.splitext(os.path.basename(input_source))[0]
        if base and base.lower() not in ("urls", "links", "input"):
            return base

    return None


async def extract_links_from_paste(page, paste_url: str) -> list[str]:
    """Open and decrypt a PrivateBin paste page (paste.fitgirl-repacks.site)"""
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Accessing encrypted paste: {C_CYAN}{paste_url}{C_RESET}")
    print(f"         Decrypting paste securely... ", end="", flush=True)
    await page.goto(paste_url, wait_until="networkidle", timeout=45000)
    await asyncio.sleep(2.5)

    body_text = await page.evaluate("() => document.body ? document.body.innerText : ''")
    links = parse_links_from_text(body_text)

    print(f"{C_GREEN}{C_BOLD}DONE{C_RESET}")
    print(f"         Extracted {C_BOLD}{len(links)}{C_RESET} link(s) from paste.")
    return links


async def extract_links_from_fitgirl_page(page, repack_url: str) -> list[str]:
    """Scrape supported hoster links from a FitGirl repack page"""
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Loading FitGirl repack page: {C_CYAN}{repack_url}{C_RESET}")
    await page.goto(repack_url, wait_until="load", timeout=45000)
    await asyncio.sleep(2)

    content = await page.content()
    links = parse_links_from_text(content)

    print(f"         Found {C_BOLD}{len(links)}{C_RESET} link(s) on repack page.")
    return links


def scrape_fitgirl_repack_mirrors(repack_url: str) -> dict | None:
    """Fast-scrape all Direct Download (FileKeeper, FuckingFast, DataNodes) and Torrent (Magnet, .torrent, 1337x, etc.) mirrors from a FitGirl repack page."""
    try:
        req = urllib.request.Request(repack_url, headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        })
        html = urllib.request.urlopen(req, timeout=15).read().decode('utf-8', errors='replace')
        soup = BeautifulSoup(html, 'html.parser')

        # Extract game title
        game_title = ""
        h1 = soup.find('h1', class_='entry-title')
        if h1:
            game_title = h1.get_text().strip()
        elif soup.title:
            game_title = soup.title.get_text().split(' - ')[0].strip()

        # Clean title
        game_title = re.sub(r'[\–\—\-]\s*v?\d.*$', '', game_title).strip()
        if not game_title:
            game_title = "FitGirl_Repack"

        direct_mirrors = []
        torrent_mirrors = []
        seen_direct = set()
        seen_torrent = set()

        for a in soup.find_all('a'):
            txt = a.get_text().strip()
            href = a.get('href') or ''
            lower_txt = txt.lower()
            lower_href = href.lower()

            # 1. Direct Download Mirrors
            if 'paste.fitgirl-repacks.site' in lower_href or any(h in lower_href for h in ['fuckingfast.co', 'filekeeper.net', 'datanodes.to']):
                if '.torrent' not in lower_txt and 'torrent' not in lower_txt:
                    hoster = None
                    if 'filekeeper' in lower_txt or 'filekeeper' in lower_href:
                        hoster = 'FileKeeper'
                    elif 'fuckingfast' in lower_txt or 'fuckingfast' in lower_href:
                        hoster = 'FuckingFast'
                    elif 'datanodes' in lower_txt or 'datanodes' in lower_href:
                        hoster = 'DataNodes'

                    if hoster and hoster not in seen_direct:
                        seen_direct.add(hoster)
                        tag = 'Recommended (Ultra-fast tunnel, ~1.5s/link, 0 countdown)' if hoster == 'FileKeeper' else ('High-Speed Direct CDN (~2.5s/link)' if hoster == 'FuckingFast' else 'Cloud Storage Mirror')
                        direct_mirrors.append({'name': hoster, 'url': href, 'tag': tag})

            # 2. Torrent Mirrors (Magnet & Direct .torrent file download)
            if href.startswith('magnet:') and 'Magnet Link' not in seen_torrent:
                seen_torrent.add('Magnet Link')
                torrent_mirrors.append({'name': 'Magnet Link', 'type': 'magnet', 'url': href, 'tag': 'Instant 1-click launch in torrent client'})
            elif '.torrent file' in lower_txt and '.torrent File Download' not in seen_torrent:
                seen_torrent.add('.torrent File Download')
                torrent_mirrors.append({'name': '.torrent File Download', 'type': 'torrent_file', 'url': href, 'tag': 'Direct .torrent file download to Downloads'})

        # Sort direct mirrors: FileKeeper first, FuckingFast second, DataNodes third
        order = {'FileKeeper': 0, 'FuckingFast': 1, 'DataNodes': 2}
        direct_mirrors.sort(key=lambda m: order.get(m['name'], 99))

        return {
            'game_title': game_title,
            'direct_mirrors': direct_mirrors,
            'torrent_mirrors': torrent_mirrors
        }
    except Exception:
        return None


async def download_torrent_attachment(page, paste_url: str, output_dir: str = DOWNLOAD_DIR) -> str | None:
    """Download .torrent file attachment from a PrivateBin paste and save directly to Downloads"""
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Accessing encrypted .torrent paste: {C_CYAN}{paste_url}{C_RESET}")
    print(f"         Decrypting .torrent attachment... ", end="", flush=True)
    await page.goto(paste_url, wait_until="networkidle", timeout=45000)
    await asyncio.sleep(2)
    print(f"{C_GREEN}{C_BOLD}DONE{C_RESET}")

    att = page.locator('a:has-text("Download attachment")')
    if await att.count() > 0:
        print(f"         Saving .torrent file to Downloads... ", end="", flush=True)
        async with page.expect_download(timeout=15000) as download_info:
            await att.first.click()
        download = await download_info.value
        filename = download.suggested_filename or "game.torrent"
        os.makedirs(output_dir, exist_ok=True)
        save_path = os.path.join(output_dir, filename)
        await download.save_as(save_path)
        print(f"{C_GREEN}{C_BOLD}DONE{C_RESET}")
        return save_path
    return None


async def handle_repack_mirror_selection(repack_url: str):
    """Scan repack page for all direct and torrent mirrors and let user select interactively"""
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Inspecting FitGirl repack page: {C_CYAN}{repack_url}{C_RESET}")
    print(f"         Scanning all available download mirrors... ", end="", flush=True)

    data = scrape_fitgirl_repack_mirrors(repack_url)
    if not data or (not data['direct_mirrors'] and not data['torrent_mirrors']):
        print(f"{C_YELLOW}DONE (Direct parse){C_RESET}")
        await run_pipeline(repack_url)
        return

    print(f"{C_GREEN}{C_BOLD}DONE{C_RESET}")
    game_title = data['game_title']
    direct = data['direct_mirrors']
    torrent = data['torrent_mirrors']

    print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
    print(f"  {C_WHITE}Repack Detected:{C_RESET} {C_GREEN}{C_BOLD}{game_title}{C_RESET}")
    print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

    options = []
    idx = 1

    if direct:
        print(f"\n{C_WHITE}{C_BOLD}--- DIRECT DOWNLOAD HOSTERS (IDM / JDownloader / FDM) ---{C_RESET}")
        for m in direct:
            rec_tag = f" {C_YELLOW}[Recommended]{C_RESET}" if m['name'] == 'FileKeeper' else ""
            print(f"  {C_GREEN}[{idx}]{C_RESET} {C_BOLD}{m['name']:<12}{C_RESET} ➜ {m['tag']}{rec_tag}")
            options.append(('direct', m))
            idx += 1

    if torrent:
        print(f"\n{C_WHITE}{C_BOLD}--- TORRENT & MAGNET MIRRORS (qBittorrent / BitTorrent) ---{C_RESET}")
        for m in torrent:
            print(f"  {C_CYAN}[{idx}]{C_RESET} {C_BOLD}{m['name']:<28}{C_RESET} ➜ {m['tag']}")
            options.append(('torrent', m))
            idx += 1

    print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")
    ans = input(f"{C_WHITE}{C_BOLD}>> Select download option [1-{len(options)}, default=1]: {C_RESET}").strip()

    choice_idx = 0
    if ans.isdigit():
        val = int(ans)
        if 1 <= val <= len(options):
            choice_idx = val - 1

    opt_type, item = options[choice_idx]

    if opt_type == 'direct':
        print(f"\n{C_GREEN}[+] Selected Direct Hoster:{C_RESET} {C_BOLD}{item['name']}{C_RESET}")
        target_url = item['url']

        print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
        print(f"{C_BOLD}Filters & Language Preferences{C_RESET}")
        print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

        ans_bonus = input(f"{C_WHITE}{C_BOLD}>> Exclude optional bonus content (soundtracks/trailers)? [Y/N, default=N]: {C_RESET}").strip().lower()
        exclude_bonus = (ans_bonus == "y")

        print(f"\n{C_BOLD}Language options:{C_RESET}")
        print(f"  {C_GREEN}[Y]{C_RESET} Keep ENGLISH ONLY (skip other language voiceovers) {C_YELLOW}[Recommended]{C_RESET}")
        print(f"  {C_WHITE}[N]{C_RESET} Download ALL languages")
        print(f"  {C_DIM}[Or type a specific language: e.g. spanish, japanese, french]{C_RESET}")
        ans_lang = input(f"{C_WHITE}{C_BOLD}>> Your language choice [Y/N, default=Y]: {C_RESET}").strip().lower()

        if ans_lang in ("", "y", "yes"):
            keep_lang = "english"
        elif ans_lang == "n":
            keep_lang = None
        else:
            keep_lang = ans_lang

        await run_pipeline(target_url, None, exclude_bonus, keep_lang)

    elif opt_type == 'torrent':
        sub_type = item.get('type')
        if sub_type == 'magnet':
            mag_url = item['url']
            print(f"\n{C_GREEN}[+] Magnet Link Extracted:{C_RESET}")
            print(f"    {C_CYAN}{mag_url[:120]}...{C_RESET}")
            copy_to_clipboard(mag_url)
            ans = input(f"\n{C_WHITE}{C_BOLD}>> Open in default torrent client (qBittorrent / BitTorrent)? [Y/N, default=Y]: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                try:
                    if sys.platform == "win32":
                        subprocess.Popen(["start", "", mag_url], shell=True)
                    elif sys.platform == "darwin":
                        subprocess.Popen(["open", mag_url])
                    print(f"{C_GREEN}[+] Torrent client launched!{C_RESET}")
                except Exception as e:
                    print(f"{C_RED}[!] Could not launch torrent client: {e}{C_RESET}")

        elif sub_type == 'torrent_file':
            paste_url = item['url']
            print(f"\n{C_GREEN}[+] Downloading .torrent file from encrypted paste...{C_RESET}")
            async with async_playwright() as p:
                launch_args = ['--disable-blink-features=AutomationControlled', '--no-sandbox']
                try:
                    browser = await p.chromium.launch(headless=True, channel="chrome", args=launch_args)
                except Exception:
                    browser = await p.chromium.launch(headless=True, args=launch_args)
                page = await browser.new_page()
                await Stealth().apply_stealth_async(page)
                saved_path = await download_torrent_attachment(page, paste_url, DOWNLOAD_DIR)
                await browser.close()

            if saved_path and os.path.isfile(saved_path):
                print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
                print(f"  {C_GREEN}{C_BOLD}SUCCESS: .torrent file saved!{C_RESET}")
                print(f"  File: {C_GREEN}{C_BOLD}{os.path.basename(saved_path)}{C_RESET}")
                print(f"  Saved to: {C_CYAN}{saved_path}{C_RESET}")
                copy_to_clipboard(saved_path)
                print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

                try:
                    if sys.platform == "win32":
                        subprocess.run(["explorer.exe", f"/select,{saved_path}"], check=False)
                    elif sys.platform == "darwin":
                        subprocess.run(["open", "-R", saved_path], check=False)
                except Exception:
                    pass

                ans = input(f"\n{C_WHITE}{C_BOLD}>> Open .torrent file in torrent client now? [Y/N, default=Y]: {C_RESET}").strip().lower()
                if ans in ("", "y", "yes"):
                    try:
                        if sys.platform == "win32":
                            os.startfile(saved_path)
                        elif sys.platform == "darwin":
                            subprocess.Popen(["open", saved_path])
                        print(f"{C_GREEN}[+] Opened .torrent file in torrent client!{C_RESET}")
                    except Exception as e:
                        print(f"{C_RED}[!] Could not open torrent file: {e}{C_RESET}")
            else:
                print(f"{C_RED}[!] Could not download .torrent file from paste.{C_RESET}")


async def extract_fuckingfast(page, url: str, retries: int = 3) -> str | None:
    """Extract FuckingFast direct download link handling Cloudflare Turnstile, HTMX & popunders."""
    clean_url = url.split('#')[0].strip()
    if not clean_url:
        return None

    for attempt in range(1, retries + 1):
        found_link = None

        def handle_download(d):
            nonlocal found_link
            found_link = d.url

        def handle_popup(p):
            asyncio.create_task(p.close())

        async def on_response(response):
            nonlocal found_link
            u = response.url
            if "/dl/" in u:
                found_link = u
            loc = response.headers.get("hx-redirect") or response.headers.get("location")
            if loc and "/dl/" in loc:
                found_link = loc

        page.on("download", handle_download)
        page.on("popup", handle_popup)
        page.on("response", on_response)

        try:
            await page.goto(clean_url, wait_until="domcontentloaded", timeout=25000)

            # Check if file was removed or deleted by hoster
            page_text = await page.content()
            if any(term in page_text for term in ("File Not Found", "File has been removed", "404 Not Found", "File does not exist")):
                return "REMOVED"

            # Allow DOM scripts to settle
            for _ in range(10):
                if await page.locator('a:has-text("DOWNLOAD")').count() > 0:
                    break
                await asyncio.sleep(0.4)

            btn = page.locator('a:has-text("DOWNLOAD")')
            if await btn.count() > 0:
                await btn.first.click()
                await asyncio.sleep(0.6)
                await btn.first.click()

                for _ in range(30):
                    if found_link:
                        break
                    await asyncio.sleep(0.15)

            if found_link:
                return found_link
        except Exception:
            pass
        finally:
            page.remove_listener("download", handle_download)
            page.remove_listener("popup", handle_popup)
            page.remove_listener("response", on_response)

        await asyncio.sleep(random.uniform(0.6, 1.2))

    return None


async def extract_filekeeper(page, url: str, retries: int = 3) -> str | None:
    """Extract FileKeeper direct download link via instant high-speed form resolution."""
    clean_url = url.split('#')[0].strip()
    if not clean_url:
        return None

    for attempt in range(1, retries + 1):
        found_link = None

        def handle_download(d):
            nonlocal found_link
            found_link = d.url

        def handle_popup(p):
            asyncio.create_task(p.close())

        async def on_response(response):
            nonlocal found_link
            u = response.url
            if "dlproxy.uk" in u or "tunnel" in u or ("/download/" in u and "filekeeper.net" not in u):
                found_link = u
            loc = response.headers.get("location")
            if loc and ("dlproxy.uk" in loc or "tunnel" in loc or ("/download/" in loc and "filekeeper.net" not in loc)):
                found_link = loc

        page.on("download", handle_download)
        page.on("popup", handle_popup)
        page.on("response", on_response)

        try:
            await page.goto(clean_url, wait_until="domcontentloaded", timeout=25000)

            # Check if file was removed
            page_text = await page.content()
            if any(term in page_text for term in ("File Not Found", "File has been removed", "404 Not Found", "File does not exist")):
                return "REMOVED"

            # Parse file code from URL: https://filekeeper.net/<code-id>/<filename>
            parts = clean_url.replace("https://", "").replace("http://", "").split('/')
            code = parts[1] if len(parts) >= 2 else ""

            # Direct form submit bypassing countdown and advertising popups
            await page.evaluate(f"""() => {{
                const form = document.createElement('form');
                form.method = 'POST';
                form.action = 'https://filekeeper.net/download';
                const fields = {{
                    'op': 'download2',
                    'id': '{code}',
                    'rand': '',
                    'referer': '',
                    'method_free': 'Free download',
                    'down_direct': '1'
                }};
                for (const [k, v] of Object.entries(fields)) {{
                    const inp = document.createElement('input');
                    inp.type = 'hidden';
                    inp.name = k;
                    inp.value = v;
                    form.appendChild(inp);
                }}
                document.body.appendChild(form);
                form.submit();
            }}""")

            for _ in range(35):
                if found_link:
                    break
                await asyncio.sleep(0.15)

            if found_link:
                return found_link
        except Exception:
            pass
        finally:
            page.remove_listener("download", handle_download)
            page.remove_listener("popup", handle_popup)
            page.remove_listener("response", on_response)

        await asyncio.sleep(random.uniform(0.5, 1.0))

    return None


async def extract_datanodes(page, url: str, retries: int = 2) -> str | None:
    """Extract DataNodes direct download link via progression and verification."""
    clean_url = url.split('#')[0].strip()
    if not clean_url:
        return None

    for attempt in range(1, retries + 1):
        found_link = None

        def handle_download(d):
            nonlocal found_link
            found_link = d.url

        def handle_popup(p):
            asyncio.create_task(p.close())

        async def on_response(response):
            nonlocal found_link
            u = response.url
            if "/d/" in u and "datanodes.to" in u:
                found_link = u
            loc = response.headers.get("location")
            if loc and "/d/" in loc:
                found_link = loc

        page.on("download", handle_download)
        page.on("popup", handle_popup)
        page.on("response", on_response)

        try:
            await page.goto(clean_url, wait_until="domcontentloaded", timeout=30000)

            # Check if file was removed
            page_text = await page.content()
            if any(term in page_text for term in ("File Not Found", "File has been removed", "404 Not Found", "File does not exist")):
                return "REMOVED"

            # Step 1: Wait up to 8s for #method_free button to become enabled
            for _ in range(16):
                btn_state = await page.evaluate("""() => {
                    const b = document.getElementById('method_free');
                    return b && !b.disabled;
                }""")
                if btn_state:
                    break
                await asyncio.sleep(0.5)

            # Submit form to navigate to Step 2
            try:
                async with page.expect_navigation(timeout=15000):
                    await page.evaluate("""() => {
                        const btn = document.getElementById('method_free');
                        if (btn) {
                            btn.removeAttribute('disabled');
                            btn.click();
                        }
                    }""")
            except Exception:
                pass

            await asyncio.sleep(3)

            # Step 2: Interact with verification if present
            loc = page.locator('.cf-turnstile')
            if await loc.count() > 0:
                box = await loc.bounding_box()
                if box:
                    await page.mouse.click(box['x'] + 30, box['y'] + 30)
                    await asyncio.sleep(3)

            # Check if download button or direct link is ready
            btn_dl = page.locator('button:has-text("Download"), button:has-text("Start Download")')
            if await btn_dl.count() > 0:
                await btn_dl.first.click()
                for _ in range(30):
                    if found_link:
                        break
                    await asyncio.sleep(0.2)

            if found_link:
                return found_link
        except Exception:
            pass
        finally:
            page.remove_listener("download", handle_download)
            page.remove_listener("popup", handle_popup)
            page.remove_listener("response", on_response)

        await asyncio.sleep(random.uniform(0.6, 1.2))

    return None


async def extract_direct_download(page, url: str) -> str | None:
    """Master direct download dispatcher routing each URL to its dedicated resolver engine"""
    hoster = detect_hoster(url)
    if hoster == "filekeeper":
        return await extract_filekeeper(page, url)
    elif hoster == "datanodes":
        return await extract_datanodes(page, url)
    else:
        return await extract_fuckingfast(page, url)


async def run_pipeline(input_source: str, output_path: str | None = None, exclude_bonus: bool = False, keep_lang: str | None = "english"):
    clean_input = input_source.strip().strip('"').strip("'")
    raw_urls = []

    if os.path.isfile(clean_input):
        print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Reading links from local file: {C_CYAN}{clean_input}{C_RESET}")
        with open(clean_input, "r", encoding="utf-8") as f:
            content = f.read()
        paste_links, repack_links, hoster_links = inspect_input(content)
    else:
        paste_links, repack_links, hoster_links = inspect_input(clean_input)

    # 1. Resolve pastebin or repack links
    if paste_links or repack_links:
        async with async_playwright() as p:
            launch_args = ['--disable-blink-features=AutomationControlled', '--no-sandbox']
            try:
                browser = await p.chromium.launch(headless=True, channel="chrome", args=launch_args)
            except Exception:
                browser = await p.chromium.launch(headless=True, args=launch_args)
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
            page = await context.new_page()
            await Stealth().apply_stealth_async(page)

            for p_url in paste_links:
                p_extracted = await extract_links_from_paste(page, p_url)
                raw_urls.extend(p_extracted)

            for r_url in repack_links:
                r_extracted = await extract_links_from_fitgirl_page(page, r_url)
                raw_urls.extend(r_extracted)

            await browser.close()

    if hoster_links:
        if not paste_links and not repack_links:
            ff_cnt = sum(1 for u in hoster_links if "fuckingfast" in u)
            fk_cnt = sum(1 for u in hoster_links if "filekeeper" in u)
            dn_cnt = sum(1 for u in hoster_links if "datanodes" in u)
            bd = []
            if ff_cnt: bd.append(f"{ff_cnt} FuckingFast")
            if fk_cnt: bd.append(f"{fk_cnt} FileKeeper")
            if dn_cnt: bd.append(f"{dn_cnt} DataNodes")
            h_str = ", ".join(bd) if bd else f"{len(hoster_links)} link(s)"
            print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Found {C_BOLD}{len(hoster_links)}{C_RESET} link(s) directly from input ({h_str}).")
        raw_urls.extend(hoster_links)

    # Deduplicate
    seen = set()
    deduped_urls = []
    for u in raw_urls:
        if u not in seen:
            seen.add(u)
            deduped_urls.append(u)
    raw_urls = deduped_urls

    if not raw_urls:
        print(f"\n{C_RED}[-] No valid download links (FuckingFast, FileKeeper, DataNodes) found to process.{C_RESET}")
        return

    # 2. Check if all links are direct
    direct_links_only = [u for u in raw_urls if is_direct_link(u)]
    if len(direct_links_only) == len(raw_urls):
        print("\n" + f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")
        print(f"  {C_YELLOW}{C_BOLD}[+] NOTICE: All links provided are ALREADY direct download links!{C_RESET}")
        print(f"      {C_DIM}Direct CDN links detected. Skipping validation pipeline.{C_RESET}")
        print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

        game_name = detect_game_name(raw_urls, clean_input)
        if not game_name:
            prompt_name = input(f"{C_WHITE}{C_BOLD}>> Enter game name for file (e.g. witcher3) [default: direct_links]: {C_RESET}").strip()
            game_name = prompt_name.replace(" ", "_") if prompt_name else "direct_links"

        if not output_path:
            output_path = os.path.join(DOWNLOAD_DIR, f"{game_name}_links.txt")

        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            for link in raw_urls:
                f.write(link.split('#')[0].strip() + "\n")

        print(f"\n  {C_GREEN}{C_BOLD}SUCCESS: {len(raw_urls)} direct links saved instantly!{C_RESET}")
        print(f"  Game: {C_GREEN}{C_BOLD}{game_name}{C_RESET}")
        print(f"  Saved to file: {C_CYAN}{output_path}{C_RESET}")
        copy_to_clipboard("\n".join([u.split('#')[0].strip() for u in raw_urls]))
        print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

        # Reveal file in OS file manager immediately!
        try:
            if sys.platform == "win32":
                subprocess.run(["explorer.exe", f"/select,{output_path}"], check=False)
            elif sys.platform == "darwin":
                subprocess.run(["open", "-R", output_path], check=False)
        except Exception:
            pass

        dms = get_installed_download_managers()
        if dms:
            dm_name, dm_target, dm_type = dms[0]
            print(f"\n{C_GREEN}[+] {dm_name} detected!{C_RESET}")
            ans = input(f"{C_WHITE}{C_BOLD}>> Would you like to launch {dm_name} now? [Y/N, default=Y]: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                try:
                    if dm_type == "mac_open":
                        subprocess.Popen(["open", dm_target])
                    else:
                        subprocess.Popen([dm_target])
                    print(f"{C_GREEN}[+] {dm_name} launched!{C_RESET}")
                except Exception as e:
                    print(f"{C_RED}[!] Could not launch {dm_name}: {e}{C_RESET}")
        return

    # 3. Detect game name
    game_name = detect_game_name(raw_urls, clean_input)
    if not game_name:
        prompt_name = input(f"\n{C_WHITE}{C_BOLD}>> Enter game name for file (e.g. witcher3) [default: fitgirl_links]: {C_RESET}").strip()
        game_name = prompt_name.replace(" ", "_") if prompt_name else f"fitgirl_links_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"

    if not output_path:
        output_path = os.path.join(DOWNLOAD_DIR, f"{game_name}_links.txt")

    # 4. Filters
    filtered_urls = []
    for url in raw_urls:
        lower = url.lower()
        if exclude_bonus and "fg-optional" in lower:
            continue

        if "fg-selective" in lower:
            if keep_lang:
                if keep_lang.lower() in lower:
                    filtered_urls.append(url)
                continue
            else:
                filtered_urls.append(url)
                continue

        filtered_urls.append(url)

    if len(filtered_urls) < len(raw_urls):
        diff = len(raw_urls) - len(filtered_urls)
        lang_note = f" (kept '{keep_lang}' audio only)" if keep_lang else ""
        print(f"         {C_YELLOW}Filter applied: excluded {diff} optional/foreign files{lang_note}.{C_RESET}")
        print(f"         {C_BOLD}{len(filtered_urls)}{C_RESET} file(s) queued for download.")

    # 5. Resolve links
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 2]{C_RESET} Resolving {C_BOLD}{len(filtered_urls)}{C_RESET} direct download links for '{C_GREEN}{C_BOLD}{game_name}{C_RESET}'...")
    print(f"         {C_DIM}(High-speed direct CDN extraction session - press Ctrl+C anytime to stop & save){C_RESET}")

    results = []
    total = len(filtered_urls)
    interrupted = False

    try:
        async with async_playwright() as p:
            launch_args = ['--disable-blink-features=AutomationControlled', '--no-sandbox']
            try:
                browser = await p.chromium.launch(headless=True, channel="chrome", args=launch_args)
            except Exception:
                browser = await p.chromium.launch(headless=True, args=launch_args)

            if sys.platform == "darwin":
                ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
            else:
                ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

            context = await browser.new_context(
                user_agent=ua,
                locale="en-US",
                timezone_id="America/New_York",
                viewport={"width": 1920, "height": 1080},
            )
            page = await context.new_page()
            # Auto-suppress any popup ad tab across the context
            context.on("page", lambda p: asyncio.create_task(p.close()) if p != page else None)
            await Stealth().apply_stealth_async(page)

            for i, url in enumerate(filtered_urls, 1):
                if '#' in url:
                    name_hint = url.split('#')[-1]
                elif '/' in url:
                    name_hint = url.split('/')[-1]
                else:
                    name_hint = f"Part {i}"

                pct = int((i - 1) / total * 100)
                bar_len = 14
                filled = int(bar_len * (i - 1) / total)
                bar = "█" * filled + "░" * (bar_len - filled)

                if is_direct_link(url):
                    pct_done = int(i / total * 100)
                    bar_done = "█" * int(bar_len * i / total) + "░" * (bar_len - int(bar_len * i / total))
                    sys.stdout.write(f"\r  [{i}/{total}] {pct_done:3d}% |{bar_done}| {name_hint[:32]} ➜ {C_YELLOW}(Direct) OK!{C_RESET}     ")
                    sys.stdout.flush()
                    results.append(url.split('#')[0].strip())
                    continue

                # Inline display with ASCII redirect icon while resolving
                sys.stdout.write(f"\r  [{i}/{total}] {pct:3d}% |{bar}| {name_hint[:32]} ➜ {C_CYAN}Resolving...{C_RESET}     ")
                sys.stdout.flush()

                direct = await extract_direct_download(page, url)
                pct_done = int(i / total * 100)
                bar_done = "█" * int(bar_len * i / total) + "░" * (bar_len - int(bar_len * i / total))
                if direct == "REMOVED":
                    sys.stdout.write(f"\r  [{i}/{total}] {pct_done:3d}% |{bar_done}| {name_hint[:32]} ➜ {C_RED}{C_BOLD}[REMOVED/404]{C_RESET}     ")
                elif direct:
                    results.append(direct)
                    sys.stdout.write(f"\r  [{i}/{total}] {pct_done:3d}% |{bar_done}| {name_hint[:32]} ➜ {C_GREEN}{C_BOLD}OK!{C_RESET}     ")
                else:
                    sys.stdout.write(f"\r  [{i}/{total}] {pct_done:3d}% |{bar_done}| {name_hint[:32]} ➜ {C_RED}{C_BOLD}FAILED{C_RESET}     ")
                sys.stdout.flush()
                await asyncio.sleep(random.uniform(0.6, 1.2))

            sys.stdout.write("\n")
            await browser.close()
    except (KeyboardInterrupt, asyncio.CancelledError):
        interrupted = True
        sys.stdout.write("\n")
        print(f"\n{C_YELLOW}{C_BOLD}[!] Cancellation requested by user (Ctrl+C).{C_RESET}")

    # 6. Finalize output
    if interrupted:
        print(f"\n{C_MAGENTA}{C_BOLD}[Step 3]{C_RESET} Preserving partially resolved links...")
    else:
        print(f"\n{C_MAGENTA}{C_BOLD}[Step 3]{C_RESET} Finalizing results...")

    if results:
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            for link in results:
                f.write(link + "\n")

        print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
        if interrupted:
            print(f"  {C_YELLOW}{C_BOLD}PARTIALLY SAVED: {len(results)}/{len(filtered_urls)} direct links preserved!{C_RESET}")
        else:
            print(f"  {C_GREEN}{C_BOLD}SUCCESS: {len(results)}/{len(filtered_urls)} direct links resolved!{C_RESET}")
        print(f"  Game: {C_GREEN}{C_BOLD}{game_name}{C_RESET}")
        print(f"  Saved to file: {C_CYAN}{output_path}{C_RESET}")
        copy_to_clipboard("\n".join(results))
        print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

        # Reveal file in OS file manager immediately!
        try:
            if sys.platform == "win32":
                subprocess.run(["explorer.exe", f"/select,{output_path}"], check=False)
            elif sys.platform == "darwin":
                subprocess.run(["open", "-R", output_path], check=False)
        except Exception:
            pass

        dms = get_installed_download_managers()
        if dms:
            dm_name, dm_target, dm_type = dms[0]
            print(f"\n{C_GREEN}[+] {dm_name} detected!{C_RESET}")
            ans = input(f"{C_WHITE}{C_BOLD}>> Would you like to launch {dm_name} now? [Y/N, default=Y]: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                try:
                    if dm_type == "mac_open":
                        subprocess.Popen(["open", dm_target])
                    else:
                        subprocess.Popen([dm_target])
                    print(f"{C_GREEN}[+] {dm_name} launched!{C_RESET}")
                except Exception as e:
                    print(f"{C_RED}[!] Could not launch {dm_name}: {e}{C_RESET}")
        else:
            print(f"\n{C_WHITE}In IDM / JDownloader / FDM:{C_RESET} Import from text file or paste from clipboard:\n  {C_CYAN}{output_path}{C_RESET}")
    else:
        print(f"\n{C_RED}[-] No links could be resolved.{C_RESET}")


def interactive_menu():
    clear_screen()
    print(BANNER)

    clip_text = get_clipboard_text()
    p_links, r_links, h_links = inspect_input(clip_text)
    src = ""

    if p_links or r_links or h_links:
        if r_links and not p_links and not h_links:
            print(f"{C_GREEN}[+] Clipboard auto-detect: Found FitGirl Repack Page in your Clipboard!{C_RESET}")
            print(f"    {C_CYAN}{r_links[0]}{C_RESET}")
            ans = input(f"{C_WHITE}{C_BOLD}>> Press [ENTER] to inspect mirrors & choose download, or type [P] to paste manually: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                asyncio.run(handle_repack_mirror_selection(r_links[0]))
                return
        else:
            desc_parts = []
            if p_links:
                desc_parts.append(f"{len(p_links)} FitGirl Pastebin URL(s)")
            if r_links:
                desc_parts.append(f"{len(r_links)} FitGirl Repack Page(s)")
            if h_links:
                ff_c = sum(1 for u in h_links if "fuckingfast" in u)
                fk_c = sum(1 for u in h_links if "filekeeper" in u)
                dn_c = sum(1 for u in h_links if "datanodes" in u)
                h_details = []
                if ff_c: h_details.append(f"{ff_c} FuckingFast")
                if fk_c: h_details.append(f"{fk_c} FileKeeper")
                if dn_c: h_details.append(f"{dn_c} DataNodes")
                desc_parts.append(f"{len(h_links)} link(s) [{', '.join(h_details)}]")

            desc = " and ".join(desc_parts)
            print(f"{C_GREEN}[+] Clipboard auto-detect: Found {C_BOLD}{desc}{C_RESET}{C_GREEN} in your Clipboard!{C_RESET}")
            ans = input(f"{C_WHITE}{C_BOLD}>> Press [ENTER] to use your clipboard, or type [P] to paste manually: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                src = clip_text

    if not src:
        print(f"\n{C_WHITE}{C_BOLD}>> Paste your URL, file path, or batch links below:{C_RESET}")
        print(f"   {C_DIM}(Supports multi-line paste with/without bullets; press Enter when done):{C_RESET}")
        lines = []
        while True:
            try:
                line = input()
                if not line.strip():
                    if lines:
                        break
                    continue
                lines.append(line)
                if len(lines) == 1 and ("paste.fitgirl-repacks.site" in line or "fitgirl-repacks.site" in line or os.path.isfile(line.strip().strip('"'))):
                    break
            except EOFError:
                break
        src = "\n".join(lines)

    if not src.strip():
        print(f"{C_RED}[!] No input provided.{C_RESET}")
        return

    p_check, r_check, h_check = inspect_input(src)
    if r_check and not p_check and not h_check:
        asyncio.run(handle_repack_mirror_selection(r_check[0]))
        return

    if h_check and not p_check and not r_check:
        direct_check = [u for u in h_check if is_direct_link(u)]
        if len(direct_check) == len(h_check):
            asyncio.run(run_pipeline(src, None, False, None))
            return

    print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
    print(f"{C_BOLD}Filters & Language Preferences{C_RESET}")
    print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

    ans_bonus = input(f"{C_WHITE}{C_BOLD}>> Exclude optional bonus content (soundtracks/trailers)? [Y/N, default=N]: {C_RESET}").strip().lower()
    exclude_bonus = (ans_bonus == "y")

    print(f"\n{C_BOLD}Language options:{C_RESET}")
    print(f"  {C_GREEN}[Y]{C_RESET} Keep ENGLISH ONLY (skip other language voiceovers) {C_YELLOW}[Recommended]{C_RESET}")
    print(f"  {C_WHITE}[N]{C_RESET} Download ALL languages")
    print(f"  {C_DIM}[Or type a specific language: e.g. spanish, japanese, french]{C_RESET}")
    ans_lang = input(f"{C_WHITE}{C_BOLD}>> Your language choice [Y/N, default=Y]: {C_RESET}").strip().lower()

    if ans_lang in ("", "y", "yes"):
        keep_lang = "english"
    elif ans_lang == "n":
        keep_lang = None
    else:
        keep_lang = ans_lang

    asyncio.run(run_pipeline(src, None, exclude_bonus, keep_lang))


def main():
    parser = argparse.ArgumentParser(description="FitGirl Turbo Link Extractor - Direct download resolver for FuckingFast, FileKeeper & DataNodes")
    parser.add_argument("source", nargs="?", help="Pastebin URL, FitGirl page URL, text file path, or link")
    parser.add_argument("-o", "--output", default=None, help="Output file (default: <Game_Name>_links.txt in Downloads)")
    parser.add_argument("--no-bonus", action="store_true", help="Exclude bonus files (fg-optional*)")
    parser.add_argument("--lang", default="english", help="Keep ONLY this selective language (default: english, or 'all')")
    args = parser.parse_args()

    try:
        if not args.source:
            while True:
                interactive_menu()
                print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
                print(f"{C_WHITE}{C_BOLD}>> What would you like to do next?{C_RESET}")
                print(f"   {C_GREEN}[1]{C_RESET} Process another game / paste new links {C_YELLOW}(Start afresh){C_RESET}")
                print(f"   {C_RED}[2]{C_RESET} Exit")
                choice = input(f"{C_WHITE}{C_BOLD}>> Choice [1/2, default=2]: {C_RESET}").strip().lower()
                if choice not in ("1", "again", "y", "yes", "afresh"):
                    print(f"\n{C_GREEN}All done! Happy downloading.{C_RESET}\n")
                    break
                print("\n" * 2)
        else:
            p_check, r_check, h_check = inspect_input(args.source)
            if r_check and not p_check and not h_check:
                asyncio.run(handle_repack_mirror_selection(r_check[0]))
                return
            keep_lang = None if args.lang.lower() in ("all", "none") else args.lang
            asyncio.run(run_pipeline(args.source, args.output, args.no_bonus, keep_lang))
    except KeyboardInterrupt:
        print(f"\n\n{C_YELLOW}[!] Session stopped cleanly.{C_RESET}\n")


if __name__ == "__main__":
    main()
