# Changelog

All notable changes to this project will be documented in this file.

## [v1.1.0] - 2026-10-20
### Added
- **Multi-Hoster Engine Rebrand**: Renamed and upgraded engine to **FitGirl Turbo Link Extractor** supporting **FuckingFast (`fuckingfast.co`)**, **FileKeeper (`filekeeper.net`)**, and **DataNodes (`datanodes.to`)**.
- **Instant FileKeeper Direct Resolver**: High-speed automated resolution delivering `tunnel*.dlproxy.uk` CDN direct links in <2 seconds per file with zero ad popups.
- **DataNodes Pipeline**: Integrated support for DataNodes mirrors with countdown progression and verification handling.
- **Multi-Hoster URL Parser**: Automatically extracts and deduplicates mixed link lists containing FuckingFast, FileKeeper, and DataNodes URLs.
- **Accurate URL Filename & Game Detection**: Extracts clean game names directly from URL path basenames (e.g. `CoD_MW4`) in addition to PrivateBin anchors and page slugs.
- **Multi-Hoster Direct Passthrough**: Instantly recognizes direct CDN links (`dlproxy.uk`, `dl.fuckingfast.co/dl/`, `datanodes.to/d/`) and bypasses browser execution.
- **Windows UTF-8 Terminal Fix**: Reconfigured `sys.stdout` to UTF-8 output on Windows to eliminate `cp1252` encoding errors during in-place progress updates.
- **Updated Desktop Folder**: Consolidated all user release files in `Desktop\FitGirl-Link-Extractor`.

## [v1.0.1] - 2026-10-19
### Added
- Ultra-fast native Win32 `ctypes` clipboard reader: Reads clipboard in 0ms with zero subprocess overhead, eliminating PowerShell timeout drops.
- Immediate folder & file reveal: Automatically opens Windows Explorer / macOS Finder and highlights the saved links file immediately upon completion, before prompting for download managers.
- Compact single-line OSC 8 terminal hyperlinks: Renders `Website` and `Buy Me a Coffee` cleanly without line-wrapping across standard 80-column consoles.
- Proprietary moat protection: Neutralized internal architecture phrasing across all console logs and status indicators.
- Cross-platform download manager detection and 1-click launcher for Windows (IDM, JDownloader 2, Free Download Manager) and macOS (JDownloader 2, FDM, NeatDM, Folx).
- Anti-bot hardening: Platform-aware User-Agent spoofing, context-level popunder tab killer, and randomized request pacing (jitter).
- Dead link detection: Instantly detects `File Not Found` / `404` pages as `[REMOVED/404]` without redundant retries.
- Single-line in-place progress monitor with ASCII redirect icon (`➜`), progress bar, and percentage.
- Static header retention (`clear_screen`) preventing header from scrolling off terminal.
- macOS support: Cross-platform clipboard reading via `pbpaste`/`pbcopy`, macOS 1-click launcher (`Download_FitGirl_Links.command`), and Finder reveal via `open -R`.
- Single-instance direct link bypass: Skips headless browser overhead when raw direct links are provided.
- Dynamic game name detection from URL anchors and repack slugs.
- Auto-restart loop to queue multiple games consecutively without restarting the launcher.

## [v1.0.0] - 2026-10-19
### Added
- Standalone polyglot Windows batch launcher (`Download_FitGirl_Links.bat`).
- Automatic dependency verification and installation (`playwright`, `playwright-stealth`, `beautifulsoup4`, `requests`).
- Cloudflare Turnstile & HTMX bypass for FuckingFast file hoster.
- FitGirl PrivateBin AES encrypted paste resolver.
- Selective voiceover language filtering.
- One-click export directly into Internet Download Manager (IDM) and clipboard.
