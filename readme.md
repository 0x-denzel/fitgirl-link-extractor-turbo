![FitGirl Turbo Link Extractor — by Chidera Okonkwo (0xdenzel)](assets/banner.png)

# FitGirl Turbo Link Extractor

A high-performance Python tool that extracts direct download links from **FitGirl Repacks**, **PrivateBin pastes**, and supported file hosts, ready for **Internet Download Manager (IDM)**, **JDownloader 2**, and **Free Download Manager (FDM)**.

**Latest release: v1.3.2** · By [**Chidera Okonkwo (0xdenzel)**](https://chideraokonkwo.com)

## What's New

- **FileKeeper and FuckingFast support:** Choose your preferred download mirror from a FitGirl repack page.
- **Automatic first-run setup:** Missing dependencies download and install automatically. A browser runtime is also downloaded when needed.
- **Windows and macOS launchers:** Launch directly without cloning the repository or creating a virtual environment.
- **Batch processing:** Process a repack page, PrivateBin paste, individual links, or a text file containing multiple URLs.
- **Improved progress saving:** Press **Ctrl+C** to stop and keep the links already completed.
- **Expanded command-line options:** Choose a mirror, filter languages and bonus content, and set your output file.

## Features

- Extract direct links for single files and multi-part archives.
- Process supported links silently in the background, without browser popups.
- Choose English, another selective language, or all available languages.
- Exclude optional bonus content when you don't need it.
- Export a download-manager-ready text file and copy links to the clipboard.
- Save `.torrent` files or open magnet links with your torrent client.
- Follow progress on one terminal line, with handling for unavailable links and temporary failures.
- Process multiple games in one interactive session.

## Supported Hosters & Mirrors

| Source | Support |
| :--- | :--- |
| **FileKeeper** | Direct download links — recommended |
| **FuckingFast** | Direct download links |
| **FitGirl repack pages** | Select a supported host or torrent mirror |
| **FitGirl PrivateBin pastes** | Read supported links or torrent attachments |
| **Magnet links and `.torrent` files** | Torrent-client handoff or file export |

**DataNodes extraction is currently unsupported.** Choose FileKeeper or FuckingFast instead.

## Prerequisites

- **Python 3.10 or newer**, available in your terminal. On Windows, select **Add Python to PATH** during installation.
- An internet connection for first-run setup and link processing.
- A writable folder for the application files.

**You do not need to install the Python dependencies manually.** On first use, the tool automatically installs any missing packages: Playwright, Playwright-Stealth, BeautifulSoup4, and Requests. It uses compatible installed Chrome when available, or downloads Chromium when needed. Setup may take a few minutes; later runs reuse the installed dependencies.

## Installation

### Option 1: Download and Launch — Recommended

**Windows**

1. Download [Download_FitGirl_Links.bat](https://github.com/0x-denzel/fitgirl-link-extractor-turbo/releases/latest/download/Download_FitGirl_Links.bat).
2. Save it in a writable folder and double-click it.
3. Allow first-run setup to finish, then follow the prompts.

**macOS**

1. Download the BAT above and [Download_FitGirl_Links.command](https://github.com/0x-denzel/fitgirl-link-extractor-turbo/releases/latest/download/Download_FitGirl_Links.command).
2. Keep both files in the same folder.
3. Make the launcher executable if needed, then open it:

```bash
chmod +x Download_FitGirl_Links.command
./Download_FitGirl_Links.command
```

No Git checkout or virtual environment is required for these launchers. You can also find both files on the [latest release page](https://github.com/0x-denzel/fitgirl-link-extractor-turbo/releases/latest).

### Option 2: Clone the Repository

Use this option if you want the additional `app.py` command-line interface.

```bash
git clone https://github.com/0x-denzel/fitgirl-link-extractor-turbo.git
cd fitgirl-link-extractor-turbo
python -x Download_FitGirl_Links.bat
```

Keep the project files together. Dependencies still install automatically when needed.

## Usage

### 1. Interactive Mode

Double-click your launcher, or run:

```bash
python -x Download_FitGirl_Links.bat
```

Copy your links before launching, or paste them when prompted. You can also enter the path to a text file. For a multiline list, finish with an empty line. The interactive flow lets you choose your mirror, language, and bonus-content preferences.

### 2. From a FitGirl Repack Page

```bash
python -x Download_FitGirl_Links.bat "https://fitgirl-repacks.site/game-name/"
```

Choose a mirror directly to skip the mirror selector:

```bash
python -x Download_FitGirl_Links.bat "https://fitgirl-repacks.site/game-name/" --mirror filekeeper
python -x Download_FitGirl_Links.bat "https://fitgirl-repacks.site/game-name/" --mirror fuckingfast
```

Use `--mirror auto` to select the preferred available host automatically.

### 3. From a PrivateBin Paste

```bash
python -x Download_FitGirl_Links.bat "https://paste.fitgirl-repacks.site/?PASTE_ID#DECRYPTION_KEY"
```

Replace the example with your complete paste URL, including the part after `#`.

### 4. From a Text File of URLs

Put one supported URL on each line in `my_links.txt`, then run:

```bash
python -x Download_FitGirl_Links.bat "my_links.txt"
```

To choose an output file, keep English selective files, and skip bonus content:

```bash
python -x Download_FitGirl_Links.bat "my_links.txt" --lang english --no-bonus -o "game_links.txt"
```

To retain all languages:

```bash
python -x Download_FitGirl_Links.bat "my_links.txt" --lang all
```

### Main Launcher Options

| Option | Description |
| :--- | :--- |
| `source` | A repack/paste URL, supported host link, magnet, `.torrent` URL, or text-file path. Omit it for interactive mode. |
| `--mirror auto` | Automatically choose the preferred available repack host. |
| `--mirror filekeeper` | Select FileKeeper for a repack page. |
| `--mirror fuckingfast` | Select FuckingFast for a repack page. |
| `--lang english` | Keep English selective files; this is the command-line default. |
| `--lang all` | Keep every selective language. Another language name, such as `french`, keeps that language instead. |
| `--no-bonus` | Exclude optional bonus files. Without this flag, bonus files are retained. |
| `-o`, `--output` | Set the output file path. |
| `--help` | Show available options. |
| `--version` | Show the application version. |

Use `python3` instead of `python` on macOS/Linux. The main launcher takes a text-file path directly; the `--file` flag belongs to `app.py` below.

## Python Command-Line Interface (`app.py`)

This entry point is included in the full repository for existing workflows.

Process a repack page using FuckingFast:

```bash
python app.py --url "https://fitgirl-repacks.site/game-name/"
```

Exclude bonus files and all selective language packs:

```bash
python app.py --url "https://fitgirl-repacks.site/game-name/" --noBonus --noLanguage
```

Process a text file or set a custom output path:

```bash
python app.py --file "my_links.txt"
python app.py --file "my_links.txt" -o "game_links.txt"
```

| Option | Description |
| :--- | :--- |
| `--url` | FitGirl repack page; this mode selects FuckingFast. |
| `--file` | Text file containing supported links. Use either `--url` or `--file`. |
| `--noBonus` | Exclude optional bonus files. |
| `--noLanguage` | Exclude **all** selective language packs. Without this flag, this tool retains all languages. |
| `-o`, `--output` | Choose an output file. |

Use the main launcher when you want mirror selection or to retain one particular language.

Run `python app.py --help` for its available options.

## Where Are My Links Saved?

| Entry point | Default output |
| :--- | :--- |
| Windows/macOS launcher or `python -x Download_FitGirl_Links.bat` | `<Game_Name>_links.txt` in your Downloads folder |
| `app.py` | `output/<name>_links.txt` under the folder you run it from |

Use `-o` to change the destination. Exported files contain one direct URL per line. Completed links are also copied to your clipboard when available, and the saved file is revealed in Explorer/Finder.

Press **Ctrl+C** during processing to save the links completed so far. If a host link expires later, process the source again to obtain a fresh one.

## How to Import into IDM

1. Open **Internet Download Manager**.
2. Go to **Tasks → Import → From text file**.
3. Select the generated links file from Downloads, `output/`, or your custom destination.
4. Select the files you want and start the queue.

For **JDownloader 2** or **FDM**, paste the copied links into the manager's add-links window. Magnet links and `.torrent` files use your preferred torrent client.

## License & Acknowledgements

This project is licensed under the [MIT License](LICENSE) · Maintained and overhauled by [**Chidera Okonkwo (0xdenzel)**](https://chideraokonkwo.com) ([@0x-denzel](https://github.com/0x-denzel)).

Special thanks and attribution to **Novandi Ramadhan** for the original base project and inspiration.
