![FitGirl Turbo Link Extractor — by 0xDENZEL](assets/banner.png)

# FitGirl Turbo Link Extractor

Quickly extract direct download links from **FitGirl Repacks**, ready to import into **IDM**, **JDownloader 2**, or **Free Download Manager**. Supports **FileKeeper**, **FuckingFast**, magnet links, and `.torrent` files on Windows and macOS.

## Supported Hosters & Mirrors

| Mirror | Support |
| :--- | :--- |
| **FileKeeper** | Direct download links — recommended |
| **FuckingFast** | Direct download links |
| **Magnet links** | Open with your torrent client |
| **.torrent files** | Save to Downloads |

DataNodes extraction is currently unsupported. Choose FileKeeper or FuckingFast instead.

## 1-Click Launch

**Python 3.10 or newer is required.** Dependencies install automatically on first use. No Git or virtual environment is needed.

- 🚀 **Windows:** Download [Download_FitGirl_Links.bat](https://github.com/EditByDenzel/fitgirl-link-extractor-turbo/releases/latest/download/Download_FitGirl_Links.bat) and double-click it.
- 🍎 **macOS:** Download the BAT above and [Download_FitGirl_Links.command](https://github.com/EditByDenzel/fitgirl-link-extractor-turbo/releases/latest/download/Download_FitGirl_Links.command). Put both in the same folder and run the `.command` file. If needed, run `chmod +x Download_FitGirl_Links.command` first.

## How It Works

1. Copy a FitGirl repack page, PrivateBin paste, or list of supported links.
2. Launch the tool and use your clipboard contents or paste your links.
3. Choose your mirror, language, and optional-content preferences.
4. Import the saved links from your Downloads folder into your download manager.

Links are also copied to your clipboard. Progress stays on one line, and **Ctrl+C** saves the links completed so far. Torrent links can be opened in your default torrent client.

## Command Line Usage

```powershell
python -x Download_FitGirl_Links.bat "https://fitgirl-repacks.site/game-name/"
python -x Download_FitGirl_Links.bat "links.txt" --lang english --no-bonus -o "game_links.txt"
```

Use `python3` on macOS. Run with `--help` for more options.

## License

[MIT License](LICENSE) · By **0xDENZEL**
