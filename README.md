<div align="center">

# adobe-off

**Shut down Adobe Creative Cloud's background services when you're not using them, and bring them back when you are.**

[![CI](https://github.com/adamtty/adobe-off/actions/workflows/ci.yml/badge.svg)](https://github.com/adamtty/adobe-off/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/adamtty/adobe-off/badge)](https://scorecard.dev/viewer/?uri=github.com/adamtty/adobe-off)
![macOS](https://img.shields.io/badge/macOS-only-lightgrey?logo=apple)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

</div>

Install Photoshop or Premiere and you also get a crowd of helpers that run all the time, whether or not
you've opened an Adobe app this month: Adobe Desktop Service, Core Sync, CCXProcess, the IPC broker,
Creative Cloud Helper, crash reporters, and Adobe Genuine Service running as root. Quitting Creative
Cloud doesn't stop them, and killing them doesn't help either: launchd starts them straight back up.

`adobe off` stops them properly. `adobe on` puts everything back the way it was.

```console
$ adobe status
Adobe background processes: 8
  AGSService (root)
  CCXProcess
  Core Sync
  Adobe Desktop Service
  Adobe Crash Processor
  Creative Cloud Helper
  AdobeIPCBroker
  com.adobe.acc.installer.v2 (root)

$ adobe off
[+] Quitting Creative Cloud...
[+] Stopping login agents...
    stopped com.adobe.AdobeCreativeCloud
    stopped com.adobe.AdobeDesktopService
    ...
[+] Stopping root-owned services (needs your password)...
    stopped com.adobe.agsservice

Adobe background processes: 0
```

## Usage

| Command | What it does |
|---|---|
| `adobe` / `adobe status` | What's running, which services are disabled, and which creative apps are open |
| `adobe off` | Stop the background services until you next log in |
| `adobe off --persist` | Same, and keep them off across logins and restarts until `adobe on` |
| `adobe off --force` | Stop them even while a creative app is open (see below) |
| `adobe on` | Undo `off`, including `--persist`, and start Creative Cloud again |

Before you open Photoshop and friends, run `adobe on`. They need the background services for
licensing, fonts and libraries.

## Install

```bash
git clone https://github.com/adamtty/adobe-off.git
install -m 755 adobe-off/adobe ~/.local/bin/adobe   # or anywhere on your PATH
```

It's one bash script that only uses what ships with macOS: no Homebrew, no dependencies.

## What it stops

| | How | Undone by `adobe on` |
|---|---|---|
| **Login agents:** Creative Cloud, Adobe Desktop Service, CCXProcess, Genuine Service invoker and scheduler | `launchctl bootout` (with `--persist`, also `launchctl disable`) | `launchctl enable` + `bootstrap` |
| **Adobe Genuine Service** daemon (root) | `sudo launchctl bootout` (with `--persist`, also `disable`) | `sudo launchctl enable` + `bootstrap` |
| **Finder extensions:** Creative Cloud sidebar and right-click menu | `pluginkit -e ignore` | `pluginkit -e use` |
| **Everything else still running** from Adobe's background folders: Core Sync, IPC broker, helpers, crash reporters, the installer helper | `kill` (TERM, then KILL for the ones that ignore it) | Starts again when Creative Cloud needs it |

`sudo` is only used when something root-owned is actually running, or for `--persist`. If you don't
enter a password, the root-owned part is skipped and everything else still stops.

## How it stays safe

- **Your creative apps are never touched.** `adobe off` refuses to run while Photoshop, Premiere, After
  Effects or another Adobe app is open, so unsaved work can't lose its licence or sync mid-session.
  `--force` overrides that, but still never signals the apps themselves.
- **It picks processes by where their program lives, not by name.** Only programs installed under
  Adobe's background folders count, such as `/Library/Application Support/Adobe/` and
  `/Applications/Utilities/Adobe …/`. A process that merely has "Adobe" in its arguments (an editor
  with an Adobe file open, a `grep`) is never matched. A look-alike program somewhere else isn't either.
- **Only the system's own tools run.** `PATH` is reset to the system folders before anything else, so
  nothing earlier in your `PATH` can stand in for `kill`, `launchctl` or `sudo`.
- **Everything is reversible.** `off` only stops and disables. It never deletes, moves or edits
  Adobe's files, so `adobe on` (or a Creative Cloud reinstall) always gets you back.

## Uninstall

```bash
adobe on                    # if you used --persist
rm ~/.local/bin/adobe
```

## Development

```bash
tests/test.sh   # runs on macOS's own bash 3.2; every system command is replaced, so nothing is stopped
```

CI runs shellcheck, [zizmor](https://github.com/zizmorcore/zizmor) and the tests, and CodeQL checks
the workflows. Report security issues privately: see [SECURITY.md](SECURITY.md).

Not affiliated with or endorsed by Adobe. Adobe and Creative Cloud are trademarks of Adobe Inc.

## License

[MIT](LICENSE)
