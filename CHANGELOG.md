# Changelog

All notable changes to this project will be documented in this file.

## [v1.3.1] - 2026-10-20
- FileKeeper and FuckingFast are the supported download hosts.
- Improved reliability, progress display, and cancellation handling.
- DataNodes extraction is currently unsupported.

## [v1.2.0] - 2026-10-20
### Added
- **Interactive Repack Mirror Selector**: Pasting any FitGirl repack game page URL (e.g. `fitgirl-repacks.site/game-name/`) automatically fast-scrapes all available mirrors in ~300ms using zero-browser parsing, displaying an interactive numbered menu.
- **Direct Download vs Torrent Mirror Grouping**: Categorizes links into Direct Hosters (FileKeeper, FuckingFast, DataNodes) and Torrent & Magnet mirrors.
- **Torrent & Magnet Integration**:
  - **Magnet Link**: One-click extraction, automatic clipboard copy, and optional auto-launch in default torrent client (qBittorrent / BitTorrent).
  - **.torrent File Attachment Downloader**: Silently decrypts PrivateBin `.torrent` file attachments in the background, downloads the `.torrent` file into `~/Downloads/`, highlights in Windows Explorer / macOS Finder, and prompts to launch in torrent client.
  - **Streamlined Torrent Sources**: Focused directly on high-speed Magnet URI launching and `.torrent` file downloads, removing redundant ad-heavy tracker web pages.
- **Graceful Cancellation & Progress Preservation**: Intercepts `Ctrl+C` interrupt cleanly without crashing, instantly saving whatever links were already resolved to file, copying them to clipboard, and highlighting in File Explorer.

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
