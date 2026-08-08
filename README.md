# get.oxrion.com

Install gate for the **Oxrion dispatcher** (`oxrion` command).

```
curl -fsSL https://get.oxrion.com | sh      # Linux / macOS
irm https://get.oxrion.com/win | iex        # Windows
```

That installs only the tiny `oxrion` dispatcher into `~/.oxrion/bin`
(`%LOCALAPPDATA%\Oxrion\bin` on Windows) and puts it on PATH. On first use of a
tool, the dispatcher reads `manifest.json` here and downloads the real tool
(recovery, licenser, …) from `protection-releases`, verifying its SHA256.

## Files
- `bootstrap.sh`  — Linux/macOS installer (served at `/`)
- `bootstrap.ps1` — Windows installer (served at `/win`)
- `manifest.json` — product catalogue the dispatcher reads
- `vercel.json`   — routing (`/` → sh, `/win` → ps1) + content-types

The dispatcher binaries themselves live in `oxrion/dispatcher-releases`; the
bootstrap fetches the latest from there. This repo hosts only the install
scripts and the manifest.
