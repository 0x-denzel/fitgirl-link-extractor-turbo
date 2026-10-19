@echo off & (python -x "%~f0" %* || (echo. & echo [!] Python is not installed or not in PATH. Please install Python 3.8+ from https://www.python.org/ & echo [Make sure to check 'Add Python to PATH' during installation] & echo. & pause)) & exit /b
# =============================================================================
#  FITGIRL & FUCKINGFAST LINK EXTRACTOR - STANDALONE ENGINE
#  Author: 0xdenzel
# =============================================================================
import asyncio
import sys
import os
import re
import datetime
import subprocess
import argparse

# Check and auto-install required dependencies if missing
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
    print(f"\n[!] First-time setup: Installing required libraries ({', '.join(missing_pkgs)})...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install"] + missing_pkgs, check=True)
        print("[+] Dependencies successfully installed!\n")
    except Exception as e:
        print(f"[!] Warning: Could not auto-install dependencies: {e}")

from playwright.async_api import async_playwright
from playwright_stealth import Stealth

DOWNLOAD_DIR = os.path.join(os.path.expanduser("~"), "Downloads")
IDM_PATHS = [
    r"C:\Program Files (x86)\Internet Download Manager\IDMan.exe",
    r"C:\Program Files\Internet Download Manager\IDMan.exe"
]

BANNER = r"""
 =============================================================================
    ______ _ _    _____ _      _   _      _       _        
   |  ____(_) |  / ____(_)    | | | |    (_)     | |       
   | |__   _| |_| |  __ _ _ __| | | |     _ _ __ | | _____ 
   |  __| | | __| | |_ | | '__| | | |    | | '_ \| |/ / __|
   | |    | | |_| |__| | | |  | | | |____| | | | |   <\__ \
   |_|    |_|\__|\_____|_|_|  |_| |______|_|_| |_|_|\_\___/

                      >>> BY 0xDENZEL <<<
 =============================================================================
  Automated direct link resolver for IDM & JDownloader
  Supports:
   [+] FitGirl PrivateBin pastes (paste.fitgirl-repacks.site/?id#key)
   [+] FitGirl Repack game pages (fitgirl-repacks.site/game-name/)
   [+] Text files containing links (.txt)
   [+] Direct FuckingFast URLs & batch pasted lists (with/without bullets)
   [+] Pre-resolved direct links (https://dl.fuckingfast.co/dl/...)
 =============================================================================
"""


def get_clipboard_text() -> str:
    """Read current Windows clipboard text"""
    try:
        cmd = subprocess.run(["powershell", "-NoProfile", "-Command", "Get-Clipboard"],
                             capture_output=True, text=True, timeout=3)
        return cmd.stdout.strip()
    except Exception:
        return ""


def copy_to_clipboard(text: str):
    """Copy text to Windows clipboard using clip.exe"""
    try:
        subprocess.run(["clip.exe"], input=text.strip().encode("utf-8"), check=True)
        print("  [+] Copied all direct links to Windows Clipboard!")
    except Exception:
        pass


def get_idm_exe():
    for p in IDM_PATHS:
        if os.path.isfile(p):
            return p
    return None


def parse_links_from_text(raw_text: str) -> list[str]:
    """Extract all FuckingFast URLs from raw text, ignoring bullets (- , *), markdown, and whitespace"""
    found = re.findall(r'https?://(?:dl\.)?fuckingfast\.co/[^\s"\'<>]+', raw_text)
    seen = set()
    links = []
    for l in found:
        # Strip trailing markdown/punctuation
        clean = l.rstrip('.,;*)\'"')
        if clean not in seen:
            seen.add(clean)
            links.append(clean)
    return links


def detect_game_name(urls: list[str], input_source: str = "") -> str:
    """Automatically detect game name from repack page URL, anchors (#Game_Name_--_...), or files"""
    # 1. Check FitGirl game page URL
    if "fitgirl-repacks.site" in input_source and "paste." not in input_source:
        clean = input_source.strip().rstrip('/')
        slug = clean.split('/')[-1]
        if slug and slug != "fitgirl-repacks.site":
            return slug.replace("-", "_")

    # 2. Check URL anchors for game name (#The_Witcher_3_Remastered_--_...)
    for u in urls:
        if '#' in u:
            anchor = u.split('#')[-1]
            m = re.match(r'^([A-Za-z0-9_.\-]+?)(?:_--_|--|\.part\d|\.rar|\.bin)', anchor, re.IGNORECASE)
            if m:
                name = m.group(1).rstrip('_.-')
                if name and not name.lower().startswith("fg-"):
                    return name

    # 3. Check local file name
    if os.path.isfile(input_source):
        base = os.path.splitext(os.path.basename(input_source))[0]
        if base and base.lower() not in ("urls", "links", "input"):
            return base

    # 4. Fallback timestamped name
    now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"fitgirl_links_{now_str}"


async def extract_links_from_paste(page, paste_url: str) -> list[str]:
    """Open and decrypt a PrivateBin paste page (paste.fitgirl-repacks.site)"""
    print(f"\n[1/3] Accessing encrypted paste: {paste_url}")
    print("      Decrypting paste in headless browser...")
    await page.goto(paste_url, wait_until="networkidle", timeout=45000)
    await asyncio.sleep(2.5)

    body_text = await page.evaluate("() => document.body ? document.body.innerText : ''")
    links = parse_links_from_text(body_text)

    print(f"      Successfully extracted {len(links)} FuckingFast link(s) from paste.")
    return links


async def extract_links_from_fitgirl_page(page, repack_url: str) -> list[str]:
    """Scrape FuckingFast links from a FitGirl repack page"""
    print(f"\n[1/3] Loading FitGirl repack page: {repack_url}")
    await page.goto(repack_url, wait_until="load", timeout=45000)
    await asyncio.sleep(2)

    content = await page.content()
    links = parse_links_from_text(content)

    print(f"      Found {len(links)} FuckingFast link(s) on repack page.")
    return links


async def extract_direct_download(page, url: str, retries: int = 3) -> str | None:
    """Extract direct download link handling Cloudflare Turnstile, HTMX & ad popunders.
       If URL is ALREADY a direct link (e.g. dl.fuckingfast.co/dl/...), returns it immediately."""
    clean_url = url.split('#')[0].strip()
    if not clean_url:
        return None

    # Handle accidentally pasted direct download links!
    if "/dl/" in clean_url and "dl.fuckingfast.co" in clean_url:
        return clean_url

    for attempt in range(1, retries + 1):
        found_link = None

        def handle_download(d):
            nonlocal found_link
            found_link = d.url

        def handle_popup(p):
            # Auto-close ad popunders immediately
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
            await page.goto(clean_url, wait_until="load", timeout=30000)
            await asyncio.sleep(1.5)

            btn = page.locator('a:has-text("DOWNLOAD")')
            if await btn.count() > 0:
                # Click 1: triggers ad popup
                await btn.first.click()
                await asyncio.sleep(0.8)
                # Click 2: triggers download stream / HX-Redirect
                await btn.first.click()

                for _ in range(25):
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

        await asyncio.sleep(1.5)

    return None


async def run_pipeline(input_source: str, output_path: str | None = None, exclude_bonus: bool = False, keep_lang: str | None = "english"):
    raw_urls = []

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

        clean_input = input_source.strip().strip('"').strip("'")

        # Check if input is a PrivateBin paste
        if "paste.fitgirl-repacks.site" in clean_input and "\n" not in clean_input:
            raw_urls = await extract_links_from_paste(page, clean_input)
        # Check if input is a FitGirl game repack page
        elif "fitgirl-repacks.site" in clean_input and "\n" not in clean_input:
            raw_urls = await extract_links_from_fitgirl_page(page, clean_input)
        # Check if input is a file path
        elif os.path.isfile(clean_input):
            print(f"\n[1/3] Reading links from local file: {clean_input}")
            with open(clean_input, "r", encoding="utf-8") as f:
                raw_urls = parse_links_from_text(f.read())
            print(f"      Read {len(raw_urls)} link(s) from file.")
        # Check if input contains raw pasted link(s) or batch multi-line paste
        else:
            raw_urls = parse_links_from_text(clean_input)
            if raw_urls:
                print(f"\n[1/3] Parsed {len(raw_urls)} FuckingFast link(s) from pasted text.")

        if not raw_urls:
            print("\n[-] No valid FuckingFast links found to process.")
            await browser.close()
            return

        # Smart Game-Specific Output Naming
        game_name = detect_game_name(raw_urls, clean_input)
        if not output_path:
            output_path = os.path.join(DOWNLOAD_DIR, f"{game_name}_links.txt")

        # Smart Filtering
        filtered_urls = []
        for url in raw_urls:
            lower = url.lower()
            if exclude_bonus and "fg-optional" in lower:
                continue

            if "fg-selective" in lower:
                if keep_lang:
                    # Keep only matching language voiceovers (default English)
                    if keep_lang.lower() in lower:
                        filtered_urls.append(url)
                    continue
                else:
                    filtered_urls.append(url)
                    continue

            filtered_urls.append(url)

        if len(filtered_urls) < len(raw_urls):
            diff = len(raw_urls) - len(filtered_urls)
            lang_note = f" (kept '{keep_lang}' only)" if keep_lang else ""
            print(f"      Filter applied: excluded {diff} optional/foreign files{lang_note}.")
            print(f"      {len(filtered_urls)} file(s) queued for download.")

        # Step 2: Resolve direct download links
        print(f"\n[2/3] Resolving {len(filtered_urls)} direct download links for '{game_name}'...")
        print("      (Shared stealth browser session bypassing Cloudflare & HTMX)")

        results = []
        total = len(filtered_urls)
        for i, url in enumerate(filtered_urls, 1):
            name_hint = url.split('#')[-1] if '#' in url else f"Part {i}"

            # Check if link was ALREADY a direct dl.fuckingfast.co/dl/... link
            if "/dl/" in url and "dl.fuckingfast.co" in url:
                sys.stdout.write(f"  [{i}/{total}] {name_hint[:50]}... (Already direct link) OK!\n")
                sys.stdout.flush()
                results.append(url.split('#')[0].strip())
                continue

            sys.stdout.write(f"  [{i}/{total}] Resolving {name_hint[:50]}... ")
            sys.stdout.flush()

            direct = await extract_direct_download(page, url)
            if direct:
                results.append(direct)
                sys.stdout.write("OK!\n")
            else:
                sys.stdout.write("FAILED\n")
            sys.stdout.flush()
            await asyncio.sleep(0.8)

        await browser.close()

    # Step 3: Finalize and IDM integration
    print("\n[3/3] Finalizing results...")
    if results:
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            for link in results:
                f.write(link + "\n")

        print(f"\n" + "=" * 65)
        print(f"  SUCCESS: {len(results)}/{len(filtered_urls)} direct links resolved!")
        print(f"  Game: {game_name}")
        print(f"  Saved to file: {output_path}")
        copy_to_clipboard("\n".join(results))
        print("=" * 65)

        # IDM integration prompt
        idm_exe = get_idm_exe()
        if idm_exe:
            print("\n[+] Internet Download Manager (IDM) detected!")
            ans = input(">> Would you like to launch IDM now? [Y/N, default=Y]: ").strip().lower()
            if ans == "" or ans == "y":
                subprocess.Popen([idm_exe])
                print("[+] IDM launched!")
                print("[+] In IDM: Click 'Tasks' -> 'Add batch download from clipboard'")
                print(f"           or 'Tasks' -> 'Import' -> 'From text file' ({os.path.basename(output_path)})")
        else:
            print("\nIn IDM: Click Tasks -> Import -> From text file and select:")
            print(f"  {output_path}")

        # Highlight output file in Windows File Explorer
        try:
            subprocess.run(["explorer.exe", f"/select,{output_path}"], check=False)
        except Exception:
            pass

    else:
        print("\n[-] No links could be resolved.")

    print("\nPress Enter to exit...")
    input()


def interactive_menu():
    print(BANNER)

    # 1. Check if Windows Clipboard already has links or FitGirl URL!
    clip_text = get_clipboard_text()
    clip_links = parse_links_from_text(clip_text)
    src = ""

    if clip_links or "paste.fitgirl-repacks.site" in clip_text or "fitgirl-repacks.site" in clip_text:
        count_desc = f"{len(clip_links)} FuckingFast link(s)" if clip_links else "FitGirl URL"
        print(f"[+] Clipboard auto-detect: Found {count_desc} in your Windows Clipboard!")
        ans = input(">> Press [ENTER] to use your clipboard, or type [P] to paste manually: ").strip().lower()
        if ans == "" or ans == "y":
            src = clip_text

    # 2. Manual paste if not using clipboard
    if not src:
        print("\n>> Paste your URL, file path, or batch links below.")
        print("   (Supports multi-line paste with or without bullets; press Enter when done):")
        lines = []
        while True:
            try:
                line = input()
                if not line.strip():
                    if lines:
                        break
                    continue
                lines.append(line)
                # If a single URL was entered and no more lines follow in buffer:
                if len(lines) == 1 and ("paste.fitgirl-repacks.site" in line or "fitgirl-repacks.site" in line or os.path.isfile(line.strip().strip('"'))):
                    break
            except EOFError:
                break
        src = "\n".join(lines)

    if not src.strip():
        print("[!] No input provided. Exiting.")
        return

    print("\n" + "=" * 65)
    print("Step 2: Filters & Language Preferences")
    print("=" * 65)

    ans_bonus = input(">> Exclude optional bonus content (soundtracks/trailers)? [Y/N, default=N]: ").strip().lower()
    exclude_bonus = (ans_bonus == "y")

    print("\nLanguage options:")
    print("  [Y] Keep ENGLISH ONLY (skip other language voiceovers) [Recommended]")
    print("  [N] Download ALL languages")
    print("  [Or type a language name: e.g. spanish, japanese, french]")
    ans_lang = input(">> Your language choice [Y/N, default=Y]: ").strip().lower()

    if ans_lang == "" or ans_lang == "y":
        keep_lang = "english"
    elif ans_lang == "n":
        keep_lang = None
    else:
        keep_lang = ans_lang

    asyncio.run(run_pipeline(src, None, exclude_bonus, keep_lang))


def main():
    parser = argparse.ArgumentParser(description="Extract direct FuckingFast download links from FitGirl pastes/pages")
    parser.add_argument("source", nargs="?", help="Pastebin URL, FitGirl page URL, text file path, or link")
    parser.add_argument("-o", "--output", default=None, help="Output file (default: <Game_Name>_links.txt in Downloads)")
    parser.add_argument("--no-bonus", action="store_true", help="Exclude bonus files (fg-optional*)")
    parser.add_argument("--lang", default="english", help="Keep ONLY this selective language (default: english, or 'all')")
    args = parser.parse_args()

    if not args.source:
        interactive_menu()
    else:
        keep_lang = None if args.lang.lower() in ("all", "none") else args.lang
        asyncio.run(run_pipeline(args.source, args.output, args.no_bonus, keep_lang))


if __name__ == "__main__":
    main()
