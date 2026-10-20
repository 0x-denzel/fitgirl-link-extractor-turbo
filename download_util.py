"""Compatibility APIs backed by the standalone engine; no duplicate resolver."""
import sys
import types
from pathlib import Path


def load_engine():
    name = '_fitgirl_standalone_engine'
    if name not in sys.modules:
        path = Path(__file__).with_name('Download_FitGirl_Links.bat')
        source = '\n' + path.read_text(encoding='utf-8').split('\n', 1)[1]
        module = types.ModuleType(name)
        module.__file__ = str(path)
        sys.modules[name] = module
        try:
            exec(compile(source, str(path), 'exec'), module.__dict__)
        except BaseException:
            sys.modules.pop(name, None)
            raise
    return sys.modules[name]


class RateLimitedException(Exception):
    """Retained for callers of the former helper module."""


async def extract_download_link_from_page(page, url):
    engine = load_engine()
    result = await engine.resolve_on_page(page, url)
    return result.url if result.status == 'success' else 'Download link not found'


async def get_final_download_fuckingfast_async(url, max_retries=3):
    engine = load_engine()
    engine.ensure_dependencies()
    async with engine.BrowserSession() as session:
        result = await engine.resolve_url(session, url, attempts=max(1, max_retries+1))
    return result.url if result.status == 'success' else 'Download link not found'


async def process_fuckingfast_links_batch(links):
    engine = load_engine()
    if not links:
        return []
    engine.ensure_dependencies()
    results = []
    progress = engine.Progress(len(links))
    try:
        async with engine.BrowserSession() as session:
            if any(not engine.is_direct_link(u) for u in links):
                await session.start()
            for index, link in enumerate(links):
                progress.update(index, engine.filename_hint(link), '> resolving')
                result = await engine.resolve_url(session, link)
                results.append(result.url if result.status == 'success' else 'Download link not found')
                progress.update(index+1, engine.filename_hint(link), '+ OK' if result.url else 'x failed')
    finally:
        progress.finish()
    return results
