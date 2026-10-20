# FitGirl Turbo Link Extractor

Version **1.3.1** · By **0xDENZEL**

Extract direct download URLs from FitGirl repack pages and PrivateBin pastes using **FileKeeper** and **FuckingFast**. Export ordered links for import into IDM, JDownloader 2, FDM, or another download manager. Magnet URIs and `.torrent` files are also supported.

## Launch

Python **3.10 or newer** must be installed. Download the [standalone ZIP or launchers from the latest release](https://github.com/EditByDenzel/fitgirl-link-generator-updated/releases/latest). Extract the ZIP into a writable folder and double-click `Download_FitGirl_Links.bat` on Windows. On macOS, put `Download_FitGirl_Links.command` beside the BAT file, make the launcher executable if necessary (`chmod +x Download_FitGirl_Links.command`), then run it. Linux users can run `python3 -x Download_FitGirl_Links.bat`.

No Git checkout or virtual environment is required. Needed Python packages install automatically into `.fitgirl-runtime/packages` beside the script. Browser operations use installed Chrome when available; otherwise Chromium installs into `.fitgirl-runtime/browsers`. First setup requires internet access and enough disk space. Help and version commands do not install anything.

All automation browsers are **headless**, including fallback launches. Browser profiles, temporary downloads, and installed runtime files stay under `.fitgirl-runtime`; browser sessions and cookies are not saved for reuse between runs.

## Use

1. Copy a repack URL, full PrivateBin URL (including its `#` key), hoster URLs, magnet URI, or `.torrent` URL.
2. Launch the script. Use detected clipboard contents or paste a URL, a text-file path, or a multiline list.
3. Select a mirror for a repack page and choose language/bonus filters.
4. Import the saved `<Game_Name>_links.txt` from `~/Downloads/` into your download manager. The app also attempts to copy the links and reveal the file.

English selective files are retained by default; use `--lang all` to retain every language. `--no-bonus` removes `fg-optional-*` files. Filters also apply to direct CDN URLs. Input order is retained and duplicates are removed.

During resolution, a terminal displays one overwritten progress row sized to its current width. Redirected output omits per-link progress. Setup, selection, and final summaries appear outside that row.

Every resolved URL is checkpointed with an atomic file replacement **before browser cleanup**. Ctrl+C preserves completed links, closes browser resources, and attempts clipboard/file reveal. Cancellation before the first success leaves an existing output file unchanged. Clipboard failure does not prevent file export or reveal. The default export is in Downloads; `--output` selects another path.

## Supported hosters

| Hoster | Behavior |
| --- | --- |
| FileKeeper | Preferred automatic mirror; resolves its form to a `dlproxy.uk` URL. |
| FuckingFast | Captures the download redirect, including the first successful HTMX response. |

### Recognized DataNodes sources

**DataNodes landing-page extraction is unsupported** and is absent from the main mirror selector. The app does not visit DataNodes landing pages, wait for their countdown, or attempt verification. Use the original repack page and choose FileKeeper or FuckingFast instead. Already-direct `datanodes.to/d/…` URLs can still be exported without browser resolution.

For compatibility, the old `--mirror datanodes` option is accepted on a repack page solely to find alternate mirrors. The app compares complete lists of archive filenames and part numbers, then resolves matching files through FileKeeper, followed by FuckingFast if needed. Only matching, unique manifests qualify. A missing or mismatched manifest is reported; files are never guessed. Filename matching is not a binary content-integrity check.

Standalone DataNodes links or DataNodes-only pastes lack the original repack context, so the app reports that an alternate source is required. No host is guaranteed to work on every network or every run.

## Command line

```powershell
# Windows: help works without third-party packages
python -x Download_FitGirl_Links.bat --help

# Choose the first available preferred host without a mirror prompt
python -x Download_FitGirl_Links.bat "https://fitgirl-repacks.site/game-name/" --mirror auto

# Choose a supported host explicitly
python -x Download_FitGirl_Links.bat "https://fitgirl-repacks.site/game-name/" --mirror fuckingfast

# Preserve all languages, omit bonus files, and set the output path
python -x Download_FitGirl_Links.bat "links.txt" --lang all --no-bonus -o "game_links.txt"
```

Use `python3` in place of `python` on macOS/Linux. A source argument can be a URL, quoted link list, or UTF-8 text file. The supported `--mirror` choices are `auto`, `filekeeper`, and `fuckingfast`. Without a source, the app enters its interactive loop. Without interactive stdin, a supplied repack page automatically prefers FileKeeper unless a mirror is specified.

Magnet URIs are copied and can be opened in the default torrent client after an interactive prompt. Direct `.torrent` responses and decrypted PrivateBin attachments must contain valid torrent metadata before being saved. Password-protected, expired, malformed, and unsupported paste content produces an explicit error.

The preserved Windows batch wrapper interprets nonzero interpreter exits as launcher failures. Handled application errors are therefore printed as summaries rather than forwarded as process exit codes; callers needing structured status can use `run_pipeline()` and its `RunSummary`.

## Compatibility and limits

- Windows clipboard access uses native Unicode Win32 APIs with bounded retries. macOS uses `pbcopy`/`pbpaste`; Linux tries Wayland clipboard tools, then `xclip`/`xsel`. Linux clipboard tools must be present for clipboard integration.
- Explorer/Finder reveal and download-manager launch are separate from browser automation. Download-manager launch requires an interactive confirmation.
- The extractor captures candidate download URLs without downloading game payloads. Host URLs may expire or depend on a session; a captured URL is not proof of a completed download.
- HTTP redirects are accepted only for recognized host/CDN destinations. Unicode filenames and encoded URLs are preserved; output filenames remove control characters and characters invalid on Windows.
- Browser pages and listeners are cleaned after each file. Images, fonts, and media are blocked; scripts, styles, fetch requests, and verification resources remain available.
- Windows headless and simulated OS-adapter checks were run for this release. Native macOS/Linux behavior and a fresh-machine dependency installation have not been physically validated.

## Development and validation

The BAT Python body is the canonical engine. **Do not change its first line**: Windows executes it as batch, and Python skips it with `-x`.

`download_util.py`, `extract_ff_links.py`, and `app.py` delegate to that same engine. The legacy extractor keeps its `Downloads/idm_links.txt` default; `app.py` keeps its `output/<prefix>_links.txt` default and legacy options.

```powershell
python -m unittest discover -s tests -v

# Opt in to synthetic network fixtures in real headless Chrome/Chromium
$env:FITGIRL_BROWSER_TESTS = "1"
python -m unittest discover -s tests -v
```

On macOS/Linux, use `FITGIRL_BROWSER_TESTS=1 python3 -m unittest discover -s tests -v`. Browser tests require installed dependencies and a usable headless browser; first-run setup can install them. The 100-part test runs 100 simulated file pages through a real invisible browser to check ordering, saved output, and cleanup. It does not download 100 live files or test DataNodes reliability. Other fixtures cover cancellation after URL capture, rejected redirects, and status handling. Test exports stay in `.test-output`; clipboard, file reveal, and client launch are mocked.

Observed live samples on 2026-10-20: FileKeeper resolved 2/2 probes in 3.063 and 1.497 seconds; FuckingFast resolved 2/2 final probes in 1.897 and 0.687 seconds. First probes include lazy browser startup. DataNodes produced no direct URL in the audited verification experiments, so its landing-page resolver was removed in v1.3.1. Earlier v1.3.0 testing mapped all 21 DataNodes parts to both alternate hosts and resolved a one-part fallback in 10.490 seconds, including the now-removed DataNodes attempt. These small samples are engineering checks, not reliability guarantees or download-speed measurements. See [VALIDATION.md](VALIDATION.md) for the current release checks and their limits.

## License

This project is licensed under the [MIT License](LICENSE).
