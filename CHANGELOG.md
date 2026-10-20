# Changelog

All notable changes to this project will be documented in this file.

## [v1.3.1] - 2026-10-20
### Changed
- Present FileKeeper and FuckingFast as the supported extraction engines; remove DataNodes from the main selector, banner, and supported CLI choices shown in help.
- Remove DataNodes landing-page navigation, countdown handling, and verification attempts. Standalone sources immediately request an alternate host; already-direct DataNodes URLs still pass through.
- Retain the old `--mirror datanodes` option only for archive-manifest matching on a repack page, resolving corresponding files through FileKeeper and then FuckingFast without attempting DataNodes.
- Clarify that the 100-part headless test uses simulated pages in a real invisible browser and does not establish live host reliability.
- Add regression coverage for unsupported DataNodes navigation, primary selection, direct passthrough, and alternate-host resolution.

## [v1.3.0] - 2026-10-20
### Added
- Bounded DataNodes resolution with a batch circuit breaker. Repack pages can fall back to FileKeeper and FuckingFast only after complete archive filename/part manifests match.
- Atomic export after each resolved URL, including a checkpoint before listener cleanup, preserving completed results on cancellation and unexpected errors.
- Offline regression tests and opt-in real headless browser fixtures, including a 100-part lifecycle run.
- Lazy local dependency/browser setup, a dependency-free `--help`, `--version`, and explicit `--mirror` selection.
- Cancellation of the browser installer process tree; local pip temporary files with its external cache disabled.

### Fixed
- Retain the first successful FuckingFast HTMX redirect even if its download button disappears. Keep HTTP browser identity aligned with the installed browser version.
- Parse inline mirrors outside a malformed article boundary; preserve all archive parts and mixed input order.
- Apply language/bonus filters to direct links; recognize FileKeeper CDN links; reject deceptive hostname matches.
- Handle encoded URLs, escaped JSON pastes, Unicode filenames, expired/password-protected/malformed pastes, and torrent metadata validation.
- Distinguish visible missing-file pages from script text and classify verification/rate-limit failures separately.
- Bound progress to terminal width and suppress per-link output when redirected.
- Clean pages, listeners, pending callbacks, contexts, and browser resources; block image/font/media payloads while preserving functional requests.
- Bound clipboard subprocesses and Win32 clipboard retries; preserve export when clipboard or file reveal fails.
- Route legacy Python entry points through the canonical BAT engine and preserve their command-line defaults.

### Changed
- Require Python 3.10 or newer. Dependencies and browser downloads install beside the script; no virtual environment or Git checkout is needed.
- Preserve the Windows polyglot first line exactly and keep every browser launch headless.
- Document DataNodes limitations and measured sample timings without claiming universal verification success.
- Normalize the macOS launcher's line endings and pass all arguments to the canonical engine.

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
