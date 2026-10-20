"""Compatibility entrypoint preserving --url/--file/--noBonus/--noLanguage."""
import argparse
import asyncio
from pathlib import Path
from download_util import load_engine


def extract_links(url, exclude_bonus=False, exclude_language=False):
    engine = load_engine()
    engine.ensure_dependencies()
    data = engine.scrape_fitgirl_repack_mirrors(url)
    links = [m['url'] for m in data['direct_mirrors'] if m['host'] == 'fuckingfast' and not engine.is_paste(m['url'])]
    return [u for u in engine.filter_links(links, exclude_bonus, None)
            if not exclude_language or 'fg-selective' not in engine.filename_hint(u).lower()]


async def async_main(argv=None):
    parser = argparse.ArgumentParser(description='FitGirl link extractor (legacy CLI)')
    sources = parser.add_mutually_exclusive_group(required=True)
    sources.add_argument('--url')
    sources.add_argument('--file')
    parser.add_argument('--noBonus', action='store_true')
    parser.add_argument('--noLanguage', action='store_true')
    parser.add_argument('-o', '--output')
    args = parser.parse_args(argv)
    engine = load_engine()
    prefix = engine.safe_filename(engine.urlsplit(args.url).path.rstrip('/').rsplit('/',1)[-1]) if args.url else engine.safe_filename(Path(args.file).stem)
    output = args.output or str(Path.cwd()/'output'/(prefix+'_links.txt'))
    return await engine.run_pipeline(args.url or args.file, output, args.noBonus,
                                     '__exclude_all_selective_languages__' if args.noLanguage else None,
                                     mirror='fuckingfast' if args.url else None)


def main():
    try:
        return asyncio.run(async_main())
    except KeyboardInterrupt:
        print('\nCancelled.')


if __name__ == '__main__':
    main()
