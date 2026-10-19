# FitGirl Turbo Link Extractor

A high-performance multi-hoster engine that automatically extracts direct CDN download URLs from **FitGirl Repacks**, **PrivateBin pastes**, **FuckingFast (`fuckingfast.co`)**, **FileKeeper (`filekeeper.net`)**, and **DataNodes (`datanodes.to`)**, ready for 1-click batch downloading in **Internet Download Manager (IDM)**, **JDownloader**, and **Free Download Manager (FDM)** across Windows and macOS.

```text
 =============================================================================
    ______ _ _    _____ _      _   _______             _           
   |  ____(_) |  / ____(_)    | | |__   __|           | |          
   | |__   _| |_| |  __ _ _ __| |    | | _   _ _ __   | |__   ___  
   |  __| | | __| | |_ | | '__| |    | || | | | '__|  | '_ \ / _ \ 
   | |    | | |_| |__| | | |  | |    | || |_| | |     | |_) | (_) |
   |_|    |_|\__|\_____|_|_|  |_|    |_| \__,_|_|     |_.__/ \___/ 

             >>> BY 0xDENZEL | Website | Buy Me a Coffee <<<
 =============================================================================
```

## Supported Hosters & Mirrors

| Hoster | Mirror Type | Extraction Speed | Cloudflare/Ad Clearance |
| :--- | :--- | :--- | :--- |
| **FuckingFast** (`fuckingfast.co`) | Direct High-Speed CDN | ~2.5s / link | Automatic Stealth Resolution |
| **FileKeeper** (`filekeeper.net`) | Turbo Tunnel Mirrors | ~1.5s / link | Instant Direct Form Dispatch |
| **DataNodes** (`datanodes.to`) | Cloud Storage Mirrors | ~6.0s / link | Interactive Turnstile Clearance |

---

## 1-Click Launch

No git, no cloning, and no copying raw code required! Simply download the standalone file for your OS:

* 🚀 **Windows**: Download [**`Download_FitGirl_Links.bat`**](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/latest) and double-click to launch.
* 🍎 **macOS**: Download [**`Download_FitGirl_Links.command`**](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/latest), place in the same folder as the script, and double-click to launch.

---

## How It Works

1. **Copy your links**: Copy any `paste.fitgirl-repacks.site` PrivateBin URL, FitGirl repack game page, or list of hoster URLs to your clipboard.
2. **Launch the Engine**: Double-click `Download_FitGirl_Links.bat` (Windows) or `Download_FitGirl_Links.command` (macOS). The script auto-detects the links directly from your clipboard!
3. **Filter Your Downloads**:
   * **Language Voiceovers**: Choose to keep English only (automatically skipping 20–30 GB of foreign audio files!).
   * **Bonus Files**: Option to exclude soundtracks, trailers, and developer commentary (`fg-optional*`).
4. **Instant Resolution**: The engine resolves direct links in-place with real-time progress bars and ASCII status indicators (`➜ OK!`).
5. **Download Manager Handoff**:
   * Links are instantly written to `<Game_Name>_links.txt` in your `Downloads` directory.
   * Links are copied to your system Clipboard.
   * Highlights the file in Windows File Explorer / macOS Finder immediately.
   * Auto-detects and prompts to launch **IDM**, **JDownloader 2**, or **Free Download Manager**.

---

## Core Features

- **Multi-Hoster Engine**: Seamlessly handles FuckingFast, FileKeeper, and DataNodes mirrors.
- **100% Self-Contained Polyglot**: Runs directly on Windows and macOS with zero external setup scripts.
- **Zero-Drop Clipboard Engine**: Uses native Win32 `ctypes` on Windows (0ms, no timeouts) and `pbpaste` on macOS.
- **PrivateBin Client Decryption**: Natively decrypts 128-bit AES encrypted FitGirl PrivateBin pastes client-side.
- **Dead Link Detection**: Instantly marks deleted or 404 links as `[REMOVED/404]` without hanging.
- **Smart Game Detection**: Automatically titles output text files using URL anchors and repack slugs (e.g. `CoD_MW4_links.txt`).
- **Interactive Multi-Game Loop**: Queue and process multiple games consecutively in one terminal session.

---

## Command Line Usage

For power users, scripts, and automations:

```bash
# Process a FitGirl PrivateBin paste
Download_FitGirl_Links.bat "https://paste.fitgirl-repacks.site/?b12063dd4f520470#6yU4dxuF8EYy8VcYoGF92hn4QLsTJrGfrsdLCS6jPZ6r"

# Process with custom output and language filter
Download_FitGirl_Links.bat "links.txt" -o "C:\Downloads\my_game.txt" --lang english --no-bonus
```

---

## Developer Setup

```bash
git clone https://github.com/EditByDenzel/fitgirl-link-generator-updated.git
cd fitgirl-link-generator-updated
python -x Download_FitGirl_Links.bat
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
