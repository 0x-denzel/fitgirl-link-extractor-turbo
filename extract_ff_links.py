"""Legacy entrypoint sharing the portable BAT engine and its CLI options."""
import argparse
import asyncio
from pathlib import Path
import sys
from download_util import load_engine


def main():
    parser = argparse.ArgumentParser(description='Legacy link extractor backed by the standalone engine')
    parser.add_argument('source',nargs='?')
    parser.add_argument('-o','--output',default=str(Path.home()/'Downloads'/'idm_links.txt'))
    parser.add_argument('--no-bonus',action='store_true')
    parser.add_argument('--lang',default='all')
    args = parser.parse_args()
    engine = load_engine()
    source = args.source or (engine.ask('Paste a URL or file path: ') if sys.stdin.isatty() else '')
    if not source:
        parser.print_usage()
        return
    try:
        return asyncio.run(engine.run_pipeline(source,args.output,args.no_bonus,
            None if args.lang.lower() in ('all','none') else args.lang.lower(),interactive=False))
    except KeyboardInterrupt:
        print('\nCancelled.')


if __name__ == '__main__':
    main()
