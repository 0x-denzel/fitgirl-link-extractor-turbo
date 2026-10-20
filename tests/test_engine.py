"""Offline regressions. No user clipboard, clients, Downloads, or network access."""
import asyncio
import contextlib
import hashlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import AsyncMock, Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from download_util import load_engine
e = load_engine()
TMP = ROOT / '.test-output'
TMP.mkdir(exist_ok=True)


class ParsingTests(unittest.TestCase):
    def test_polyglot_first_line_is_exact(self):
        first=(ROOT/'Download_FitGirl_Links.bat').read_bytes().split(b'\n',1)[0]
        self.assertEqual(hashlib.sha256(first).hexdigest(),'d51a1c87f4a1c9d151502075ee206bd146f5607d6b7c0e8bad18208c116d46f7')

    def test_source_response_size_bound(self):
        with patch.object(e.urllib.request,'urlopen',return_value=io.BytesIO(b'123456')):
            with self.assertRaisesRegex(e.ExtractionError,'size'):
                e.fetch_bytes('https://example.test',limit=3)

    def test_cdn_case_order_and_duplicates(self):
        urls = ['https://filekeeper.net/a/Game.part01.rar', 'HTTPS://FUCKINGFAST.CO/b#Game.part02.rar',
                'https://tunnel1.dlproxy.uk/download/abc?token=a%2Fb&next=%20']
        self.assertEqual(e.parse_links_from_text('\n'.join(urls+urls)), urls)

    def test_spoofed_hosts_and_queries(self):
        for url in ('https://example.org/?u=datanodes.to/d/a', 'https://dl.fuckingfast.co.evil.test/dl/a',
                    'https://user@filekeeper.net/a', 'https://datanodes.to:444/d/a', 'javascript:dlproxy.uk/a'):
            with self.subTest(url=url):
                self.assertFalse(e.is_direct_link(url))
                self.assertFalse(e.detect_hoster(url))

    def test_signed_query_not_reencoded(self):
        url = 'https://tunnel1.dlproxy.uk/download/a?sig=A%2FB+%3D&x=1'
        self.assertEqual(e.parse_links_from_text(url), [url])

    def test_json_escaped_urls_and_entities(self):
        self.assertEqual(e.parse_links_from_text('{"files":[{"href":"https:\\/\\/filekeeper.net\\/a?x=1&y=2"}]}'),
                         ['https://filekeeper.net/a?x=1&y=2'])
        self.assertEqual(e.parse_links_from_text('https://filekeeper.net/a?x=1&amp;y=2'), ['https://filekeeper.net/a?x=1&y=2'])

    def test_percent_and_unicode_game_names(self):
        self.assertEqual(e.detect_game_name(['https://filekeeper.net/a/My%20Game.part01.rar']), 'My_Game')
        self.assertEqual(e.detect_game_name(['https://filekeeper.net/a/日本語.part01.rar']), '日本語')
        self.assertEqual(e.detect_game_name(['https://fuckingfast.co/a#My_Game_--_part1.rar']), 'My_Game')

    def test_windows_names_and_controls(self):
        for value in ('../CON', 'CON', '日本/語\r\n', 'x\x1b[31m', '..\\evil', 'a:*?"b'):
            name = e.safe_filename(value)
            self.assertNotRegex(name, r'[<>:"/\\|?*\r\n\x1b]')
        self.assertEqual(e.safe_filename('CON'), '_CON')

    def test_magnet_detection(self):
        url = 'magnet:?xt=urn:btih:' + 'a'*40 + '&dn=Test'
        self.assertTrue(any(e.inspect_input(url)))
        self.assertFalse(e.is_magnet('magnet:?xt=urn:btih:1234'))

    def test_mirror_parts_and_context_label(self):
        html = '<article><h1 class="entry-title">Game</h1><p>FileKeeper <a href="https://paste.fitgirl-repacks.site/?x#key">Download</a></p><a href="https://filekeeper.net/a/Game.part1.rar">Part 1</a><a href="https://filekeeper.net/b/Game.part2.rar">Part 2</a></article>'
        result = e.parse_repack_html(html, 'https://fitgirl-repacks.site/game/')
        self.assertEqual(len(result['direct_mirrors']), 3)

    def test_relative_torrent_and_spoof(self):
        result = e.parse_repack_html('<a href="/game.torrent">Download</a><a href="https://evil.test/?u=filekeeper.net">FileKeeper</a>', 'https://fitgirl-repacks.site/game/')
        self.assertEqual(result['torrent_mirrors'][0]['url'], 'https://fitgirl-repacks.site/game.torrent')
        self.assertFalse(result['direct_mirrors'])
        self.assertFalse(e.parse_repack_html('<html></html>', 'https://fitgirl-repacks.site/game/')['direct_mirrors'])

    def test_malformed_post_mirrors_outside_article(self):
        content='<div class="content-area"><article><div class="entry-content"><a href="https://datanodes.to/a/Game.part1.rar">DataNodes</a></div></article><a href="https://filekeeper.net/a/Game.part1.rar">FileKeeper</a><div id="comments"><a href="https://filekeeper.net/b/Other.rar">Unrelated</a></div></div>'
        result=e.parse_repack_html(content,'https://fitgirl-repacks.site/game/')
        self.assertEqual([m['host'] for m in result['direct_mirrors']],['filekeeper','datanodes'])

    def test_manifest_requires_all_parts_and_same_archive(self):
        primary = ['https://datanodes.to/a/Game.part1.rar', 'https://datanodes.to/b/Game.part2.rar']
        other = ['https://filekeeper.net/b/Game.part02.rar', 'https://filekeeper.net/a/Game.part01.rar']
        self.assertEqual(len(e.compatible_manifest(primary, other)), 2)
        self.assertFalse(e.compatible_manifest(primary, other[:1]))
        self.assertFalse(e.compatible_manifest(primary, [u.replace('Game','Other') for u in other]))
        self.assertFalse(e.compatible_manifest(primary, [other[0],other[0]]))
        self.assertFalse(e.compatible_manifest(['https://datanodes.to/id'], ['https://filekeeper.net/id']))

    def test_error_classification_uses_visible_text(self):
        self.assertEqual(e.page_failure(404, '').status, 'removed')
        self.assertEqual(e.page_failure(429, '').status, 'rate_limited')
        self.assertEqual(e.page_failure(403, '').status, 'verification_required')
        self.assertIsNone(e.page_failure(200, 'Healthy file\nHelp: what does File Not Found mean?'))

    def test_paste_error_messages(self):
        for text in ('Paste does not exist, has expired or has been deleted.', 'Please enter the password for this paste.', 'Could not decrypt data: invalid ciphertext'):
            self.assertTrue(e.paste_error(text))

    def test_bencoded_torrent_validation(self):
        data = b'd4:infod6:lengthi1e4:name1:x12:piece lengthi16384e6:pieces20:abcdefghijklmnopqrstee'
        self.assertTrue(e.valid_torrent(data))
        for invalid in (b'<html>error</html>', data+b'junk', b'd4:infodee', b'd4:infoi3ee', data[:-1]):
            self.assertFalse(e.valid_torrent(invalid))

    def test_help_without_site_packages(self):
        proc = subprocess.run([sys.executable, '-S', '-x', str(ROOT/'Download_FitGirl_Links.bat'), '--help'], capture_output=True, timeout=10)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(b'--mirror', proc.stdout)
        self.assertNotIn(b'Installing', proc.stdout)

    def test_legacy_help_without_dependencies(self):
        for script in ('app.py', 'extract_ff_links.py'):
            proc = subprocess.run([sys.executable, '-S', str(ROOT/script), '--help'], capture_output=True, timeout=10)
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_every_browser_launch_is_headless(self):
        import ast
        tree = ast.parse('\n'+(ROOT/'Download_FitGirl_Links.bat').read_text(encoding='utf-8').split('\n',1)[1])
        launches = [n for n in ast.walk(tree) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr=='launch']
        self.assertTrue(launches)
        for call in launches:
            self.assertTrue(any(k.arg=='headless' and isinstance(k.value,ast.Constant) and k.value.value is True for k in call.keywords))


class ProgressAndOutputTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=TMP)
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)/'Game_links.txt'

    def test_widths_and_unicode(self):
        progress = e.Progress(100)
        for width in (40,80,120):
            for status in ('> resolving','x removed','+ OK'):
                row = progress.render(99,'日本語'*40+'\r\n\x1b[2J',status,width)
                self.assertLess(e.display_width(row),width)
                self.assertNotRegex(row,r'[\r\n\x1b]')
                self.assertIn('99%',row)
                self.assertIn(status,row)

    def test_one_row_and_redirected_stdout(self):
        output=io.StringIO(); output.isatty=lambda:True
        progress=e.Progress(100,output)
        for i in range(100): progress.update(i+1,'Part','+ OK')
        self.assertNotIn('\n',output.getvalue())
        self.assertEqual(output.getvalue().count('\r'),100)
        self.assertEqual(output.getvalue().count('\033[K'),100)
        progress.finish();self.assertEqual(output.getvalue().count('\n'),1)
        redirected=io.StringIO();e.Progress(1,redirected).update(1,'Part','OK')
        self.assertEqual(redirected.getvalue(),'')

    def test_atomic_checkpoint_survives_write_failure(self):
        sink=e.ResultSink(self.path)
        one='https://tunnel1.dlproxy.uk/download/1';two='https://tunnel1.dlproxy.uk/download/2'
        sink.add(one)
        with patch.object(e.os,'replace',side_effect=PermissionError):
            with self.assertRaises(PermissionError):sink.add(two)
        self.assertEqual(self.path.read_text().splitlines(),[one])
        self.assertEqual(sink.links,[one])
        self.assertFalse(list(self.path.parent.glob('*.tmp')))

    def test_bom_file_input(self):
        url='https://filekeeper.net/a'
        self.path.write_bytes(url.encode('utf-16'))
        self.assertEqual(e.read_source(str(self.path)),url)

    def test_clipboard_failure_is_bounded(self):
        with patch.object(e.sys,'platform','darwin'),patch.object(e.shutil,'which',return_value='/usr/bin/pbcopy'),patch.object(e,'quiet_process',side_effect=subprocess.TimeoutExpired('pbcopy',2)) as proc:
            self.assertFalse(e.copy_to_clipboard('日本語'))
            self.assertEqual(proc.call_args.kwargs['timeout'],2)


class PipelineTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(dir=TMP);self.addCleanup(self.tmp.cleanup)
        self.path=Path(self.tmp.name)/'Game_links.txt'
        self.input='https://filekeeper.net/a/Game.part1.rar\nhttps://filekeeper.net/b/Game.part2.rar'
        self.patches=[patch.object(e,'ensure_dependencies'),patch.object(e.BrowserSession,'start',new=AsyncMock()),
                      patch.object(e,'copy_to_clipboard',return_value=True),patch.object(e,'reveal_file',return_value=True)]
        for p in self.patches:p.start();self.addCleanup(p.stop)

    async def run_quiet(self,source=None,**kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            return await e.run_pipeline(source or self.input,str(self.path),**kwargs)

    async def test_direct_filters_precede_passthrough(self):
        urls=['https://dl.fuckingfast.co/dl/a#Game_--_fg-optional-bonus.bin',
              'https://dl.fuckingfast.co/dl/b#Game_--_fg-selective-french.bin',
              'https://dl.fuckingfast.co/dl/c#Game_--_fg-01.bin']
        result=await self.run_quiet('\n'.join(urls),exclude_bonus=True,keep_lang='english')
        self.assertEqual(result.resolved,1)
        self.assertEqual(self.path.read_text().splitlines(),['https://dl.fuckingfast.co/dl/c'])

    async def test_cancellation_and_failure_preserve_first_link(self):
        for failure in (asyncio.CancelledError(),RuntimeError('browser lost')):
            with self.subTest(failure=type(failure).__name__),patch.object(e,'resolve_url',new=AsyncMock(side_effect=[e.Resolution('success','https://tunnel1.dlproxy.uk/download/1'),failure])):
                result=await self.run_quiet()
                self.assertEqual(result.resolved,1)
                self.assertEqual(self.path.read_text().splitlines(),['https://tunnel1.dlproxy.uk/download/1'])
                self.assertTrue(result.interrupted or result.error)

    async def test_cancel_before_first_does_not_overwrite(self):
        self.path.write_text('prior file')
        with patch.object(e,'resolve_url',new=AsyncMock(side_effect=asyncio.CancelledError())):
            result=await self.run_quiet()
        self.assertTrue(result.interrupted)
        self.assertEqual(self.path.read_text(),'prior file')

    async def test_clipboard_exception_does_not_block_reveal(self):
        with patch.object(e,'copy_to_clipboard',side_effect=RuntimeError),patch.object(e,'reveal_file') as reveal:
            result=await self.run_quiet('https://dl.fuckingfast.co/dl/a')
        self.assertEqual(result.resolved,1);reveal.assert_called_once()

    async def test_all_filtered_does_not_start_browser(self):
        result=await self.run_quiet('https://filekeeper.net/a/fg-selective-french.bin',keep_lang='english')
        self.assertEqual(result.total,0);e.BrowserSession.start.assert_not_awaited()

    async def test_datanodes_uses_verified_fallback_without_attempting_source(self):
        urls=['https://datanodes.to/a/Game.part1.rar','https://datanodes.to/b/Game.part2.rar']
        alt={e.url_identity(u):['https://filekeeper.net/'+str(i)+'/Game.part'+str(i+1)+'.rar'] for i,u in enumerate(urls)}
        calls=[]
        async def resolver(session,url,**kwargs):
            calls.append(url)
            self.assertNotEqual(e.detect_hoster(url),'datanodes')
            return e.Resolution('success','https://tunnel1.dlproxy.uk/download/'+str(len(calls)))
        with patch.object(e,'resolve_url',side_effect=resolver):
            result=await e.process_batch(urls,alt,None,e.ResultSink(self.path),e.Progress(2,io.StringIO()))
        self.assertEqual(result.resolved,2)
        self.assertEqual(sum(e.detect_hoster(u)=='datanodes' for u in calls),0)

    async def test_missing_fallback_does_not_guess(self):
        with patch.object(e,'resolve_url',new=AsyncMock(return_value=e.Resolution('verification_required'))) as resolver:
            result=await self.run_quiet('https://datanodes.to/a/Game.part1.rar\nhttps://datanodes.to/b/Game.part2.rar')
        self.assertEqual(result.resolved,0);self.assertEqual(resolver.await_count,0)
        self.assertEqual(result.statuses,{'alternative_required':2})
        e.BrowserSession.start.assert_not_awaited()
        e.ensure_dependencies.assert_not_called()
        self.assertFalse(self.path.exists())

    async def test_datanodes_resolver_never_navigates_landing_page(self):
        session=Mock(get_page=AsyncMock())
        page=Mock()
        url='https://datanodes.to/a/Game.part1.rar'
        self.assertEqual((await e.resolve_url(session,url)).status,'alternative_required')
        self.assertEqual((await e.resolve_on_page(page,url)).status,'alternative_required')
        session.get_page.assert_not_awaited()
        self.assertFalse(page.mock_calls)

    async def test_datanodes_direct_url_still_passes_without_browser(self):
        result=await self.run_quiet('https://datanodes.to/d/direct-file')
        self.assertEqual(result.resolved,1)
        self.assertEqual(self.path.read_text().splitlines(),['https://datanodes.to/d/direct-file'])
        e.BrowserSession.start.assert_not_awaited()
        e.ensure_dependencies.assert_not_called()

    async def test_legacy_datanodes_repack_maps_matching_alternatives(self):
        dn=['https://datanodes.to/a/Game.part1.rar','https://datanodes.to/b/Game.part2.rar']
        fk=['https://filekeeper.net/a/Game.part1.rar','https://filekeeper.net/b/Game.part2.rar']
        ff=['https://fuckingfast.co/a#Game.part1.rar','https://fuckingfast.co/b#Game.part2.rar']
        data={'game_title':'Game','direct_mirrors':[{'host':e.detect_hoster(u),'url':u} for u in dn+fk+ff],'torrent_mirrors':[]}
        with patch.object(e,'scrape_fitgirl_repack_mirrors',return_value=data):
            batch=await e.prepare_batch('https://fitgirl-repacks.site/game/',None,mirror='datanodes')
        self.assertEqual(batch.urls,dn)
        self.assertEqual(batch.alternatives,{e.url_identity(u):[fk[i],ff[i]] for i,u in enumerate(dn)})
        self.assertIn('unsupported',batch.warnings[0])

    async def test_alternate_failure_tries_second_matching_host(self):
        dn='https://datanodes.to/a/Game.part1.rar'
        alt=['https://filekeeper.net/a/Game.part1.rar','https://fuckingfast.co/a#Game.part1.rar']
        results=[e.Resolution('verification_required'),e.Resolution('success','https://dl.fuckingfast.co/dl/a')]
        with patch.object(e,'resolve_url',new=AsyncMock(side_effect=results)) as resolver:
            summary=await e.process_batch([dn],{e.url_identity(dn):alt},None,e.ResultSink(self.path),e.Progress(1,io.StringIO()))
        self.assertEqual(summary.resolved,1)
        self.assertEqual([call.args[1] for call in resolver.call_args_list],alt)

    async def test_missing_paste_key_fails_without_navigation(self):
        page=Mock()
        with self.assertRaisesRegex(e.ExtractionError,'decryption-key'):
            await e.load_paste(page,'https://paste.fitgirl-repacks.site/?id')
        page.goto.assert_not_called()

    async def test_paste_errors_are_not_success(self):
        page=Mock();page.goto=AsyncMock(return_value=Mock(status=200))
        page.inner_text=AsyncMock(return_value='Paste has expired or has been deleted.')
        with self.assertRaisesRegex(e.ExtractionError,'expired'):
            await e.extract_links_from_paste(page,'https://paste.fitgirl-repacks.site/?id#key')

    async def test_json_paste_ready_without_fixed_sleep(self):
        page=Mock();page.goto=AsyncMock(return_value=Mock(status=200))
        page.inner_text=AsyncMock(return_value='{"files":[{"href":"https:\\/\\/filekeeper.net\\/a"}]}')
        self.assertEqual(await e.extract_links_from_paste(page,'https://paste.fitgirl-repacks.site/?id#key'),['https://filekeeper.net/a'])

    async def test_cleanup_error_keeps_output(self):
        with patch.object(e.BrowserSession,'close',new=AsyncMock(side_effect=RuntimeError('cleanup failed'))):
            result=await self.run_quiet('https://dl.fuckingfast.co/dl/a')
        self.assertEqual(result.resolved,1);self.assertTrue(self.path.exists())

    async def test_resolution_cancel_closes_page(self):
        session=Mock();session.get_page=AsyncMock(return_value=object());session.close_page=AsyncMock()
        with patch.object(e,'resolve_on_page',new=AsyncMock(side_effect=asyncio.CancelledError())):
            with self.assertRaises(asyncio.CancelledError):await e.resolve_url(session,'https://filekeeper.net/a')
        session.close_page.assert_awaited_once()


class SetupAndLifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def test_browser_setup_reports_failure(self):
        process=Mock(returncode=1,wait=AsyncMock(return_value=1))
        with patch.object(e.asyncio,'create_subprocess_exec',new=AsyncMock(return_value=process)):
            with self.assertRaisesRegex(e.ExtractionError,'Browser setup failed'):
                await e.install_browser({})

    async def test_browser_setup_cancel_stops_only_its_process_tree(self):
        for platform in ('win32','linux'):
            with self.subTest(platform=platform):
                started=asyncio.Event()
                calls=0
                async def wait():
                    nonlocal calls
                    calls+=1
                    if calls==1:
                        started.set()
                        await asyncio.Event().wait()
                    return -1
                process=Mock(returncode=None,pid=4242,wait=wait)
                killer=Mock(returncode=0,wait=AsyncMock(return_value=0))
                spawn=AsyncMock(side_effect=[process,killer])
                with patch.object(e.sys,'platform',platform), \
                     patch.object(e.subprocess,'CREATE_NO_WINDOW',0x08000000,create=True), \
                     patch.object(e.os,'killpg',create=True) as killpg, \
                     patch.object(e.asyncio,'create_subprocess_exec',new=spawn):
                    task=asyncio.create_task(e.install_browser({}))
                    await asyncio.wait_for(started.wait(),1)
                    task.cancel()
                    with self.assertRaises(asyncio.CancelledError):
                        await asyncio.wait_for(task,2)
                    if platform=='win32':
                        self.assertEqual(spawn.call_args.args,('taskkill','/PID','4242','/T','/F'))
                        killpg.assert_not_called()
                    else:
                        killpg.assert_called_once_with(4242,e.signal.SIGTERM)
                        self.assertTrue(spawn.call_args.kwargs['start_new_session'])

    async def test_route_setup_failure_removes_registered_listeners(self):
        page=Mock(route=AsyncMock(side_effect=RuntimeError('route failed')),unroute=AsyncMock())
        with self.assertRaisesRegex(RuntimeError,'route failed'):
            await e.resolve_on_page(page,'https://filekeeper.net/a')
        self.assertEqual([call.args[0] for call in page.remove_listener.call_args_list],['download','response'])


class CliTests(unittest.TestCase):
    def test_primary_selector_and_auto_exclude_datanodes(self):
        data={'game_title':'Game','direct_mirrors':[{'host':host,'url':'https://'+host+'.test/file'} for host in e.HOST_ORDER], 'torrent_mirrors':[]}
        output=io.StringIO()
        with patch.object(e,'ask',return_value='1'),contextlib.redirect_stdout(output):
            selected,_,_=e.choose_mirror(data,interactive=True)
        self.assertEqual(selected,'filekeeper')
        self.assertNotIn('DataNodes',output.getvalue())
        data['direct_mirrors']=[{'host':'datanodes','url':'https://datanodes.to/a/Game.rar'}]
        with self.assertRaisesRegex(e.ExtractionError,'unsupported'):
            e.choose_mirror(data)

    def test_repack_options_forwarded(self):
        with patch.object(e,'run_pipeline',new=AsyncMock(return_value=e.RunSummary())) as run:
            e.main(['https://fitgirl-repacks.site/game/','-o','chosen.txt','--no-bonus','--lang','french','--mirror','datanodes'])
        self.assertEqual(run.call_args.args,('https://fitgirl-repacks.site/game/','chosen.txt',True,'french'))
        self.assertEqual(run.call_args.kwargs['mirror'],'datanodes')


if __name__=='__main__':unittest.main()
