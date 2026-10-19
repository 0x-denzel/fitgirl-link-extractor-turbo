# FitGirl Turbo Link Extractor

A high-performance multi-hoster engine that automatically extracts direct CDN download URLs from **FitGirl Repacks**, **PrivateBin pastes**, **FuckingFast (`fuckingfast.co`)**, **FileKeeper (`filekeeper.net`)**, and **DataNodes (`datanodes.to`)**, as well as instant **Magnet & .torrent file mirrors**, ready for 1-click batch downloading in **Internet Download Manager (IDM)**, **JDownloader**, **Free Download Manager (FDM)**, and torrent clients across Windows and macOS.

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

| Mirror / Hoster | Category | Extraction Speed | Description & Integration |
| :--- | :--- | :--- | :--- |
| **FileKeeper** (`filekeeper.net`) | Direct Download | ~1.5s / link | **Recommended** — High-speed turbo tunnel mirrors (`dlproxy.uk`), 0 countdown |
| **FuckingFast** (`fuckingfast.co`) | Direct Download | ~2.5s / link | Direct high-speed CDN with automated Turnstile & HTMX handling |
| **DataNodes** (`datanodes.to`) | Direct Download | ~6.0s / link | Cloud storage mirrors with countdown handling |
| **Magnet Links** | Torrent Mirror | Instant | 1-click launch into default torrent client (qBittorrent / BitTorrent) |
| **.torrent File Download** | Torrent Mirror | ~2.0s | Decrypts PrivateBin attachment and downloads `.torrent` directly to `Downloads` |
| **Tracker Pages (1337x / Tapochek)** | Torrent Mirror | Instant | Copies tracker URL to clipboard and opens in browser |

---

## 1-Click Launch

No git, no cloning, and no copying raw code required! Simply download the standalone file for your OS:

* 🚀 **Windows**: Download [**`Download_FitGirl_Links.bat`**](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/latest) and double-click to launch.
* 🍎 **macOS**: Download [**`Download_FitGirl_Links.command`**](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/latest), place in the same folder as the script, and double-click to launch.

---

## How It Works

1. **Copy your link**: Copy any FitGirl repack game page (e.g. `fitgirl-repacks.site/game-name/`), `paste.fitgirl-repacks.site` URL, or list of hoster URLs to your clipboard.
2. **Launch the Engine**: Double-click `Download_FitGirl_Links.bat` (Windows) or `Download_FitGirl_Links.command` (macOS). The engine auto-detects links directly from your clipboard!
3. **Interactive Mirror Selector (Repack Pages)**:
   * When pasting a repack game page URL, the tool scans all available mirrors in ~300ms.
   * Choose between **Direct Download Hosters** (FileKeeper, FuckingFast, DataNodes) or **Torrent Mirrors** (Magnet, .torrent file, 1337x).
4. **Filter Your Downloads**:
   * **Language Voiceovers**: Choose to keep English only (automatically skipping 20–30 GB of foreign audio files!).
   * **Bonus Files**: Option to exclude soundtracks, trailers, and developer commentary (`fg-optional*`).
5. **Instant Resolution & Graceful Cancellation**:
   * Direct links are resolved in-place with real-time progress bars and ASCII indicators (`➜ OK!`).
   * Press `Ctrl + C` anytime to safely cancel and preserve whatever links were already resolved.
6. **Download Manager & Torrent Handoff**:
   * Direct links are instantly written to `<Game_Name>_links.txt` in your `Downloads` directory and copied to your clipboard.
   * Highlights the file in Windows File Explorer / macOS Finder immediately.
   * Auto-detects and prompts to launch **IDM**, **JDownloader 2**, or **Free Download Manager** (or qBittorrent/BitTorrent for torrents).

---

## Core Features

- **Interactive Repack Mirror Selector**: Paste any FitGirl game page URL to inspect and choose your preferred direct hoster or torrent source.
- **Direct .torrent File Extractor**: Decrypts PrivateBin `.torrent` file attachments silently in the background and saves them to `~/Downloads/`.
- **Multi-Hoster Engine**: Seamlessly handles FileKeeper, FuckingFast, and DataNodes mirrors.
- **Graceful Cancellation**: Cancel anytime (`Ctrl+C`) without losing progress—partially resolved links are preserved, saved, and copied to clipboard.
- **100% Self-Contained Polyglot**: Runs directly on Windows and macOS with zero external setup scripts.
- **Zero-Drop Clipboard Engine**: Uses native Win32 `ctypes` on Windows (0ms, no timeouts) and `pbpaste` on macOS.
- **PrivateBin Client Decryption**: Natively decrypts 128-bit AES encrypted FitGirl PrivateBin pastes client-side.
- **Dead Link Detection**: Instantly marks deleted or 404 links as `[REMOVED/404]` without hanging.
- **Smart Game Detection**: Automatically titles output text files using URL anchors and repack slugs (e.g. `God_of_War_III_Remastered_links.txt`).
- **Interactive Multi-Game Loop**: Queue and process multiple games consecutively in one terminal session.

---

## Command Line Usage

For power users, scripts, and automations:

```bash
# Process a FitGirl repack page (opens mirror selector)
Download_FitGirl_Links.bat "http://fitgirl-repacks.site/god-of-war-3-remastered/"

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
