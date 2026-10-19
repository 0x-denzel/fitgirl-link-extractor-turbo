# Changelog

All notable changes to this project will be documented in this file.

## [v1.0.1] - 2026-10-19
### Added
- Author website branding (`https://chideraokonkwo.com`) and tip link (`buymeacoffee.com/0xdenzel`) directly in ASCII header banner.
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
