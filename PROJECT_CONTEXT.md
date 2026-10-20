# FitGirl Turbo Link Extractor — Project Context & Session History

> **Location:** `C:\Users\user\Desktop\FitGirl-Link-Extractor`  
> **Repository:** `https://github.com/0x-denzel/fitgirl-link-extractor-turbo`  
> **Author:** Chidera Okonkwo (0xdenzel) · [Website](https://chideraokonkwo.com) · [GitHub](https://github.com/0x-denzel)  
> **Current Version:** v1.3.2  
> **Test Status:** 52 / 52 unit tests passing (100%)  

---

## 1. Project Overview & Architecture

FitGirl Turbo Link Extractor is a single-file polyglot utility that automatically resolves and extracts direct high-speed CDN download links from:
1. **FitGirl Repack Game Pages** (`fitgirl-repacks.site/game-name/`)
2. **Encrypted PrivateBin Pastes** (`paste.fitgirl-repacks.site/?id#key`)
3. **Raw Hoster URLs** (`filekeeper.net/...`, `fuckingfast.co/...`)
4. **Instant Direct CDN URLs** (`tunnel*.dlproxy.uk`, `dl.fuckingfast.co/dl/`)
5. **Torrent & Magnet Links** (Magnet URIs and `.torrent` attachments)

### Key Launcher Files:
* **`Download_FitGirl_Links.bat`**: Windows batch polyglot file. Line 1 executes Python via `python -x "%~f0" %*`. **Line 1 must remain byte-for-byte exact.**
* **`Download_FitGirl_Links.command`**: macOS bash launcher executing `python3 -x "Download_FitGirl_Links.bat"`.

---

## 2. Strict Design Rules & Constraints

1. **Zero Visible Windows**: All browser operations run strictly headless and silent in the background. No popup browser windows under any circumstance.
2. **Single-Line In-Place Terminal Display**: When resolving multiple parts, the console strictly updates on **one single line** (`\r` with progress bar, percentage, link name, and status). It must never line-wrap or spam lines down the screen.
3. **Graceful Cancellation (`Ctrl + C`)**: Safely preserves all links resolved so far into `<Game_Name>_links.txt` in `~/Downloads/`, copies them to clipboard, and reveals them in File Explorer.
4. **Standalone Portability**: Zero requirement for users to clone Git or configure virtual environments. Dependencies auto-install on first run.

---

## 3. Supported Hosters & State

| Mirror / Source | Type | Speed | Status |
| :--- | :--- | :--- | :--- |
| **FileKeeper** (`filekeeper.net`) | Direct Download | ~1.5s / link | **Recommended** — High-speed turbo tunnel (`dlproxy.uk`), 0 countdown |
| **F-Fast** (`fuckingfast.co`) | Direct Download | ~0.7s – 2.5s / link | Direct high-speed CDN with Turnstile & HTMX evasion |
| **Magnet Links** | Torrent Mirror | Instant | 1-click launch in default torrent client |
| **.torrent File Download** | Torrent Mirror | ~2.0s | Silently decrypts PrivateBin attachment to `~/Downloads/` |
| **DataNodes** (`datanodes.to`) | Cloud Storage | — | Unsupported in headless (Cloudflare Turnstile token blocker); auto-fallback to FileKeeper/F-Fast |

---

## 4. Key Fixes Implemented in v1.3.2

1. **Playwright Route Handler Error Guard**:
   * Wrapped `route.continue_()`, `route.abort()`, and `route.fallback()` in `try...except Exception: pass`.
   * Completely eliminated `playwright._impl._errors.Error: Route.continue_: Route is already handled!` when pages redirect between parts.
2. **File Explorer Comma Delimiter Bug**:
   * Sanitized commas `,` and special dashes `–`, `—` out of generated filenames in `safe_filename()`.
   * Prevents Windows `explorer.exe /select,<path>` from breaking at commas and opening Desktop instead of Downloads.
3. **ANSI Color System**:
   * Enabled VT100 mode immediately via `enable_terminal()`.
   * Restored vibrant colors (`C_GREEN`, `C_CYAN`, `C_YELLOW`, `C_BOLD`) across menus, prompts, mirror selection, and completion summary boxes.
4. **Single-Line Block Progress Bar**:
   * Uses modern `|████░░░░|` block graphics with colored status indicators (`➜ OK!`, `➜ Resolving...`, `➜ FAILED`).
   * Width calculations strip ANSI codes (`display_width(strip_ansi(...))`) to guarantee the row never wraps on standard 80-column consoles.
5. **Torrent Mirror Deduplication**:
   * Deduplicated Magnet links and `.torrent` attachments in `parse_repack_html()`.
6. **Live Clipboard Preview**:
   * Automatically inspects clipboard and previews the exact repack link or part count before prompting to use it.
