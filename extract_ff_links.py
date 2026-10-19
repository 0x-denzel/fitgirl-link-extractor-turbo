"""
Batch Link Extractor for FuckingFast & FitGirl Repacks (IDM Ready)
Supports:
  - PrivateBin paste URLs (e.g. https://paste.fitgirl-repacks.site/?id#key)
  - FitGirl repack web pages (e.g. https://fitgirl-repacks.site/game-name/)
  - Text files containing links
  - Raw fuckingfast.co links
"""

import asyncio
import sys
import os
import re
import subprocess
import argparse
from playwright.async_api import async_playwright
from playwright_stealth import Stealth

DOWNLOAD_DIR = os.path.join(os.path.expanduser("~"), "Downloads")
DEFAULT_OUTPUT = os.path.join(DOWNLOAD_DIR, "idm_links.txt")
IDM_PATH = r"C:\Program Files (x86)\Internet Download Manager\IDMan.exe"


def copy_to_clipboard(text: str):
    """Copy text to Windows clipboard using clip.exe"""
    try:
        subprocess.run(["clip.exe"], input=text.strip().encode("utf-8"), check=True)
        print("  [+] Copied all direct links to Windows Clipboard!")
    except Exception:
        pass


async def extract_links_from_paste(page, paste_url: str) -> list[str]:
    """Open and decrypt a PrivateBin paste page (paste.fitgirl-repacks.site)"""
    print(f"\n[1/3] Accessing encrypted paste: {paste_url}")
    print("      Decrypting paste in headless browser...")
    await page.goto(paste_url, wait_until="networkidle", timeout=45000)
    await asyncio.sleep(2.5)

    body_text = await page.evaluate("() => document.body ? document.body.innerText : ''")
    found = re.findall(r'https://fuckingfast\.co/[^\s"\'<>]+', body_text)

    # Deduplicate while preserving order
    seen = set()
    links = []
    for l in found:
        if l not in seen:
            seen.add(l)
            links.append(l)

    print(f"      Successfully extracted {len(links)} FuckingFast link(s) from paste.")
    return links


async def extract_links_from_fitgirl_page(page, repack_url: str) -> list[str]:
    """Scrape FuckingFast links from a FitGirl repack page"""
    print(f"\n[1/3] Loading FitGirl repack page: {repack_url}")
    await page.goto(repack_url, wait_until="load", timeout=45000)
    await asyncio.sleep(2)

    content = await page.content()
    found = re.findall(r'https://fuckingfast\.co/[^\s"\'<>]+', content)

    seen = set()
    links = []
    for l in found:
        if l not in seen:
            seen.add(l)
            links.append(l)

    print(f"      Found {len(links)} FuckingFast link(s) on repack page.")
    return links


async def extract_direct_download(page, url: str, retries: int = 3) -> str | None:
    """Extract direct download link handling Cloudflare Turnstile, HTMX & ad popunders"""
    clean_url = url.split('#')[0].strip()
    if not clean_url:
        return None

    for attempt in range(1, retries + 1):
        found_link = None

        def handle_download(d):
            nonlocal found_link
            found_link = d.url

        def handle_popup(p):
            # Immediately close ad popunders
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


async def run_pipeline(input_source: str, output_path: str, exclude_bonus: bool = False, exclude_lang: bool = False):
    print("=" * 65)
    print("      FITGIRL & FUCKINGFAST BATCH LINK EXTRACTOR")
    print("=" * 65)

    raw_urls = []

    async with async_playwright() as p:
        # Launch stealth Chrome instance
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

        # Step 1: Discover / collect all target links
        clean_input = input_source.strip().strip('"').strip("'")

        if "paste.fitgirl-repacks.site" in clean_input:
            raw_urls = await extract_links_from_paste(page, clean_input)
        elif "fitgirl-repacks.site" in clean_input:
            raw_urls = await extract_links_from_fitgirl_page(page, clean_input)
        elif os.path.isfile(clean_input):
            print(f"\n[1/3] Reading links from local file: {clean_input}")
            with open(clean_input, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("http"):
                        raw_urls.append(line)
            print(f"      Read {len(raw_urls)} link(s) from file.")
        elif clean_input.startswith("http"):
            raw_urls = [clean_input]
        else:
            print(f"Error: Unrecognized input: {clean_input}")
            await browser.close()
            return

        if not raw_urls:
            print("\n[-] No FuckingFast links found to process.")
            await browser.close()
            return

        # Optional filters
        filtered_urls = []
        for url in raw_urls:
            lower = url.lower()
            if exclude_bonus and "fg-optional" in lower:
                continue
            if exclude_lang and "fg-selective" in lower:
                continue
            filtered_urls.append(url)

        if len(filtered_urls) < len(raw_urls):
            print(f"      Applied filters: {len(filtered_urls)} links remaining (excluded bonus/languages).")

        # Step 2: Resolve direct download links
        print(f"\n[2/3] Resolving {len(filtered_urls)} direct download links...")
        print("      (Shared browser session bypassing Cloudflare & HTMX)")

        results = []
        total = len(filtered_urls)
        for i, url in enumerate(filtered_urls, 1):
            name_hint = url.split('#')[-1] if '#' in url else f"Part {i}"
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

    # Step 3: Save results and handle IDM integration
    print("\n[3/3] Finalizing results...")
    if results:
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            for link in results:
                f.write(link + "\n")

        print(f"\n" + "=" * 65)
        print(f"  SUCCESS: {len(results)}/{len(filtered_urls)} links resolved!")
        print(f"  Saved to file: {output_path}")
        copy_to_clipboard("\n".join(results))
        print("=" * 65)
        print("\nIDM Batch Download Instructions:")
        print("  Option A (Direct File): In IDM, click Tasks -> Import -> From text file")
        print(f"                          and select: {output_path}")
        print("  Option B (Clipboard):   In IDM, click Tasks -> Add batch download from clipboard")
        print("=" * 65)
    else:
        print("\n[-] No links could be resolved.")


def main():
    parser = argparse.ArgumentParser(description="Extract direct FuckingFast download links from FitGirl pastes/pages")
    parser.add_argument("source", nargs="?", help="Pastebin URL, FitGirl page URL, text file path, or link")
    parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT, help=f"Output file (default: {DEFAULT_OUTPUT})")
    parser.add_argument("--no-bonus", action="store_true", help="Exclude bonus files (fg-optional*)")
    parser.add_argument("--no-lang", action="store_true", help="Exclude selective language files (fg-selective*)")
    args = parser.parse_args()

    source = args.source
    if not source:
        print("=" * 65)
        print("      FITGIRL & FUCKINGFAST BATCH LINK EXTRACTOR")
        print("=" * 65)
        print("You can paste any of the following:")
        print("  1. A paste.fitgirl-repacks.site URL (with the #key)")
        print("  2. A fitgirl-repacks.site game page URL")
        print("  3. Path to a .txt file containing links")
        print("  4. A direct fuckingfast.co URL")
        print("-" * 65)
        source = input("Paste your URL or file path here: ").strip()

    if not source:
        print("No input provided. Exiting.")
        return

    output = os.path.abspath(args.output)
    asyncio.run(run_pipeline(source, output, args.no_bonus, args.no_lang))


if __name__ == "__main__":
    main()
