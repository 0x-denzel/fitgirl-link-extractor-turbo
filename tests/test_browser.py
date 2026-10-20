"""Real headless Chromium with synthetic HTTP responses; opt in with FITGIRL_BROWSER_TESTS=1."""
import asyncio
import io
import json
import os
from pathlib import Path
import sys
import time
import tracemalloc
import unittest
from unittest.mock import AsyncMock, patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from download_util import load_engine
e=load_engine()


@unittest.skipUnless(os.environ.get('FITGIRL_BROWSER_TESTS')=='1','opt-in headless browser fixtures')
class BrowserFixtures(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.session=e.BrowserSession()
        await self.session.__aenter__()
        self.trace=[]

    async def asyncTearDown(self):
        await self.session.__aexit__(None,None,None)
        self.assertFalse(self.session.contexts)
        self.assertFalse(self.session.tasks)
        self.assertFalse(self.session.allowed_pages)

    async def fixture_page(self,html,host='fuckingfast',status=200,headers=None):
        page=await self.session.get_page(host)
        async def route(request_route):
            self.trace.append(request_route.request.url)
            await request_route.fulfill(status=status,content_type='text/html',body=html,headers=headers or {})
        await page.context.route('**/*',route)
        return page

    async def test_first_click_redirect_is_not_lost(self):
        page=await self.session.get_page('fuckingfast')
        async def route(r):
            path=e.urlsplit(r.request.url).path
            if path=='/go':
                await r.fulfill(status=200,headers={'HX-Redirect':'https://dl.fuckingfast.co/dl/fixture'},body='ok')
            else:
                await r.fulfill(content_type='text/html',body='<a href="#" onclick="this.remove(); fetch(\'/go\')">DOWNLOAD</a>')
        await page.context.route('**/*',route)
        result=await e.resolve_on_page(page,'https://fuckingfast.co/fixture')
        self.assertEqual(result.status,'success')
        self.assertEqual(result.url,'https://dl.fuckingfast.co/dl/fixture')
        await self.session.close_page(page)

    async def test_error_phrase_inside_script_does_not_mark_removed(self):
        page=await self.fixture_page('<script>const msg="File Not Found";</script><a href="https://dl.fuckingfast.co/dl/fixture">DOWNLOAD</a>')
        result=await e.resolve_on_page(page,'https://fuckingfast.co/fixture')
        self.assertEqual(result.status,'success')
        await self.session.close_page(page)

    async def test_removed_and_rate_limit_status(self):
        for status,expected in ((404,'removed'),(429,'rate_limited'),(403,'verification_required')):
            page=await self.fixture_page('Server response',status=status)
            result=await e.resolve_on_page(page,'https://fuckingfast.co/fixture')
            self.assertEqual(result.status,expected)
            await self.session.close_page(page)

    async def test_untrusted_redirect_is_not_accepted(self):
        page=await self.fixture_page('File Not Found',headers={'HX-Redirect':'https://evil.test/?next=dl.fuckingfast.co/dl/a'})
        result=await e.resolve_on_page(page,'https://fuckingfast.co/fixture')
        self.assertEqual(result.status,'removed')
        await self.session.close_page(page)

    async def test_cancel_during_navigation_cleans_page(self):
        page=await self.session.get_page('filekeeper')
        arrived=asyncio.Event()
        async def slow(r):
            arrived.set()
            await asyncio.sleep(1)
            try:await r.abort()
            except Exception:pass
        await page.context.route('**/*',slow)
        task=asyncio.create_task(e.resolve_on_page(page,'https://filekeeper.net/fixture'))
        await asyncio.wait_for(arrived.wait(),5)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):await task
        await self.session.close_page(page)
        self.assertFalse(self.session.allowed_pages)

    async def test_checkpoint_precedes_cancelled_listener_cleanup(self):
        page=await self.fixture_page('<a href="https://dl.fuckingfast.co/dl/checkpoint">DOWNLOAD</a>')
        sink=e.ResultSink(ROOT/'.test-output'/'cleanup-cancel-links.txt')
        with patch.object(page,'unroute',new=AsyncMock(side_effect=asyncio.CancelledError())):
            with self.assertRaises(asyncio.CancelledError):
                await e.resolve_on_page(page,'https://fuckingfast.co/fixture',on_success=sink.add)
        self.assertEqual(sink.path.read_text().splitlines(),['https://dl.fuckingfast.co/dl/checkpoint'])
        await self.session.close_page(page)

    async def test_100_parts_keep_pages_tasks_and_output_bounded(self):
        first=await self.session.get_page('fuckingfast')
        context=first.context
        await self.session.close_page(first)
        payload_requests=0
        async def fixture(r):
            nonlocal payload_requests
            path=e.urlsplit(r.request.url).path
            if e.is_direct_link(r.request.url):
                payload_requests+=1
                await r.abort()
            elif path.startswith('/go/'):
                part=path.rsplit('/',1)[-1]
                await r.fulfill(status=200,headers={'HX-Redirect':'https://dl.fuckingfast.co/dl/'+part},body='ok')
            else:
                part=path.rsplit('/',1)[-1]
                await r.fulfill(content_type='text/html',body=f'<a href="#" onclick="window.open(\'about:blank\');this.remove();fetch(\'/go/{part}\')">DOWNLOAD</a>')
        await context.route('**/*',fixture)
        destination=ROOT/'.test-output'/'browser_100_links.txt'
        sink=e.ResultSink(destination)
        tracemalloc.start();start=time.perf_counter()
        peak_pages=peak_tasks=0
        for i in range(100):
            page=await self.session.get_page('fuckingfast')
            result=await e.resolve_on_page(page,'https://fuckingfast.co/fixture/'+str(i))
            self.assertEqual(result.status,'success',f'part {i}')
            sink.add(result.url)
            await self.session.close_page(page)
            if self.session.tasks:await asyncio.gather(*list(self.session.tasks),return_exceptions=True)
            peak_pages=max(peak_pages,len(context.pages));peak_tasks=max(peak_tasks,len(self.session.tasks))
            self.assertEqual(len(context.pages),0)
            self.assertEqual(len(self.session.tasks),0)
        current,peak=tracemalloc.get_traced_memory();tracemalloc.stop()
        self.assertEqual(len(sink.links),100)
        self.assertEqual(sink.links,['https://dl.fuckingfast.co/dl/'+str(i) for i in range(100)])
        self.assertEqual(payload_requests,0)
        metrics={'parts':100,'seconds':round(time.perf_counter()-start,3),'pages_after_each_part_max':peak_pages,
                 'pending_popup_tasks_after_each_part_max':peak_tasks,'python_traced_current_bytes':current,
                 'python_traced_peak_bytes':peak,'payload_requests':payload_requests}
        (ROOT/'.test-output'/'browser-metrics.json').write_text(json.dumps(metrics,indent=2))


if __name__=='__main__':unittest.main()
