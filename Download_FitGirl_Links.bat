@echo off & (python -x "%~f0" %* || (echo. & echo [!] Python is not installed or not in PATH. Please install Python 3.8+ from https://www.python.org/ & echo [Make sure to check 'Add Python to PATH' during installation] & echo. & pause)) & exit /b
# =============================================================================
#  FITGIRL & FUCKINGFAST LINK EXTRACTOR - STANDALONE ENGINE
#  Author: 0xdenzel (chideraokonkwo.com)
# =============================================================================
import asyncio
import sys
import os
import re
import datetime
import subprocess
import argparse

# Enable Windows ANSI Virtual Terminal Colors
if sys.platform == "win32":
    os.system('')

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

DOWNLOAD_DIR = os.path.join(os.path.expanduser("~"), "Downloads")
IDM_PATHS = [
    r"C:\Program Files (x86)\Internet Download Manager\IDMan.exe",
    r"C:\Program Files\Internet Download Manager\IDMan.exe"
]

BANNER = f"""
{C_CYAN}{C_BOLD} =============================================================================
    ______ _ _    _____ _      _   _      _       _        
   |  ____(_) |  / ____(_)    | | | |    (_)     | |       
   | |__   _| |_| |  __ _ _ __| | | |     _ _ __ | | _____ 
   |  __| | | __| | |_ | | '__| | | |    | | '_ \| |/ / __|
   | |    | | |_| |__| | | |  | | | |____| | | | |   <\__ \\
   |_|    |_|\__|\_____|_|_|  |_| |______|_|_| |_|_|\_\___/

             {C_YELLOW}>>> BY 0xDENZEL | https://chideraokonkwo.com | Tip: buymeacoffee.com/0xdenzel <<<{C_CYAN}{C_BOLD}
 ============================================================================={C_RESET}
  {C_WHITE}Automated direct link resolver for IDM & JDownloader{C_RESET}
  {C_DIM}Supports:
   [+] FitGirl PrivateBin pastes (paste.fitgirl-repacks.site/?id#key)
   [+] FitGirl Repack game pages (fitgirl-repacks.site/game-name/)
   [+] Raw FuckingFast links (single or multi-line with/without bullets)
   [+] Text files (.txt) containing links
   [+] Instant passthrough for already direct links (dl.fuckingfast.co/dl/...){C_RESET}
{C_CYAN}{C_BOLD} ============================================================================={C_RESET}
"""


def clear_screen():
    """Clear terminal screen to keep the header static at the top"""
    if sys.platform == "win32":
        os.system("cls")
    else:
        os.system("clear")


def get_clipboard_text() -> str:
    """Cross-platform clipboard reader (Windows & macOS & Linux)"""
    try:
        if sys.platform == "darwin":
            cmd = subprocess.run(["pbpaste"], capture_output=True, text=True, timeout=2)
            return cmd.stdout.strip()
        elif sys.platform == "win32":
            cmd = subprocess.run(["powershell", "-NoProfile", "-Command", "Get-Clipboard"],
                                 capture_output=True, text=True, timeout=3)
            return cmd.stdout.strip()
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


def get_idm_exe():
    if sys.platform != "win32":
        return None
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
        clean = l.rstrip('.,;*)\'"')
        if clean not in seen:
            seen.add(clean)
            links.append(clean)
    return links


def inspect_input(raw_text: str):
    """Inspect text and find all pastebin links, repack page links, and direct/raw FF links"""
    paste_links = re.findall(r'https?://paste\.fitgirl-repacks\.site/[^\s"\'<>]+', raw_text)
    repack_links = [u for u in re.findall(r'https?://fitgirl-repacks\.site/[^\s"\'<>]+', raw_text)
                    if not u.startswith("https://paste.") and not u.startswith("http://paste.")]
    ff_links = parse_links_from_text(raw_text)
    return paste_links, repack_links, ff_links


def detect_game_name(urls: list[str], input_source: str = "") -> str | None:
    """Detect game name from repack page URL, anchors (#Game_Name_--_...), or local file name"""
    if "fitgirl-repacks.site" in input_source and "paste." not in input_source:
        clean = input_source.strip().rstrip('/')
        slug = clean.split('/')[-1]
        if slug and slug != "fitgirl-repacks.site":
            return slug.replace("-", "_")

    for u in urls:
        if '#' in u:
            anchor = u.split('#')[-1]
            m = re.match(r'^([A-Za-z0-9_.\-]+?)(?:_--_|--|\.part\d|\.rar|\.bin)', anchor, re.IGNORECASE)
            if m:
                name = m.group(1).rstrip('_.-')
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
    print(f"         Decrypting paste in headless browser... ", end="", flush=True)
    await page.goto(paste_url, wait_until="networkidle", timeout=45000)
    await asyncio.sleep(2.5)

    body_text = await page.evaluate("() => document.body ? document.body.innerText : ''")
    links = parse_links_from_text(body_text)

    print(f"{C_GREEN}{C_BOLD}DONE{C_RESET}")
    print(f"         Extracted {C_BOLD}{len(links)}{C_RESET} FuckingFast link(s) from paste.")
    return links


async def extract_links_from_fitgirl_page(page, repack_url: str) -> list[str]:
    """Scrape FuckingFast links from a FitGirl repack page"""
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Loading FitGirl repack page: {C_CYAN}{repack_url}{C_RESET}")
    await page.goto(repack_url, wait_until="load", timeout=45000)
    await asyncio.sleep(2)

    content = await page.content()
    links = parse_links_from_text(content)

    print(f"         Found {C_BOLD}{len(links)}{C_RESET} FuckingFast link(s) on repack page.")
    return links


async def extract_direct_download(page, url: str, retries: int = 3) -> str | None:
    """Extract direct download link handling Cloudflare Turnstile, HTMX & ad popunders."""
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
            await page.goto(clean_url, wait_until="load", timeout=30000)
            await asyncio.sleep(1.5)

            btn = page.locator('a:has-text("DOWNLOAD")')
            if await btn.count() > 0:
                await btn.first.click()
                await asyncio.sleep(0.8)
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
    clean_input = input_source.strip().strip('"').strip("'")
    raw_urls = []

    if os.path.isfile(clean_input):
        print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Reading links from local file: {C_CYAN}{clean_input}{C_RESET}")
        with open(clean_input, "r", encoding="utf-8") as f:
            content = f.read()
        paste_links, repack_links, ff_links = inspect_input(content)
    else:
        paste_links, repack_links, ff_links = inspect_input(clean_input)

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

    if ff_links:
        if not paste_links and not repack_links:
            print(f"\n{C_MAGENTA}{C_BOLD}[Step 1]{C_RESET} Found {C_BOLD}{len(ff_links)}{C_RESET} FuckingFast link(s) directly from input (no pastebin needed).")
        raw_urls.extend(ff_links)

    # Deduplicate
    seen = set()
    deduped_urls = []
    for u in raw_urls:
        if u not in seen:
            seen.add(u)
            deduped_urls.append(u)
    raw_urls = deduped_urls

    if not raw_urls:
        print(f"\n{C_RED}[-] No valid FuckingFast links found to process.{C_RESET}")
        return

    # 2. Check if all links are direct
    direct_links_only = [u for u in raw_urls if "/dl/" in u and "dl.fuckingfast.co" in u]
    if len(direct_links_only) == len(raw_urls):
        print("\n" + f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")
        print(f"  {C_YELLOW}{C_BOLD}[+] NOTICE: All links provided are ALREADY direct download links!{C_RESET}")
        print(f"      {C_DIM}Skipping browser automation, Cloudflare checks, and filters.{C_RESET}")
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

        idm_exe = get_idm_exe()
        if idm_exe:
            print(f"\n{C_GREEN}[+] Internet Download Manager (IDM) detected!{C_RESET}")
            ans = input(f"{C_WHITE}{C_BOLD}>> Would you like to launch IDM now? [Y/N, default=Y]: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                subprocess.Popen([idm_exe])
                print(f"{C_GREEN}[+] IDM launched!{C_RESET}")
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
    print(f"         {C_DIM}(Shared stealth browser session bypassing Cloudflare & HTMX){C_RESET}")

    results = []
    total = len(filtered_urls)

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

        for i, url in enumerate(filtered_urls, 1):
            name_hint = url.split('#')[-1] if '#' in url else f"Part {i}"
            pct = int((i - 1) / total * 100)
            bar_len = 14
            filled = int(bar_len * (i - 1) / total)
            bar = "█" * filled + "░" * (bar_len - filled)

            if "/dl/" in url and "dl.fuckingfast.co" in url:
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
            if direct:
                results.append(direct)
                sys.stdout.write(f"\r  [{i}/{total}] {pct_done:3d}% |{bar_done}| {name_hint[:32]} ➜ {C_GREEN}{C_BOLD}OK!{C_RESET}     ")
            else:
                sys.stdout.write(f"\r  [{i}/{total}] {pct_done:3d}% |{bar_done}| {name_hint[:32]} ➜ {C_RED}{C_BOLD}FAILED{C_RESET}     ")
            sys.stdout.flush()
            await asyncio.sleep(0.8)

        sys.stdout.write("\n")
        await browser.close()

    # 6. Finalize output
    print(f"\n{C_MAGENTA}{C_BOLD}[Step 3]{C_RESET} Finalizing results...")
    if results:
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            for link in results:
                f.write(link + "\n")

        print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
        print(f"  {C_GREEN}{C_BOLD}SUCCESS: {len(results)}/{len(filtered_urls)} direct links resolved!{C_RESET}")
        print(f"  Game: {C_GREEN}{C_BOLD}{game_name}{C_RESET}")
        print(f"  Saved to file: {C_CYAN}{output_path}{C_RESET}")
        copy_to_clipboard("\n".join(results))
        print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")

        idm_exe = get_idm_exe()
        if idm_exe:
            print(f"\n{C_GREEN}[+] Internet Download Manager (IDM) detected!{C_RESET}")
            ans = input(f"{C_WHITE}{C_BOLD}>> Would you like to launch IDM now? [Y/N, default=Y]: {C_RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                subprocess.Popen([idm_exe])
                print(f"{C_GREEN}[+] IDM launched!{C_RESET}")
                print(f"    {C_DIM}In IDM: Click 'Tasks' -> 'Add batch download from clipboard'{C_RESET}")
                print(f"    {C_DIM}        or 'Tasks' -> 'Import' -> 'From text file' ({os.path.basename(output_path)}){C_RESET}")
        else:
            print(f"\n{C_WHITE}In IDM / JDownloader:{C_RESET} Import from text file or paste from clipboard:\n  {C_CYAN}{output_path}{C_RESET}")

        # Reveal file in OS file manager (Windows Explorer or macOS Finder)
        try:
            if sys.platform == "win32":
                subprocess.run(["explorer.exe", f"/select,{output_path}"], check=False)
            elif sys.platform == "darwin":
                subprocess.run(["open", "-R", output_path], check=False)
        except Exception:
            pass
    else:
        print(f"\n{C_RED}[-] No links could be resolved.{C_RESET}")


def interactive_menu():
    clear_screen()
    print(BANNER)

    clip_text = get_clipboard_text()
    p_links, r_links, f_links = inspect_input(clip_text)
    src = ""

    if p_links or r_links or f_links:
        desc_parts = []
        if p_links:
            desc_parts.append(f"{len(p_links)} FitGirl Pastebin URL(s)")
        if r_links:
            desc_parts.append(f"{len(r_links)} FitGirl Repack Page(s)")
        if f_links:
            desc_parts.append(f"{len(f_links)} FuckingFast link(s)")

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

    p_check, r_check, f_check = inspect_input(src)
    if f_check and not p_check and not r_check:
        direct_check = [u for u in f_check if "/dl/" in u and "dl.fuckingfast.co" in u]
        if len(direct_check) == len(f_check):
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
    parser = argparse.ArgumentParser(description="Extract direct FuckingFast download links from FitGirl pastes/pages")
    parser.add_argument("source", nargs="?", help="Pastebin URL, FitGirl page URL, text file path, or link")
    parser.add_argument("-o", "--output", default=None, help="Output file (default: <Game_Name>_links.txt in Downloads)")
    parser.add_argument("--no-bonus", action="store_true", help="Exclude bonus files (fg-optional*)")
    parser.add_argument("--lang", default="english", help="Keep ONLY this selective language (default: english, or 'all')")
    args = parser.parse_args()

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
        keep_lang = None if args.lang.lower() in ("all", "none") else args.lang
        asyncio.run(run_pipeline(args.source, args.output, args.no_bonus, keep_lang))


if __name__ == "__main__":
    main()
