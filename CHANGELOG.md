# Changelog

All notable changes to this project will be documented in this file.

## [v1.0.1] - 2026-10-19
### Added
- OSC 8 clickable terminal hyperlinks for Website (`https://chideraokonkwo.com`) and Coffee Tip (`https://chideraokonkwo.gumroad.com/coffee`) with clean text fallback.
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
