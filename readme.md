# FitGirl Link Generator (Updated Standalone Edition)

A high-performance tool that extracts direct download URLs from **FitGirl Repacks**, **PrivateBin pastes**, and **FuckingFast**, ready for 1-click batch downloading in **Internet Download Manager (IDM)** and **JDownloader**.

```text
 =============================================================================
    ______ _ _    _____ _      _   _      _       _        
   |  ____(_) |  / ____(_)    | | | |    (_)     | |       
   | |__   _| |_| |  __ _ _ __| | | |     _ _ __ | | _____ 
   |  __| | | __| | |_ | | '__| | | |    | | '_ \| |/ / __|
   | |    | | |_| |__| | | |  | | | |____| | | | |   <\__ \
   |_|    |_|\__|\_____|_|_|  |_| |______|_|_| |_|_|\_\___/

                      >>> BY 0xDENZEL <<<
 =============================================================================
```

## Quick Start (Single File Download)

You don't need to clone the whole repository! You can just download the single standalone launcher:

👉 **[Download `Download_FitGirl_Links.bat`](https://raw.githubusercontent.com/EditByDenzel/fitgirl-link-generator-updated/master/Download_FitGirl_Links.bat)** *(Right-click $\rightarrow$ Save link as...)*

1. Double-click `Download_FitGirl_Links.bat`.
2. Paste any **`paste.fitgirl-repacks.site`** link, FitGirl game page URL, or text file.
3. Select your filter (keeps English voiceovers, skips extra 20–30GB foreign languages).
4. Links are automatically copied to your clipboard and saved to `idm_links.txt`.
5. IDM opens automatically—click **Tasks $\rightarrow$ Add batch download from clipboard**!

---

## Features

- **100% Self-Contained `.bat`**: Merged Python and Batch polyglot—no separate `.py` files to lose. Auto-installs missing dependencies on first launch.
- **PrivateBin Paste Decryption**: Natively decrypts `paste.fitgirl-repacks.site/?id#key` URLs client-side.
- **Cloudflare Turnstile & Bot Bypass**: Stealth browser configuration solves Turnstile challenges seamlessly in headless mode.
- **HTMX & Ad Popunder Handling**: Closes advertising popunders and captures `HX-Redirect` and direct download streams.
- **Smart Language Filtering**: Keeps English audio (`fg-selective-english*.bin`) and drops unnecessary foreign voiceovers, saving 20–30GB per repack.
- **IDM Integration**: Auto-detects IDM, copies links to clipboard, and highlights the output file in File Explorer.

## Manual Installation (Full Repo)

```bash
git clone https://github.com/EditByDenzel/fitgirl-link-generator-updated.git
cd fitgirl-link-generator-updated
```

Run via:
```cmd
Download_FitGirl_Links.bat
```
*(or via Python: `python app.py --help`)*

## License

This project is licensed under the MIT License - see the LICENSE file for details.
