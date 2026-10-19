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

## Download & 1-Click Launch

No git, no cloning, and no copying raw code required! Simply download from the [Official Release](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/tag/v1.0.0):

* 🚀 **[Download Standalone BAT (`Download_FitGirl_Links.bat`)](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/download/v1.0.0/Download_FitGirl_Links.bat)**  
  *(Direct single-file download)*
* 📦 **[Download ZIP Archive (`FitGirl_Link_Extractor_v1.0.0.zip`)](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/download/v1.0.0/FitGirl_Link_Extractor_v1.0.0.zip)**  
  *(Pre-packaged zip containing the launcher)*

---

## How to Use

1. Double-click **`Download_FitGirl_Links.bat`**.
2. **Step 1:** Paste any **`paste.fitgirl-repacks.site`** link, FitGirl game page URL, or text file path.
3. **Step 2:** Choose your filter options:
   * Keep English only (automatically skips 20–30GB of foreign audio packs!).
   * Exclude optional bonus files (soundtracks, trailers).
4. **Step 3:** The tool decrypts the paste, solves Cloudflare challenges in the background, and generates direct download links.
5. **Step 4:** All links are copied to your Windows Clipboard and saved to `idm_links.txt`. IDM is detected and launched automatically!

---

## Features

- **100% Self-Contained**: Polyglot Batch/Python architecture—single file with zero external script dependencies.
- **Auto-Configuring**: Automatically installs missing dependencies (`playwright`, `playwright-stealth`, `requests`, `beautifulsoup4`) on first launch if needed.
- **PrivateBin Decryption**: Natively decrypts `paste.fitgirl-repacks.site/?id#key` URLs client-side.
- **Cloudflare & HTMX Bypass**: Stealth browser profile handles Cloudflare Turnstile and the 2-click ad popunder flow.
- **Smart Language Filtering**: Selects English voiceover (`fg-selective-english*.bin`) and drops unnecessary languages to save bandwidth and storage.
- **IDM Integration**: Auto-detects IDM, copies links to clipboard, and highlights the output file in File Explorer.

## Manual Clone (For Developers)

```bash
git clone https://github.com/EditByDenzel/fitgirl-link-generator-updated.git
cd fitgirl-link-generator-updated
Download_FitGirl_Links.bat
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
