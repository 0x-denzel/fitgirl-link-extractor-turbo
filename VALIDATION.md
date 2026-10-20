# Release validation — v1.3.1

Validated on Windows with Python 3.11, Playwright 1.63, playwright-stealth 2.0.3, and Chrome 155 on 2026-10-20.

## Support policy

FileKeeper and FuckingFast are the supported extraction engines. DataNodes landing-page navigation, countdown handling, and verification attempts have been removed. DataNodes is absent from the primary selector, banner, and supported choices shown in CLI help. Already-direct DataNodes URLs still pass through.

The legacy `--mirror datanodes` option is accepted only to compare a repack page's complete archive manifests and resolve matching FileKeeper/FuckingFast alternatives. Unsupported standalone DataNodes sources immediately request an alternate source without starting a browser or installing dependencies. No alternate URL is guessed.

## Automated checks

```powershell
$env:FITGIRL_BROWSER_TESTS = '1'
python -m unittest discover -s tests -v
```

**52 tests passed in 57.869 seconds**: 45 offline regressions and 7 real headless browser fixture tests. Coverage includes exact polyglot first-line preservation, parsing, filters, trusted redirects, manifest matching, primary mirror selection, DataNodes navigation prevention, direct passthrough, ordered alternate resolution, atomic checkpoints, cancellation during navigation and cleanup, browser-setup cancellation, clipboard failure, and dependency-free help.

The **100-part headless test** means 100 simulated file pages run through a real invisible browser. It checks output order and cleanup; it does not download 100 real game parts or measure live DataNodes reliability.

Final 100-part fixture observations:

```json
{
  "parts": 100,
  "seconds": 46.499,
  "pages_after_each_part_max": 0,
  "pending_popup_tasks_after_each_part_max": 0,
  "python_traced_current_bytes": 1407485,
  "python_traced_peak_bytes": 2312157,
  "payload_requests": 0
}
```

Python tracemalloc measures Python allocations, not full browser/process RAM. Zero remaining pages/tasks in this fixture is evidence for these exercised lifecycle paths, not a universal memory-leak guarantee.

## Live alternate-mirror check

A public repack's 21 DataNodes parts matched both FileKeeper and FuckingFast manifests. The one-part resolution then used FileKeeper directly. The harness rejects creation of a DataNodes resolver page; no DataNodes landing page was opened. Generated CDN payload requests were intercepted, and only hostnames/counts/timings were retained.

```json
[
  {
    "kind": "fallback_manifest",
    "parts": 21,
    "mapped_parts": 21,
    "alternative_counts": [
      2
    ],
    "seconds": 9.227,
    "warnings": [
      "DataNodes extraction is unsupported. Using matching FileKeeper/FuckingFast alternatives only."
    ]
  },
  {
    "kind": "live_fallback_one_part",
    "resolved": 1,
    "total": 1,
    "result_host": "tunnel1.dlproxy.uk",
    "seconds": 2.603
  }
]
```

Earlier supported-host probes resolved FileKeeper 2/2 in 3.063 and 1.497 seconds, and FuckingFast 2/2 in 1.897 and 0.687 seconds. First probes include lazy browser startup. These small samples are engineering checks, not population reliability estimates or download-speed measurements. The earlier DataNodes verification experiments produced no direct URLs; this motivated removing its resolver.

## Packaging and limits

The Windows polyglot first line remains byte-for-byte intact. Its historical launcher text says Python 3.8; the engine and documentation require Python 3.10 or newer. The macOS launcher has LF endings and is tracked executable. Runtime dependencies, browser files, and setup temporary files stay beside the script. All browser launches specify headless mode.

Source and Desktop release copies are SHA256 checked. The Python body compiles; `python -x Download_FitGirl_Links.bat --help`, dependency-free `python -S -x Download_FitGirl_Links.bat --version`, and the Windows batch `--help` launch were checked. Original Desktop files remain backed up locally.

Native macOS/Linux integration, a fresh-machine dependency installation, and completed game downloads have not been physically tested. OS handoff tests mock clipboard, file reveal, and client launch. Installer process-tree cancellation uses mocked Windows/POSIX coverage. A captured URL may expire or depend on host session state; it is not proof of a completed download or binary integrity.

The [historical audit and approved plan](docs/AUDIT_2026-10-20.md) documents original bugs, DataNodes experiments, and resource-blocking observations. Its awaiting-approval wording records the state at that earlier phase; this validation report describes the current release.
