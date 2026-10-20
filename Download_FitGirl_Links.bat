@echo off & (python -x "%~f0" %* || (echo. & echo [!] Python is not installed or not in PATH. Please install Python 3.8+ from https://www.python.org/ & echo [Make sure to check 'Add Python to PATH' during installation] & echo. & pause)) & exit /b
"""Standalone FitGirl link resolver. Python body of the Windows polyglot launcher."""
from __future__ import annotations

import argparse
import asyncio
import base64
import contextlib
import ctypes
import datetime
import html
import importlib
import importlib.metadata
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass, field
from urllib.parse import unquote, urljoin, urlsplit, urlunsplit

def enable_terminal():
    if sys.platform == 'win32':
        for stream in (sys.stdout, sys.stderr):
            with contextlib.suppress(Exception): stream.reconfigure(encoding='utf-8', errors='replace')
        try:
            from ctypes import wintypes
            kernel = ctypes.windll.kernel32
            kernel.GetStdHandle.argtypes = [wintypes.DWORD]
            kernel.GetStdHandle.restype = wintypes.HANDLE
            kernel.GetConsoleMode.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
            kernel.SetConsoleMode.argtypes = [wintypes.HANDLE, wintypes.DWORD]
            handle = kernel.GetStdHandle(-11)
            mode = wintypes.DWORD()
            if kernel.GetConsoleMode(handle, ctypes.byref(mode)):
                kernel.SetConsoleMode(handle, mode.value | 4)
        except Exception:
            pass

enable_terminal()

C_CYAN = "\033[96m"
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_RED = "\033[91m"
C_MAGENTA = "\033[95m"
C_WHITE = "\033[97m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_RESET = "\033[0m"

def strip_ansi(text: str) -> str:
    return re.sub(r'\033\[[0-9;]*m', '', text)

def make_link(text: str, url: str) -> str:
    """Render clickable OSC 8 hyperlink everywhere; modern conhost, Windows Terminal & macOS parse cleanly without wrapping"""
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"

LINK_SITE = make_link("Website", "https://chideraokonkwo.com")
LINK_COFFEE = make_link("Buy Me a Coffee", "https://chideraokonkwo.gumroad.com/coffee")

BANNER = f"""
{C_CYAN}{C_BOLD} =============================================================================
    ______ _ _    _____ _      _   _______             _
   |  ____(_) |  / ____(_)    | | |__   __|           | |
   | |__   _| |_| |  __ _ _ __| |    | | _   _ _ __   | |__   ___
   |  __| | | __| | |_ | | '__| |    | || | | | '__|  | '_ \\ / _ \\
   | |    | | |_| |__| | | |  | |    | || |_| | |     | |_) | (_) |
   |_|    |_|\\__|\\_____|_|_|  |_|    |_| \\__,_|_|     |_.__/ \\___/

             {C_YELLOW}>>> BY 0xDENZEL | {LINK_SITE} | {LINK_COFFEE} <<<{C_CYAN}{C_BOLD}
 ============================================================================={C_RESET}
  {C_WHITE}Automated direct link resolver for IDM, JDownloader & Free Download Manager{C_RESET}
  {C_DIM}Supported Hosters & Mirrors:
   [+] FuckingFast (fuckingfast.co) - Instant CDN Direct Links
   [+] FileKeeper (filekeeper.net) - High-Speed Turbo Tunnel Mirrors
   [+] Torrent & Magnet Mirrors (Magnet URI, .torrent file download)
   [+] FitGirl PrivateBin pastes (paste.fitgirl-repacks.site/?id#key)
   [+] FitGirl Repack game pages with interactive mirror selector
   [+] Instant passthrough for already direct links (.dlproxy.uk, /dl/, /d/){C_RESET}
{C_CYAN}{C_BOLD} ============================================================================={C_RESET}
"""

VERSION = '1.3.1'
BASE_DIR = Path(__file__).resolve().parent
DOWNLOAD_DIR = str(Path.home() / 'Downloads')
MAX_TEXT = 4 * 1024 * 1024
MAX_TORRENT = 10 * 1024 * 1024
HOST_NAMES = {'filekeeper': 'FileKeeper', 'fuckingfast': 'FuckingFast', 'datanodes': 'DataNodes'}
HOST_ORDER = ('filekeeper', 'fuckingfast', 'datanodes')
SUPPORTED_HOSTS = ('filekeeper', 'fuckingfast')
URL_RE = re.compile(r'(?:https?://|magnet:\?)[^\s<>"\x00-\x20]+', re.I)
ARCHIVE_RE = re.compile(r'\.(?:rar|7z|zip|bin|exe)(?:\.html)?$', re.I)
RUNTIME = BASE_DIR / '.fitgirl-runtime'
_dependencies_ready = False


class ExtractionError(Exception):
    """A short, user-readable error without cookie values or signed URLs."""


@dataclass
class Resolution:
    status: str
    url: str = ''
    detail: str = ''


@dataclass
class PreparedBatch:
    urls: list[str] = field(default_factory=list)
    name: str = ''
    alternatives: dict[str, list[str]] = field(default_factory=dict)
    torrents: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


@dataclass
class RunSummary:
    resolved: int = 0
    total: int = 0
    interrupted: bool = False
    error: str = ''
    output: str = ''
    statuses: dict[str, int] = field(default_factory=dict)


def quiet_process(args, **kwargs):
    """Run a bounded helper without creating an extra Windows console."""
    if sys.platform == 'win32':
        kwargs.setdefault('creationflags', subprocess.CREATE_NO_WINDOW)
    kwargs.setdefault('timeout', 5)
    return subprocess.run(args, **kwargs)


def ensure_dependencies():
    """Install compatible dependencies locally, only when actual work needs them."""
    global _dependencies_ready
    if _dependencies_ready:
        return
    if sys.version_info < (3, 10):
        raise ExtractionError('Python 3.10 or newer is required.')
    packages = [
        ('playwright', 'playwright', (1, 49), 2, 'playwright>=1.49,<2'),
        ('playwright_stealth', 'playwright-stealth', (2, 0), 3, 'playwright-stealth>=2,<3'),
        ('bs4', 'beautifulsoup4', (4, 12), 5, 'beautifulsoup4>=4.12,<5'),
        ('requests', 'requests', (2, 32), 3, 'requests>=2.32,<3'),
    ]
    local_libs = RUNTIME / 'packages'
    if local_libs.exists() and str(local_libs) not in sys.path:
        sys.path.insert(0, str(local_libs))
    missing = []
    for module, dist, minimum, upper, spec in packages:
        try:
            version = tuple(int(n) for n in re.findall(r'\d+', importlib.metadata.version(dist))[:2])
            if importlib.util.find_spec(module) is None or version < minimum or version[0] >= upper:
                missing.append(spec)
        except (ImportError, ValueError):
            missing.append(spec)
    if missing:
        print('First-time setup: installing libraries locally...')
        local_libs.mkdir(parents=True, exist_ok=True)
        setup_temp = RUNTIME / 'tmp'
        setup_temp.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ)
        env.update({key: str(setup_temp) for key in ('TMP', 'TEMP', 'TMPDIR')})
        result = quiet_process([sys.executable, '-m', 'pip', 'install', '--disable-pip-version-check',
                                '--no-input', '--no-cache-dir', '--upgrade', '--target', str(local_libs), *missing],
                               env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
        if result.returncode:
            raise ExtractionError('Dependency setup failed. Check internet access and pip, then retry.')
        if str(local_libs) not in sys.path:
            sys.path.insert(0, str(local_libs))
        importlib.invalidate_caches()
    try:
        importlib.import_module('playwright.async_api')
        if not hasattr(importlib.import_module('playwright_stealth'), 'Stealth'):
            raise ImportError('Stealth API unavailable')
        importlib.import_module('bs4')
    except ImportError as exc:
        raise ExtractionError('Installed libraries are incompatible; restart after updating dependencies.') from exc
    _dependencies_ready = True


def url_parts(url):
    try:
        p = urlsplit(url)
        if p.scheme.lower() not in ('http', 'https') or not p.hostname or p.username or p.password:
            return None
        if p.port not in (None, 80 if p.scheme.lower() == 'http' else 443):
            return None
        return p
    except ValueError:
        return None


def detect_hoster(url: str) -> str:
    p = url_parts(url)
    if not p:
        return ''
    host = p.hostname.lower()
    if host in ('filekeeper.net', 'www.filekeeper.net') or host == 'dlproxy.uk' or host.endswith('.dlproxy.uk'):
        return 'filekeeper'
    if host in ('fuckingfast.co', 'www.fuckingfast.co', 'dl.fuckingfast.co'):
        return 'fuckingfast'
    if host in ('datanodes.to', 'www.datanodes.to'):
        return 'datanodes'
    return ''


def is_direct_link(url: str) -> bool:
    p = url_parts(url)
    if not p:
        return False
    host = p.hostname.lower()
    return bool(
        ((host == 'dlproxy.uk' or host.endswith('.dlproxy.uk')) and p.path not in ('', '/'))
        or (host in ('dl.fuckingfast.co', 'fuckingfast.co') and p.path.startswith('/dl/'))
        or (host in ('datanodes.to', 'www.datanodes.to') and p.path.startswith('/d/'))
    )


def is_paste(url):
    p = url_parts(url)
    return bool(p and p.hostname.lower() == 'paste.fitgirl-repacks.site')


def is_repack(url):
    p = url_parts(url)
    return bool(p and p.hostname.lower() in ('fitgirl-repacks.site', 'www.fitgirl-repacks.site')
                and not p.path.lower().endswith('.torrent'))


def is_magnet(url):
    return bool(re.match(r'^magnet:\?', url, re.I) and re.search(
        r'(?:[?&])xt=urn:btih:(?:[a-f0-9]{40}|[a-z2-7]{32})(?:&|$)', unquote(url), re.I))


def clean_url(url):
    value = html.unescape(url).strip().rstrip('.,;')
    for closing, opening in ((')', '('), (']', '[')):
        while value.endswith(closing) and value.count(closing) > value.count(opening):
            value = value[:-1]
    return value.rstrip("'\"")


def url_identity(url):
    p = url_parts(url)
    if not p:
        return url
    # Fragments label hoster files but contain essential PrivateBin decryption keys.
    return urlunsplit((p.scheme.lower(), p.netloc.lower(), p.path, p.query, p.fragment if is_paste(url) else ''))


def unique_urls(urls):
    seen, result = set(), []
    for url in urls:
        key = url_identity(url)
        if key not in seen:
            seen.add(key)
            result.append(url)
    return result


def extract_urls(raw_text):
    if len(raw_text) > MAX_TEXT:
        raise ExtractionError('Input exceeds the 4 MB text limit.')
    text = html.unescape(raw_text).replace('\\/', '/')
    # Decode escaped JSON strings without reserializing or changing signed URLs.
    if text.lstrip().startswith(('{', '[')):
        try:
            obj = json.loads(raw_text)
            strings = []
            def walk(value, depth=0):
                if depth > 30:
                    return
                if isinstance(value, str):
                    strings.append(value)
                elif isinstance(value, dict):
                    for v in value.values(): walk(v, depth + 1)
                elif isinstance(value, list):
                    for v in value: walk(v, depth + 1)
            walk(obj)
            text = '\n'.join(strings)
        except (ValueError, RecursionError):
            pass
    return unique_urls(clean_url(m.group()) for m in URL_RE.finditer(text))


def parse_links_from_text(raw_text: str) -> list[str]:
    return [u for u in extract_urls(raw_text) if detect_hoster(u)]


def inspect_input(raw_text: str):
    urls = extract_urls(raw_text)
    return ([u for u in urls if is_paste(u)], [u for u in urls if is_repack(u)],
            [u for u in urls if detect_hoster(u) or is_magnet(u) or is_torrent_url(u)])


def is_torrent_url(url):
    p = url_parts(url)
    return bool(p and p.path.lower().endswith('.torrent'))


def plain_text(value):
    return ''.join(c for c in str(value) if unicodedata.category(c)[0] != 'C')


def safe_filename(value, default='fitgirl', limit=140):
    value = unicodedata.normalize('NFC', plain_text(value))
    value = re.sub(r'[<>:"/\\|?*,\u2013\u2014]', '_', value)
    value = re.sub(r'\s+', '_', value).strip(' ._')[:limit].rstrip(' .')
    if not value or value in ('.', '..'):
        value = default
    if re.match(r'^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)', value, re.I):
        value = '_' + value
    return value


def filename_hint(url):
    p = url_parts(url)
    if not p:
        return ''
    fragment = unquote(p.fragment)
    path_name = unquote(p.path.rsplit('/', 1)[-1])
    return fragment if ARCHIVE_RE.search(fragment) else path_name


def detect_game_name(urls: list[str], input_source: str = ''):
    if is_repack(input_source):
        slug = urlsplit(input_source).path.rstrip('/').rsplit('/', 1)[-1]
        if slug:
            return safe_filename(unquote(slug).replace('-', '_'))
    for url in urls:
        hint = filename_hint(url)
        if ARCHIVE_RE.search(hint):
            name = re.split(r'_--_|--|\.part\d+|\.(?:rar|7z|zip|bin|exe)', hint, maxsplit=1, flags=re.I)[0]
            if name and not name.lower().startswith('fg-'):
                return safe_filename(name)
    try:
        if input_source and Path(input_source).is_file():
            name = Path(input_source).stem
            if name.lower() not in ('urls', 'links', 'input'):
                return safe_filename(name)
    except OSError:
        pass
    return None


def filter_links(urls, exclude_bonus=False, keep_lang='english'):
    result = []
    for url in urls:
        label = filename_hint(url).casefold()
        if exclude_bonus and 'fg-optional' in label:
            continue
        if 'fg-selective' in label and keep_lang and keep_lang.casefold() not in label:
            continue
        result.append(url)
    return result


def archive_identity(url):
    label = filename_hint(url)
    if not ARCHIVE_RE.search(label):
        return ''
    label = re.sub(r'\.html$', '', label, flags=re.I)
    label = unicodedata.normalize('NFKC', label).casefold()
    label = re.sub(r'[ _]+', '_', label)
    return re.sub(r'\.part0*(\d+)(?=\.)', lambda m: '.part' + str(int(m[1])), label)


def compatible_manifest(primary, alternative):
    """Require an exact, unique filename/part manifest before mixing mirrors."""
    a, b = [archive_identity(u) for u in primary], [archive_identity(u) for u in alternative]
    if not a or '' in a or '' in b or len(set(a)) != len(a) or len(set(b)) != len(b) or set(a) != set(b):
        return {}
    return dict(zip(b, alternative))


def fetch_bytes(url, limit=MAX_TEXT, timeout=15):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Accept': '*/*'})
    try:
        deadline = time.monotonic() + timeout
        with urllib.request.urlopen(request, timeout=min(timeout, 5)) as response:
            chunks, size = [], 0
            while True:
                if time.monotonic() >= deadline:
                    raise ExtractionError('Source download timed out.')
                chunk = response.read1(min(65536, limit + 1 - size))
                if not chunk: break
                size += len(chunk)
                if size > limit:
                    raise ExtractionError('Response exceeds the permitted size.')
                chunks.append(chunk)
            return b''.join(chunks)
    except urllib.error.HTTPError as exc:
        raise ExtractionError('HTTP %s while loading source.' % exc.code) from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ExtractionError('Could not load source; check internet access and retry.') from exc


def parse_repack_html(content, repack_url):
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(content, 'html.parser')
    title = soup.select_one('h1.entry-title') or soup.title
    title = title.get_text(' ', strip=True) if title else 'FitGirl Repack'
    title = re.sub(r'\s+[-–—]\s*v\d.*$', '', title, flags=re.I)
    # Some live posts close their article early; mirrors remain in content-area.
    body = soup.select_one('.content-area') or soup.select_one('.entry-content') or soup.find('article') or soup
    for node in body.select('script,style,nav,aside,footer,#comments,.comments-area,.related-posts,.yarpp-related'):
        node.decompose()
    direct, torrents, seen = [], [], set()
    for anchor in body.select('a[href]'):
        url = clean_url(urljoin(repack_url, anchor['href']))
        if url_identity(url) in seen:
            continue
        label = anchor.get_text(' ', strip=True).casefold()
        context_label = anchor.parent.get_text(' ', strip=True)[:400].casefold() if anchor.parent else label
        if is_magnet(url):
            if not any(t.get('type') == 'magnet' for t in torrents):
                torrents.append({'name': 'Magnet Link', 'type': 'magnet', 'url': url, 'tag': 'Open in your torrent client'})
        elif is_torrent_url(url) or (is_paste(url) and 'torrent' in label):
            if not any(t.get('type') == 'torrent_file' for t in torrents):
                torrents.append({'name': '.torrent File Download', 'type': 'torrent_file', 'url': url, 'tag': 'Save a verified torrent attachment'})
        elif detect_hoster(url) or is_paste(url):
            host = detect_hoster(url)
            if not host:
                host = next((h for h in HOST_ORDER if h in label), '')
            if not host:
                matches = [h for h in HOST_ORDER if h in context_label]
                host = matches[0] if len(matches) == 1 else ''
            if host:
                tag = 'Recommended' if host == 'filekeeper' else ('Source recognition only; use matching alternate mirrors' if host == 'datanodes' else 'Direct CDN')
                direct.append({'name': HOST_NAMES[host], 'host': host, 'url': url, 'tag': tag})
        seen.add(url_identity(url))
    direct.sort(key=lambda m: HOST_ORDER.index(m['host']))
    return {'game_title': plain_text(title), 'direct_mirrors': direct, 'torrent_mirrors': torrents}


def scrape_fitgirl_repack_mirrors(repack_url):
    return parse_repack_html(fetch_bytes(repack_url).decode('utf-8', errors='replace'), repack_url)


def display_width(text):
    return sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1 for c in text)


def fit_text(text, width):
    result, used = [], 0
    for char in plain_text(text):
        size = display_width(char)
        if used + size > max(0, width): break
        result.append(char); used += size
    return ''.join(result)


def colorize_progress_row(row):
    row = re.sub(r'(█+)', f'{C_GREEN}\\1{C_RESET}', row)
    row = row.replace('> resolving', f'{C_CYAN}➜ Resolving...{C_RESET}')
    row = row.replace('+ OK', f'{C_GREEN}{C_BOLD}➜ OK!{C_RESET}')
    row = row.replace('x failed', f'{C_RED}{C_BOLD}➜ FAILED{C_RESET}')
    row = row.replace('x removed', f'{C_RED}{C_BOLD}➜ [REMOVED/404]{C_RESET}')
    row = row.replace('! verify', f'{C_YELLOW}{C_BOLD}➜ [VERIFY]{C_RESET}')
    row = row.replace('! limited', f'{C_YELLOW}{C_BOLD}➜ [LIMITED]{C_RESET}')
    row = row.replace('! use alternate', f'{C_YELLOW}{C_BOLD}➜ [ALTERNATE]{C_RESET}')
    return row


class Progress:
    """One physical row; no per-file output when stdout is redirected."""
    def __init__(self, total, stream=None):
        self.total = total
        self.stream = stream or sys.stdout
        self.enabled = bool(getattr(self.stream, 'isatty', lambda: False)())
        self.active = False

    def render(self, completed, title, status, width=None):
        budget = max(1, (width or shutil.get_terminal_size((80, 24)).columns) - 1)
        pct = int(100 * completed / self.total) if self.total else 100
        prefix = f'{completed}/{self.total} {pct:3d}% '
        suffix = ' ' + plain_text(status)
        available = budget - display_width(prefix) - display_width(suffix)
        bar_size = max(0, min(14, available // 3))
        bar = ''
        if bar_size >= 3:
            filled = int(bar_size * completed / self.total) if self.total else bar_size
            bar = '|' + '█' * filled + '░' * (bar_size - filled) + '| '
        label = fit_text(title, budget - display_width(prefix) - display_width(bar) - display_width(suffix))
        return fit_text(prefix + bar + label + suffix, budget)

    def update(self, completed, title, status):
        if self.enabled:
            row = self.render(completed, title, status)
            colored = colorize_progress_row(row)
            self.stream.write('\r' + colored + '\033[K')
            self.stream.flush()
            self.active = True

    def finish(self):
        if self.active:
            self.stream.write('\n'); self.stream.flush(); self.active = False


class ResultSink:
    """Checkpoint complete results atomically before another async operation."""
    def __init__(self, path):
        self.path = Path(path).expanduser().resolve()
        self.links = []

    def add(self, url):
        url = url.split('#', 1)[0]
        if not is_direct_link(url) or any(c in url for c in '\r\n\x00'):
            raise ExtractionError('Resolver returned an invalid download URL.')
        if url not in self.links:
            next_links = self.links + [url]
            atomic_write(self.path, ('\n'.join(next_links) + '\n').encode('utf-8'))
            self.links = next_links


def atomic_write(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        with temporary.open('xb') as handle:
            handle.write(content); handle.flush(); os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        with contextlib.suppress(OSError): temporary.unlink()


async def bounded_close(awaitable, seconds=5):
    """Finish cleanup under cancellation, with a finite deadline."""
    task = asyncio.ensure_future(awaitable)
    try:
        await asyncio.wait_for(asyncio.shield(task), timeout=seconds)
    except asyncio.CancelledError:
        try:
            await asyncio.wait_for(asyncio.shield(task), timeout=seconds)
        except (Exception, asyncio.CancelledError):
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
        raise
    except Exception:
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)


async def install_browser(env):
    """Cancel the setup process tree instead of leaving a worker thread running."""
    options = {'creationflags': subprocess.CREATE_NO_WINDOW} if sys.platform == 'win32' else {'start_new_session': True}
    process = await asyncio.create_subprocess_exec(
        sys.executable, '-m', 'playwright', 'install', 'chromium',
        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **options)

    async def stop():
        if process.returncode is not None:
            return
        if sys.platform == 'win32':
            try:
                killer = await asyncio.create_subprocess_exec(
                    'taskkill', '/PID', str(process.pid), '/T', '/F',
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    await asyncio.wait_for(killer.wait(), 3)
                finally:
                    if killer.returncode is None:
                        killer.kill()
                        await killer.wait()
            except OSError:
                process.kill()
        else:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGTERM)
        try:
            await asyncio.wait_for(process.wait(), 3)
        except asyncio.TimeoutError:
            if sys.platform == 'win32':
                with contextlib.suppress(ProcessLookupError): process.kill()
            else:
                with contextlib.suppress(ProcessLookupError): os.killpg(process.pid, signal.SIGKILL)
            await process.wait()

    try:
        code = await asyncio.wait_for(process.wait(), 300)
    except BaseException:
        await bounded_close(stop(), 8)
        raise
    if code:
        raise ExtractionError('Browser setup failed. Check internet access and disk space, then retry.')


class BrowserSession:
    """Lazy headless browser, ephemeral per-host cookies, fresh per-file pages."""
    def __init__(self, block_assets=True):
        self.block_assets = block_assets
        self.driver = None
        self.browser = None
        self.contexts = {}
        self.allowed_pages = set()
        self.tasks = set()
        self.opening = set()
        self.old_temp = None

    async def __aenter__(self):
        return self

    def track(self, awaitable):
        task = asyncio.create_task(awaitable)
        self.tasks.add(task)
        def done(t):
            self.tasks.discard(t)
            if not t.cancelled():
                with contextlib.suppress(Exception): t.exception()
        task.add_done_callback(done)
        return task

    async def start(self):
        if self.browser:
            return
        ensure_dependencies()
        from playwright.async_api import async_playwright
        temp_dir = RUNTIME / 'tmp'
        temp_dir.mkdir(parents=True, exist_ok=True)
        browser_dir = RUNTIME / 'browsers'
        self.old_temp = {k: os.environ.get(k) for k in ('TMP', 'TEMP', 'TMPDIR', 'PLAYWRIGHT_BROWSERS_PATH')}
        for key in ('TMP', 'TEMP', 'TMPDIR'):
            os.environ[key] = str(temp_dir)
        os.environ['PLAYWRIGHT_BROWSERS_PATH'] = str(browser_dir)
        self.driver = await async_playwright().start()
        try:
            self.browser = await self.driver.chromium.launch(headless=True, channel='chrome', downloads_path=str(temp_dir))
        except Exception:
            try:
                self.browser = await self.driver.chromium.launch(headless=True, downloads_path=str(temp_dir))
            except Exception:
                # Only bootstrap when the expected browser executable is absent.
                if Path(self.driver.chromium.executable_path).exists():
                    raise ExtractionError('Headless Chromium could not start. Check OS/browser compatibility.')
                print('First-time setup: installing a headless browser locally...')
                env = dict(os.environ)
                local_packages = str(RUNTIME / 'packages')
                env['PYTHONPATH'] = local_packages + os.pathsep + env.get('PYTHONPATH', '')
                await install_browser(env)
                self.browser = await self.driver.chromium.launch(headless=True, downloads_path=str(temp_dir))

    async def get_page(self, host='source'):
        await self.start()
        context = self.contexts.get(host)
        if context is None:
            options = {}
            if host == 'fuckingfast':
                # Keep HTTP and JS identities consistent, using the installed version.
                platform = 'Macintosh; Intel Mac OS X 10_15_7' if sys.platform == 'darwin' else ('X11; Linux x86_64' if sys.platform.startswith('linux') else 'Windows NT 10.0; Win64; x64')
                options['user_agent'] = f'Mozilla/5.0 ({platform}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{self.browser.version} Safari/537.36'
                options['locale'] = 'en-US'
            context = await self.browser.new_context(accept_downloads=False, service_workers='block', **options)
            self.contexts[host] = context
            async def route_assets(route):
                try:
                    if self.block_assets and route.request.resource_type in ('image', 'media', 'font'):
                        await route.abort()
                    else:
                        await route.continue_()
                except Exception:
                    pass
            await context.route('**/*', route_assets)
            def page_created(page):
                # new_page() fires the event before returning the intended page.
                if host not in self.opening:
                    self.track(page.close())
            context.on('page', page_created)
        self.opening.add(host)
        try:
            page = await context.new_page()
        finally:
            self.opening.discard(host)
        self.allowed_pages.add(page)
        page.set_default_timeout(8000)
        page.set_default_navigation_timeout(20000)
        if host == 'fuckingfast':
            from playwright_stealth import Stealth
            try:
                await Stealth().apply_stealth_async(page)
            except BaseException:
                await self.close_page(page)
                raise
        return page

    async def close_page(self, page):
        self.allowed_pages.discard(page)
        await bounded_close(page.close(), 3)

    async def close(self):
        try:
            for context in list(self.contexts.values()):
                await bounded_close(context.close(), 3)
            self.contexts.clear()
            if self.tasks:
                await bounded_close(asyncio.gather(*list(self.tasks), return_exceptions=True), 3)
            if self.browser:
                await bounded_close(self.browser.close(), 5)
            if self.driver:
                await bounded_close(self.driver.stop(), 5)
        finally:
            self.allowed_pages.clear()
            self.browser = self.driver = None
            if self.old_temp is not None:
                for key, value in self.old_temp.items():
                    if value is None: os.environ.pop(key, None)
                    else: os.environ[key] = value
                self.old_temp = None

    async def __aexit__(self, *exc):
        await bounded_close(self.close(), 15)


def paste_error(text):
    lower = text.casefold()
    if re.search(r'paste.*(?:expired|deleted|does not exist)|paste not found', lower):
        return 'This paste has expired or was deleted.'
    if re.search(r'(?:enter|requires?|protected.*with|wrong).*password|password.protected', lower):
        return 'This paste requires a password; password-protected pastes are not supported.'
    if re.search(r'could not decrypt|cannot decrypt|invalid ciphertext|decryption failed|wrong decryption key', lower):
        return 'The paste could not be decrypted. Check its complete URL and key.'
    return ''


async def load_paste(page, paste_url, attachment=False, timeout=20):
    p = url_parts(paste_url)
    if not is_paste(paste_url) or not p.query or not p.fragment:
        raise ExtractionError('PrivateBin URLs must include both the paste ID and #decryption-key.')
    response = await page.goto(paste_url, wait_until='domcontentloaded', timeout=20000)
    if response and response.status >= 400:
        raise ExtractionError('Paste server returned HTTP %s.' % response.status)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        text = await page.inner_text('body')
        error = paste_error(text)
        if error:
            raise ExtractionError(error)
        if attachment:
            anchor = page.locator('#attachment a[href], a[download], a:has-text("Download attachment")')
            if await anchor.count():
                return anchor.first
        else:
            links = parse_links_from_text(text)
            if links:
                return links
            empty = await page.locator('#plaintext, #prettyprint').count()
            if empty:
                content = await page.locator('#plaintext, #prettyprint').first.inner_text()
                if content.strip():
                    raise ExtractionError('The decrypted paste contains no supported download URLs.')
        await asyncio.sleep(0.15)
    raise ExtractionError('Paste decryption timed out or its schema is unsupported.')


async def extract_links_from_paste(page, paste_url):
    return await load_paste(page, paste_url)


async def extract_links_from_fitgirl_page(page, repack_url):
    await page.goto(repack_url, wait_until='domcontentloaded', timeout=20000)
    return parse_links_from_text(await page.content())


async def wait_event(event, seconds):
    try:
        await asyncio.wait_for(event.wait(), timeout=seconds)
        return True
    except asyncio.TimeoutError:
        return False


def page_failure(status, text):
    if status in (404, 410):
        return Resolution('removed')
    if status == 429:
        return Resolution('rate_limited')
    if status in (401, 403):
        return Resolution('verification_required')
    if status and status >= 500:
        return Resolution('transient')
    lines = [line.strip().casefold().rstrip('.!') for line in text.splitlines()]
    if any(line in ('file not found', 'file has been removed', '404 not found', 'file does not exist') for line in lines):
        return Resolution('removed')
    if any('too many requests' in line or line == 'rate limited' for line in lines):
        return Resolution('rate_limited')
    return None


async def resolve_on_page(page, url, host=None, deadline=30, on_success=None):
    """Capture only a trusted host's candidate and stop before its payload loads."""
    host = host or detect_hoster(url)
    if not host:
        return Resolution('unsupported')
    if is_direct_link(url):
        if on_success: on_success(url.split('#', 1)[0])
        return Resolution('success', url.split('#', 1)[0])
    if host == 'datanodes':
        return Resolution('alternative_required')
    ready = asyncio.Event()
    captured = ''
    pending = set()
    failure = None
    def capture(candidate, base=''):
        nonlocal captured
        candidate = urljoin(base, candidate)
        if not captured and is_direct_link(candidate) and detect_hoster(candidate) == host:
            captured = candidate.split('#', 1)[0]
            ready.set()
    def track(coro):
        task = asyncio.create_task(coro)
        pending.add(task)
        task.add_done_callback(pending.discard)
        task.add_done_callback(lambda t: t.exception() if not t.cancelled() else None)
    def on_download(download):
        capture(download.url)
        track(download.cancel())
    def on_response(response):
        nonlocal failure
        if not 200 <= response.status < 400:
            if detect_hoster(response.url) == host and response.request.resource_type == 'document':
                failure = page_failure(response.status, '')
            return
        for value in (response.headers.get('hx-redirect'), response.headers.get('location')):
            if value: capture(value, response.url)
    async def capture_route(route):
        try:
            if is_direct_link(route.request.url):
                capture(route.request.url)
                await route.abort()
            else:
                await route.fallback()
        except Exception:
            pass
    page.on('download', on_download)
    page.on('response', on_response)

    async def flow():
        nonlocal failure
        response = await page.goto(url.split('#', 1)[0], wait_until='domcontentloaded', timeout=20000)
        if captured:
            return Resolution('success', captured)
        text = await page.inner_text('body')
        failure = page_failure(response.status if response else None, text)
        if failure:
            return failure
        if host == 'filekeeper':
            code = urlsplit(url).path.strip('/').split('/')[0]
            if not re.fullmatch(r'[A-Za-z0-9_-]+', code):
                return Resolution('invalid')
            await page.evaluate('''code => {
                const f=document.createElement('form'); f.method='POST'; f.action='/download';
                const fields={op:'download2',id:code,rand:'',referer:'',method_free:'Free download',down_direct:'1'};
                for(const [name,value] of Object.entries(fields)) {
                    const i=document.createElement('input'); i.type='hidden';i.name=name;i.value=value;f.appendChild(i);
                } document.body.appendChild(f); f.submit();
            }''', code)
            await wait_event(ready, 10)
        elif host == 'fuckingfast':
            button = page.locator('a:has-text("DOWNLOAD"), button:has-text("DOWNLOAD")').first
            await button.wait_for(state='visible', timeout=8000)
            for _ in range(2):
                if captured: break
                # A click may detach its target after producing a valid redirect.
                try:
                    await button.click(timeout=4000, no_wait_after=True)
                except Exception:
                    if captured: break
                if await wait_event(ready, 2): break
            if not captured:
                await wait_event(ready, 5)
        if captured:
            return Resolution('success', captured)
        if failure:
            return failure
        late_failure = page_failure(None, await page.inner_text('body'))
        if late_failure:
            return late_failure
        if await page.locator('.cf-turnstile, iframe[src*="challenges.cloudflare.com"]').count():
            return Resolution('verification_required')
        return Resolution('transient')

    try:
        await page.route('**/*', capture_route)
        try:
            result = await asyncio.wait_for(flow(), deadline)
            result = Resolution('success', captured) if captured else result
        except asyncio.CancelledError:
            if captured and on_success: on_success(captured)
            raise
        except Exception:
            result = Resolution('success', captured) if captured else (failure or Resolution('transient'))
        # Persistence precedes listener/page cleanup, so Ctrl+C during cleanup is safe.
        if result.status == 'success' and on_success:
            on_success(result.url)
        return result
    finally:
        page.remove_listener('download', on_download)
        page.remove_listener('response', on_response)
        with contextlib.suppress(Exception):
            await page.unroute('**/*', capture_route)
        if pending:
            await bounded_close(asyncio.gather(*list(pending), return_exceptions=True), 3)


async def resolve_url(session, url, attempts=2, on_success=None):
    if is_direct_link(url):
        if on_success: on_success(url.split('#', 1)[0])
        return Resolution('success', url.split('#', 1)[0])
    host = detect_hoster(url)
    if not host:
        return Resolution('unsupported')
    if host == 'datanodes':
        return Resolution('alternative_required')
    result = Resolution('transient')
    for attempt in range(attempts):
        page = await session.get_page(host)
        try:
            result = await resolve_on_page(page, url, host, on_success=on_success)
        finally:
            await session.close_page(page)
        if result.status not in ('transient', 'rate_limited'):
            break
        if attempt + 1 < attempts:
            await asyncio.sleep(min(8, (2 ** attempt) * (3 if result.status == 'rate_limited' else 0.6)))
    return result


async def extract_direct_download(page, url, retries=1):
    """Legacy string API; new code consumes explicit Resolution states."""
    result = await resolve_on_page(page, url)
    return result.url if result.status == 'success' else ('REMOVED' if result.status == 'removed' else None)


async def extract_fuckingfast(page, url, retries=1):
    return await extract_direct_download(page, url, retries)


async def extract_filekeeper(page, url, retries=1):
    return await extract_direct_download(page, url, retries)


async def extract_datanodes(page, url, retries=1):
    """Compatibility API: direct URLs only; landing pages require alternatives."""
    return await extract_direct_download(page, url, retries)


def clipboard_windows(text=None):
    """Read/write CF_UNICODETEXT, with ownership and locks released on all paths."""
    from ctypes import wintypes
    user, kernel = ctypes.windll.user32, ctypes.windll.kernel32
    specs = [
        (user.OpenClipboard, [wintypes.HWND], wintypes.BOOL),
        (user.CloseClipboard, [], wintypes.BOOL),
        (user.EmptyClipboard, [], wintypes.BOOL),
        (user.GetClipboardData, [wintypes.UINT], wintypes.HANDLE),
        (user.SetClipboardData, [wintypes.UINT, wintypes.HANDLE], wintypes.HANDLE),
        (kernel.GlobalAlloc, [wintypes.UINT, ctypes.c_size_t], wintypes.HANDLE),
        (kernel.GlobalLock, [wintypes.HANDLE], ctypes.c_void_p),
        (kernel.GlobalUnlock, [wintypes.HANDLE], wintypes.BOOL),
        (kernel.GlobalFree, [wintypes.HANDLE], wintypes.HANDLE),
        (kernel.GetConsoleWindow, [], wintypes.HWND),
    ]
    for function, args, result in specs:
        function.argtypes, function.restype = args, result
    owner = kernel.GetConsoleWindow()
    for _ in range(5):
        if user.OpenClipboard(owner):
            break
        time.sleep(0.04)
    else:
        return '' if text is None else False
    handle, transferred = None, False
    try:
        if text is None:
            handle = user.GetClipboardData(13)
            pointer = kernel.GlobalLock(handle) if handle else None
            if not pointer:
                return ''
            try:
                return ctypes.wstring_at(pointer)
            finally:
                kernel.GlobalUnlock(handle)
        data = (text + '\0').encode('utf-16-le')
        handle = kernel.GlobalAlloc(0x0002, len(data))
        if not handle:
            return False
        pointer = kernel.GlobalLock(handle)
        if not pointer:
            return False
        try:
            ctypes.memmove(pointer, data, len(data))
        finally:
            kernel.GlobalUnlock(handle)
        if not user.EmptyClipboard():
            return False
        transferred = bool(user.SetClipboardData(13, handle))
        return transferred
    finally:
        if text is not None and handle and not transferred:
            kernel.GlobalFree(handle)
        user.CloseClipboard()


def clipboard_commands(write=False):
    if sys.platform == 'darwin':
        return [['pbcopy' if write else 'pbpaste']]
    return ([['wl-copy'], ['xclip', '-selection', 'clipboard'], ['xsel', '--clipboard', '--input']]
            if write else [['wl-paste', '--no-newline'], ['xclip', '-selection', 'clipboard', '-o'], ['xsel', '--clipboard', '--output']])


def get_clipboard_text():
    try:
        if sys.platform == 'win32':
            return clipboard_windows().strip()
        for command in clipboard_commands():
            if shutil.which(command[0]):
                try:
                    result = quiet_process(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
                    if result.returncode == 0:
                        return result.stdout.decode('utf-8', errors='replace').strip()
                except (OSError, subprocess.TimeoutExpired):
                    continue
    except Exception:
        pass
    return ''


def copy_to_clipboard(text):
    try:
        if sys.platform == 'win32':
            return bool(clipboard_windows(text))
        for command in clipboard_commands(write=True):
            if shutil.which(command[0]):
                try:
                    result = quiet_process(command, input=text.encode('utf-8'), stdout=subprocess.DEVNULL,
                                           stderr=subprocess.PIPE, timeout=2)
                    if result.returncode == 0:
                        return True
                except (OSError, subprocess.TimeoutExpired):
                    continue
    except Exception:
        pass
    return False


def reveal_file(path):
    target = Path(path).resolve()
    try:
        if sys.platform == 'win32':
            if target.is_file():
                quiet_process(['explorer.exe', f'/select,{str(target)}'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif target.is_dir():
                quiet_process(['explorer.exe', str(target)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                quiet_process(['explorer.exe', str(target.parent)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif sys.platform == 'darwin':
            quiet_process(['open', '-R', str(target)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which('xdg-open'):
            quiet_process(['xdg-open', str(target.parent)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            return False
        return True
    except (OSError, subprocess.TimeoutExpired):
        return False


def open_default(target):
    try:
        if sys.platform == 'win32':
            os.startfile(target)
        else:
            quiet_process(['open' if sys.platform == 'darwin' else 'xdg-open', target],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except (OSError, subprocess.TimeoutExpired):
        return False


def ask(prompt, default=''):
    try:
        return input(prompt).strip() or default
    except EOFError:
        return default


def valid_torrent(data):
    """Bounded bencode parser; accept v1 or v2 info dictionaries, not HTML errors."""
    if not data or len(data) > MAX_TORRENT:
        return False
    position, items = 0, 0
    def parse(depth=0):
        nonlocal position, items
        items += 1
        if depth > 30 or items > 100000 or position >= len(data):
            raise ValueError('invalid bencode')
        tag = data[position:position+1]
        if tag == b'i':
            end = data.index(b'e', position)
            value = data[position+1:end]
            if not re.fullmatch(rb'(?:0|-?[1-9]\d*)', value): raise ValueError('integer')
            position = end + 1
            return int(value)
        if tag in (b'l', b'd'):
            position += 1
            result = [] if tag == b'l' else {}
            while data[position:position+1] != b'e':
                key = parse(depth+1)
                if tag == b'l': result.append(key)
                else:
                    if not isinstance(key, bytes) or key in result: raise ValueError('dict key')
                    result[key] = parse(depth+1)
            position += 1
            return result
        end = data.index(b':', position)
        length = data[position:end]
        if not re.fullmatch(rb'(?:0|[1-9]\d*)', length): raise ValueError('string length')
        size = int(length)
        position = end + 1
        if position + size > len(data): raise ValueError('truncated')
        value = data[position:position+size]; position += size
        return value
    try:
        torrent = parse()
        info = torrent.get(b'info') if isinstance(torrent, dict) else None
        if position != len(data) or not isinstance(info, dict) or not isinstance(info.get(b'name'), bytes):
            return False
        if not isinstance(info.get(b'piece length'), int) or info[b'piece length'] <= 0:
            return False
        if info.get(b'meta version') == 2:
            return isinstance(info.get(b'file tree'), dict)
        return isinstance(info.get(b'pieces'), bytes) and len(info[b'pieces']) % 20 == 0 and (
            isinstance(info.get(b'length'), int) and info[b'length'] >= 0 or isinstance(info.get(b'files'), list))
    except (ValueError, IndexError, OverflowError, RecursionError):
        return False


async def download_torrent_attachment(page, paste_url, output_dir=DOWNLOAD_DIR, output_path=None):
    anchor = await load_paste(page, paste_url, attachment=True)
    attachment = await anchor.evaluate('''async (a, limit) => {
        const response=await fetch(a.href);
        if(!response.ok) throw new Error('Attachment unavailable');
        const reader=response.body.getReader();const chunks=[];let length=0;
        try { while(true) { const {value,done}=await reader.read(); if(done) break;
            length+=value.byteLength; if(length>limit) throw new Error('Attachment too large'); chunks.push(value);
        }} finally {await reader.cancel();}
        let binary='';for(const bytes of chunks) for(let i=0;i<bytes.length;i+=8192) binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
        return {name:a.download||'game.torrent',data:btoa(binary)};
    }''', MAX_TORRENT)
    data = base64.b64decode(attachment['data'], validate=True)
    filename = safe_filename(attachment['name'], 'game.torrent')
    if not filename.lower().endswith('.torrent') or not valid_torrent(data):
        raise ExtractionError('Attachment is not a valid .torrent file.')
    path = Path(output_path) if output_path else Path(output_dir) / filename
    if path.suffix.lower() != '.torrent':
        raise ExtractionError('Torrent output must have a .torrent extension.')
    atomic_write(path, data)
    return str(path.resolve())


def read_source(source):
    value = source.strip().strip('"').strip("'")
    # URL strings are not filesystem paths (avoids Windows invalid-name errors).
    if not re.match(r'^(?:https?://|magnet:)', value, re.I) and '\n' not in value:
        try:
            path = Path(value).expanduser()
            if path.is_file():
                with path.open('rb') as stream:
                    data = stream.read(MAX_TEXT + 1)
                if len(data) > MAX_TEXT:
                    raise ExtractionError('Input file exceeds the 4 MB text limit.')
                try:
                    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
                except UnicodeError as exc:
                    raise ExtractionError('Input file must use UTF-8 or BOM-marked UTF-16.') from exc
        except OSError as exc:
            raise ExtractionError('Could not read the input file.') from exc
    return value


async def collect_sources(urls, session):
    collected = []
    for url in urls:
        if detect_hoster(url):
            collected.append(url)
        elif is_paste(url):
            page = await session.get_page('source')
            try:
                collected.extend(await extract_links_from_paste(page, url))
            finally:
                await session.close_page(page)
    return unique_urls(collected)


def choose_mirror(data, mirror=None, interactive=False):
    groups = {}
    for item in data['direct_mirrors']:
        groups.setdefault(item['host'], []).append(item['url'])
    if mirror and mirror != 'auto':
        if mirror not in groups:
            raise ExtractionError('Selected mirror is not present on this repack page.')
        return mirror, groups, None
    if interactive:
        options = [('host', h) for h in SUPPORTED_HOSTS if h in groups]
        options += [('torrent', t) for t in data['torrent_mirrors']]
        if options:
            print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
            print(f"  {C_WHITE}Repack Detected:{C_RESET} {C_GREEN}{C_BOLD}{plain_text(data['game_title'])}{C_RESET}")
            print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")
            for index, (kind, value) in enumerate(options, 1):
                label = HOST_NAMES[value] if kind == 'host' else value['name']
                note = f" {C_YELLOW}[Recommended]{C_RESET}" if value == 'filekeeper' else ''
                desc = f" ➜ {value['tag']}" if kind == 'torrent' else (" ➜ Turbo tunnel mirror (~1.5s/link)" if value == 'filekeeper' else " ➜ Direct CDN (~2.5s/link)")
                print(f"  {C_GREEN}[{index}]{C_RESET} {C_BOLD}{label:<24}{C_RESET}{desc}{note}")
            print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}")
            answer = ask(f"{C_WHITE}{C_BOLD}>> Select mirror [1-{len(options)}, default=1]: {C_RESET}", '1')
            if not answer.isdigit() or not 1 <= int(answer) <= len(options):
                raise ExtractionError('Invalid mirror selection.')
            kind, value = options[int(answer)-1]
            return (value, groups, None) if kind == 'host' else ('', groups, value['url'])
    selected = next((h for h in SUPPORTED_HOSTS if h in groups), '')
    if not selected:
        raise ExtractionError('No FileKeeper or FuckingFast mirrors found. DataNodes landing pages are unsupported; use a torrent link or another source.')
    return selected, groups, None


async def prepare_batch(source, session, mirror=None, interactive=False):
    batch = PreparedBatch()
    for url in extract_urls(read_source(source)):
        if is_magnet(url) or is_torrent_url(url):
            batch.torrents.append(url)
        elif is_repack(url):
            data = await asyncio.to_thread(scrape_fitgirl_repack_mirrors, url)
            selected, groups, torrent = choose_mirror(data, mirror, interactive)
            if torrent:
                batch.torrents.append(torrent)
                continue
            primary = [u for u in await collect_sources(groups[selected], session) if detect_hoster(u) == selected]
            if not primary:
                raise ExtractionError('Selected mirror contains no supported links.')
            batch.urls.extend(primary)
            batch.name = batch.name or safe_filename(data['game_title'])
            # Alternatives are prepared before progress starts, never during a row update.
            if selected == 'datanodes':
                batch.warnings.append('DataNodes extraction is unsupported. Using matching FileKeeper/FuckingFast alternatives only.')
                for host in ('filekeeper', 'fuckingfast'):
                    if host not in groups: continue
                    try:
                        other = [u for u in await collect_sources(groups[host], session) if detect_hoster(u) == host]
                    except ExtractionError:
                        batch.warnings.append(HOST_NAMES[host] + ' fallback could not be loaded.')
                        continue
                    mapping = compatible_manifest(primary, other)
                    if not mapping:
                        batch.warnings.append(HOST_NAMES[host] + ' fallback omitted: archive manifests differ or lack filenames.')
                    for original in primary:
                        if archive_identity(original) in mapping:
                            batch.alternatives.setdefault(url_identity(original), []).append(mapping[archive_identity(original)])
        elif detect_hoster(url):
            batch.urls.append(url)
        elif is_paste(url):
            batch.urls.extend(await collect_sources([url], session))
    batch.urls = unique_urls(batch.urls)
    batch.name = batch.name or detect_game_name(batch.urls, source) or 'fitgirl_' + datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    return batch


async def process_batch(urls, alternatives, session, sink, progress):
    """Sequential host-aware resolution; checkpoints precede every next await."""
    summary = RunSummary(total=len(urls), output=str(sink.path))
    blocked = {}
    for index, url in enumerate(urls):
        title = filename_hint(url) or f'Part {index+1}'
        progress.update(index, title, f"{C_CYAN}➜ Resolving...{C_RESET}")
        host = detect_hoster(url)
        if host == 'datanodes' and not is_direct_link(url):
            result = Resolution('alternative_required')
        else:
            result = Resolution(blocked[host]) if host in blocked and not is_direct_link(url) else await resolve_url(session, url, on_success=sink.add)
        if result.status == 'verification_required':
            blocked[host] = result.status
        if result.status != 'success' and host == 'datanodes':
            for alternative in alternatives.get(url_identity(url), []):
                alt_host = detect_hoster(alternative)
                if alt_host in blocked: continue
                progress.update(index, title, f"{C_YELLOW}➜ {HOST_NAMES.get(alt_host, 'fallback')}...{C_RESET}")
                result = await resolve_url(session, alternative, on_success=sink.add)
                if result.status == 'verification_required': blocked[alt_host] = result.status
                if result.status == 'success': break
        if result.status == 'success':
            sink.add(result.url)
            summary.resolved = len(sink.links)
        summary.statuses[result.status] = summary.statuses.get(result.status, 0) + 1
        label = {
            'success': f"{C_GREEN}{C_BOLD}➜ OK!{C_RESET}",
            'removed': f"{C_RED}{C_BOLD}➜ [REMOVED/404]{C_RESET}",
            'verification_required': f"{C_YELLOW}{C_BOLD}➜ [VERIFY]{C_RESET}",
            'rate_limited': f"{C_YELLOW}{C_BOLD}➜ [LIMITED]{C_RESET}",
            'alternative_required': f"{C_YELLOW}{C_BOLD}➜ [ALTERNATE]{C_RESET}"
        }.get(result.status, f"{C_RED}{C_BOLD}➜ FAILED{C_RESET}")
        progress.update(index+1, title, label)
    return summary


async def handle_torrent(source, session, output_path=None, interactive=False):
    if is_magnet(source):
        copied = copy_to_clipboard(source)
        print('Magnet copied to clipboard.' if copied else 'Clipboard unavailable. Magnet: ' + source)
        if interactive and ask('Open in your default torrent client? [Y/n]: ', 'y').lower() in ('y', 'yes'):
            if not open_default(source): print('Could not open the default torrent client.')
        return ''
    if is_paste(source):
        page = await session.get_page('source')
        try:
            saved = await asyncio.wait_for(download_torrent_attachment(page, source, DOWNLOAD_DIR, output_path), 45)
        finally:
            await session.close_page(page)
    else:
        data = await asyncio.to_thread(fetch_bytes, source, MAX_TORRENT)
        if not valid_torrent(data):
            raise ExtractionError('The response is not a valid .torrent file.')
        name = safe_filename(unquote(urlsplit(source).path.rsplit('/', 1)[-1]), 'game.torrent')
        path = Path(output_path) if output_path else Path(DOWNLOAD_DIR) / name
        if path.suffix.lower() != '.torrent': raise ExtractionError('Torrent output must have a .torrent extension.')
        atomic_write(path, data)
        saved = str(path.resolve())
    print('Torrent saved: ' + saved)
    copy_to_clipboard(saved); reveal_file(saved)
    if interactive and ask('Open in your default torrent client? [Y/n]: ', 'y').lower() in ('y', 'yes'):
        if not open_default(saved): print('Could not open the default torrent client.')
    return saved


async def run_pipeline(input_source, output_path=None, exclude_bonus=False, keep_lang='english', *, mirror=None, interactive=False, handoff=True):
    sink, progress = None, None
    summary = RunSummary()
    try:
        inputs = extract_urls(read_source(input_source))
        if any(is_repack(u) or is_paste(u) or (detect_hoster(u) in SUPPORTED_HOSTS and not is_direct_link(u)) for u in inputs):
            ensure_dependencies()
        async with BrowserSession() as session:
            batch = await prepare_batch(input_source, session, mirror, interactive)
            for warning in batch.warnings[:3]: print('Note: ' + warning)
            if batch.torrents and batch.urls and output_path:
                raise ExtractionError('Use separate runs for mixed torrent and direct links with --output.')
            if len(batch.torrents) > 1 and output_path:
                raise ExtractionError('A single --output cannot name multiple torrent files.')
            for torrent in batch.torrents:
                await handle_torrent(torrent, session, output_path, interactive)
            urls = filter_links(batch.urls, exclude_bonus, keep_lang)
            summary.total = len(urls)
            if not urls:
                if not batch.torrents:
                    print('No supported links remain after parsing and filtering.')
                return summary
            path = output_path or str(Path(DOWNLOAD_DIR) / (safe_filename(batch.name) + '_links.txt'))
            sink = ResultSink(path)
            summary.output = str(sink.path)
            # Bootstrap before a progress row exists, keeping installer output separate.
            if any(not is_direct_link(u) and detect_hoster(u) in SUPPORTED_HOSTS for u in urls) or batch.alternatives:
                await session.start()
            print(f'Resolving {len(urls)} links for {plain_text(batch.name)}. Ctrl+C saves progress.')
            progress = Progress(len(urls))
            summary = await process_batch(urls, batch.alternatives, session, sink, progress)
    except (asyncio.CancelledError, KeyboardInterrupt):
        summary.interrupted = True
    except Exception as exc:
        summary.error = str(exc) if isinstance(exc, ExtractionError) else 'Resolution stopped (' + type(exc).__name__ + ').'
    finally:
        if progress: progress.finish()
        if sink:
            summary.resolved = len(sink.links)
            summary.output = str(sink.path)
            if sink.links:
                copied = False
                if handoff:
                    with contextlib.suppress(Exception): copied = copy_to_clipboard('\n'.join(sink.links))
                    with contextlib.suppress(Exception): reveal_file(sink.path)
                if summary.interrupted or summary.error:
                    print(f"\n{C_YELLOW}{C_BOLD}================================================================={C_RESET}")
                    print(f"  {C_YELLOW}{C_BOLD}PARTIAL RESULTS PRESERVED: {summary.resolved}/{summary.total} links saved{C_RESET}")
                    print(f"  Saved to file: {C_CYAN}{sink.path}{C_RESET}")
                    if handoff:
                        print(f"  Clipboard:     {C_GREEN}Copied to clipboard!{C_RESET}" if copied else f"  {C_YELLOW}Clipboard unavailable; use the saved file.{C_RESET}")
                    print(f"{C_YELLOW}{C_BOLD}================================================================={C_RESET}\n")
                else:
                    print(f"\n{C_CYAN}{C_BOLD}================================================================={C_RESET}")
                    print(f"  {C_GREEN}{C_BOLD}SUCCESS: {summary.resolved}/{summary.total} direct links saved!{C_RESET}")
                    print(f"  Saved to file: {C_CYAN}{sink.path}{C_RESET}")
                    if handoff:
                        print(f"  Clipboard:     {C_GREEN}Copied to clipboard!{C_RESET}" if copied else f"  {C_YELLOW}Clipboard unavailable; use the saved file.{C_RESET}")
                    print(f"{C_CYAN}{C_BOLD}================================================================={C_RESET}\n")
            elif summary.total:
                print(f"{C_RED}[-] No links were resolved; any existing output file was left unchanged.{C_RESET}")
        if summary.interrupted: print(f"{C_YELLOW}[!] Cancelled. Completed links have been preserved.{C_RESET}")
        if summary.error: print(f"{C_RED}[!] Error: {plain_text(summary.error)}{C_RESET}")
    if summary.statuses.get('verification_required'):
        print('Some files require host verification. No matching working fallback was available.')
    if summary.statuses.get('alternative_required'):
        print('DataNodes landing pages are unsupported. Use the original repack page and choose FileKeeper or FuckingFast.')
    if sink and sink.links and interactive and not summary.interrupted and not summary.error:
        offer_download_manager()
    return summary


def offer_download_manager():
    managers = get_installed_download_managers()
    if not managers:
        return
    name, target, kind = managers[0]
    if ask(f'Open {name}? [Y/n]: ', 'y').lower() not in ('y', 'yes'):
        return
    try:
        if kind == 'mac_open':
            quiet_process(['open', target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.Popen([target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             **({'creationflags': subprocess.CREATE_NO_WINDOW} if sys.platform == 'win32' else {}))
    except OSError:
        print('Could not launch the download manager. Import the saved file manually.')


async def handle_repack_mirror_selection(repack_url, output_path=None, exclude_bonus=False, keep_lang='english', **kwargs):
    return await run_pipeline(repack_url, output_path, exclude_bonus, keep_lang,
                              interactive=kwargs.pop('interactive', True), **kwargs)


def interactive_menu():
    print(BANNER)
    clipboard = get_clipboard_text()
    source = ''
    try:
        found = any(inspect_input(clipboard))
    except ExtractionError:
        found = False
    if found:
        print(f"{C_GREEN}[+] Clipboard auto-detect: Supported links found in your Clipboard!{C_RESET}")
        ans = ask(f"{C_WHITE}{C_BOLD}>> Press [ENTER] to use clipboard, or type [P] to paste manually: {C_RESET}", 'enter')
        if ans.lower() not in ('p', 'paste'):
            source = clipboard
    if not source:
        print(f"\n{C_WHITE}{C_BOLD}>> Paste a URL, file path, or link list (end a list with an empty line):{C_RESET}")
        lines = []
        while True:
            try:
                line = input().strip()
            except EOFError:
                break
            if not line: break
            lines.append(line)
            if len(lines) == 1 and (is_paste(line) or is_repack(line) or is_magnet(line) or is_torrent_url(line)):
                break
            if len(lines) == 1 and not re.match(r'https?://', line, re.I):
                break
        source = '\n'.join(lines)
    if not source:
        print(f"{C_YELLOW}[!] No input provided.{C_RESET}")
        return
    print(f"\n{C_CYAN}{C_BOLD}-----------------------------------------------------------------{C_RESET}")
    exclude = ask(f"{C_WHITE}{C_BOLD}>> Exclude optional bonus files (soundtracks/trailers)? [y/N, default=N]: {C_RESET}", 'n').lower() in ('y', 'yes')
    print(f"{C_WHITE}{C_BOLD}>> Selective Voiceover Language:{C_RESET}")
    print(f"   {C_GREEN}[Enter]{C_RESET} Keep English only {C_YELLOW}[Recommended]{C_RESET}")
    print(f"   {C_WHITE}[N]{C_RESET}     Download all languages")
    print(f"   {C_DIM}[Or type a language: e.g. spanish, japanese, french]{C_RESET}")
    lang = ask(f"{C_WHITE}{C_BOLD}>> Your language choice [default=English]: {C_RESET}", 'english').lower()
    lang = None if lang in ('n', 'all', 'none') else ('english' if lang in ('y', 'yes') else lang)
    print(f"{C_CYAN}{C_BOLD}-----------------------------------------------------------------{C_RESET}\n")
    asyncio.run(run_pipeline(source, None, exclude, lang, interactive=True))


def main(argv=None):
    parser = argparse.ArgumentParser(description='FitGirl Turbo Link Extractor - silent headless mirror resolution')
    parser.add_argument('source', nargs='?', help='Repack/paste URL, hoster links, magnet, .torrent URL, or text file')
    parser.add_argument('-o', '--output', help='Output file (default: <Game_Name>_links.txt in Downloads)')
    parser.add_argument('--no-bonus', action='store_true', help='Exclude fg-optional files')
    parser.add_argument('--lang', default='english', help='Selective language to retain, or all (default: english)')
    # Accept the old datanodes option only for matching alternate manifests.
    parser.add_argument('--mirror', choices=['auto', *HOST_ORDER], metavar='{auto,filekeeper,fuckingfast}',
                        help='Choose a supported repack hoster; auto prefers FileKeeper')
    parser.add_argument('--version', action='version', version=VERSION)
    args = parser.parse_args(argv)
    enable_terminal()
    if sys.version_info < (3, 10):
        print('Python 3.10 or newer is required. Install it from https://www.python.org/.')
        return 1
    try:
        if args.source:
            language = None if args.lang.lower() in ('all', 'none') else args.lang.lower()
            interactive = sys.stdin.isatty() and args.mirror is None
            summary = asyncio.run(run_pipeline(args.source, args.output, args.no_bonus, language,
                                                mirror=args.mirror, interactive=interactive))
            return 130 if summary.interrupted else (1 if summary.error else 0)
        if not sys.stdin.isatty():
            parser.print_usage()
            print('Provide a source when stdin is not an interactive terminal.')
            return 1
        while True:
            interactive_menu()
            if ask('Process another game? [y/N]: ', 'n').lower() not in ('y', 'yes'):
                return 0
    except KeyboardInterrupt:
        print('\nCancelled.')
        return 130



def get_installed_download_managers() -> list[tuple[str, str, str]]:
    """Detect installed download managers across Windows and macOS.
    Returns: list of (Name, LaunchPath, LaunchCommandType)
    """
    managers = []

    if sys.platform == "win32":
        # Internet Download Manager (IDM)
        idm_paths = [
            r"C:\Program Files (x86)\Internet Download Manager\IDMan.exe",
            r"C:\Program Files\Internet Download Manager\IDMan.exe"
        ]
        for p in idm_paths:
            if os.path.isfile(p):
                managers.append(("Internet Download Manager (IDM)", p, "win_exec"))
                break

        # JDownloader 2 on Windows
        local_app = os.environ.get("LOCALAPPDATA", "")
        prog_files = os.environ.get("ProgramFiles", "")
        prog_files_x86 = os.environ.get("ProgramFiles(x86)", "")
        jd_paths = [
            os.path.join(local_app, "JDownloader 2.0", "JDownloader2.exe"),
            os.path.join(prog_files, "JDownloader 2.0", "JDownloader2.exe"),
            os.path.join(prog_files_x86, "JDownloader 2.0", "JDownloader2.exe")
        ]
        for p in jd_paths:
            if p and os.path.isfile(p):
                managers.append(("JDownloader 2", p, "win_exec"))
                break

        # Free Download Manager on Windows
        fdm_paths = [
            os.path.join(prog_files, "Softdeluxe", "Free Download Manager", "fdm.exe"),
            os.path.join(prog_files, "FreeDownloadManager", "fdm.exe"),
            os.path.join(local_app, "Programs", "Free Download Manager", "fdm.exe")
        ]
        for p in fdm_paths:
            if p and os.path.isfile(p):
                managers.append(("Free Download Manager", p, "win_exec"))
                break

    elif sys.platform == "darwin":
        # macOS Applications
        mac_apps = [
            ("JDownloader 2", "/Applications/JDownloader 2.app"),
            ("Free Download Manager", "/Applications/Free Download Manager.app"),
            ("Neat Download Manager", "/Applications/NeatDownloadManager.app"),
            ("Folx", "/Applications/Folx.app")
        ]
        for name, app_path in mac_apps:
            if os.path.exists(app_path):
                managers.append((name, app_path, "mac_open"))

    return managers

if __name__ == '__main__':
    # Keep handled cancellation out of the immutable batch wrapper's Python-error branch.
    main()
