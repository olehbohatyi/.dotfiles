# .dotfiles

My shell config for Bash, Zsh, PowerShell (Windows PowerShell 5.1 and
PowerShell 7+), and the Ammonite Scala REPL. One prompt shape and color
scheme across all of them, installed via [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html)
so everything is a symlink back into this repo, not a copy that drifts.

```
λ username: .dotfiles (main) ∫
```

Cyan `λ`, red username, yellow directory, blue git branch, green `∫`. Same
shape, same colors, in every shell. Running as root/Administrator swaps in a
plain red `user path #` instead, as a "be careful" cue.

## What's here

```
amm/.ammonite/    Ammonite REPL predef: helper.sc, import.sc, predef.sc
bash/             .bash_profile, .bashrc
zsh/              .zshrc
pwsh/             profile.ps1
git/              .aliases — git config fragment, included from ~/.gitconfig
cli/              .clirc — modern CLI tool integration, shared by bash+zsh
                  .ripgreprc — ripgrep colors (rg has no color env var)
claude/.claude/   settings.json — Claude Code settings + permission allowlist
install.sh        Stow-based installer: bash, zsh, amm, git, cli, claude (macOS/Linux)
install.ps1       Profile installer for pwsh/profile.ps1 (any OS)
```

See [CLAUDE.md](CLAUDE.md) for the conventions each of these follows and the
reasoning behind the layout.

## Installing

### A fresh machine

**macOS / Linux** (needs [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html)):

```bash
git clone git@github.com:olehbohatyi/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
brew install stow   # or: sudo apt install stow / sudo dnf install stow
./install.sh
```

This symlinks `bash/`, `zsh/`, `amm/`, `git/`, `cli/`, and `claude/` into
`$HOME` and registers `~/.aliases` in your `~/.gitconfig`. Install only a
subset with `./install.sh zsh git`.

**Windows / PowerShell** (any OS running pwsh):

```powershell
git clone https://github.com/olehbohatyi/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.ps1
```

Run it once per PowerShell edition you use (Windows PowerShell 5.1 and
PowerShell 7+ have separate profiles). Creating the symlink needs
Administrator rights or Developer Mode enabled; without either, the script
falls back to copying the file (see the script's `.NOTES` for details).

On a genuinely empty system there's nothing to conflict with, so this is
the entire install.

### A machine that already has dotfiles

Most real machines already have their own `~/.bashrc`, `~/.zshrc`,
`~/.gitconfig`, or PowerShell profile. Both installers handle this the same
way:

- **Default — backup, then stow.** Any real file (not already a symlink) at
  a target path is moved to `~/.dotfiles-backup/<timestamp>/` before this
  repo's version is symlinked in. Nothing is lost. Afterwards, open the
  backup next to the repo's file and hand-merge anything machine-specific
  (a corporate proxy variable, a local `PATH` tweak) into the repo, then
  re-run the installer.
- **`--adopt` (`./install.sh --adopt`) / `-Adopt` (`./install.ps1 -Adopt`)
  — keep what's already there instead.** Pulls the existing file's content
  *into the repo*, overwriting the repo's copy, then symlinks as normal.
  Use this when the machine's current config is what you actually want to
  keep long-term. Immediately run `git diff` in the repo and discard
  whatever you don't want before committing.

Either way, nothing is silently overwritten — you either get a timestamped
backup or an explicit `git diff` to review.

## Git aliases

`git/.aliases` — short names for staging (`aa`, `ap`), branches (`br`, `sw`),
fetch/push (`f`, `up`, `please`), stash (`ss`, `sl`, `sp`), rebase (`rbi`,
`rbc`, `rba`), log (`lg`, `ll`, `last`), and cleanup of merged branches
(`cleanup`). Full list is in the file itself — that's the source of truth,
not this README.

It's included via `include.path` rather than being a full `.gitconfig`, so
it never touches `user.name`/`user.email`/signing config. `install.sh`
registers the include automatically; without the installer, run:

```bash
git config --global include.path ~/.aliases
```

`cli/.clirc` also aliases the base command itself: `g` → `git`. It's a
separate mechanism (a shell alias, not a git alias) so the two combine —
`g aa`, `g st`, `g f` (fetch) all work.

## Claude Code settings

`claude/.claude/settings.json` — theme, the official plugin marketplace, and
a permission allowlist so read-only commands (`ls`, `cat`, `rg`, `fd`,
`git status`, `git diff`, `git log`, ...) run without a prompt every time.
Anything that can mutate state still asks.

Only `settings.json` is tracked. The rest of `~/.claude` — `sessions/`,
`cache/`, `telemetry/`, `projects/` (which holds full conversation
transcripts) — is machine-local runtime state and stays out of git. Both
`.gitignore` and `.stow-local-ignore` in this package ignore *everything*
and re-include just that one file, so a runtime directory Claude Code
invents later can't quietly start getting committed.

The allowlist names read-only git subcommands one by one instead of using
`Bash(git *)`, because permission rules match by prefix and `git *` would
also cover `git push` and `git reset --hard`.

## Modern CLI tools

`cli/.clirc` (sourced by both bash and zsh) auto-wires these in *if
installed* — nothing breaks if they're not, each one is behind a
`command -v` check. Install any of these however you like (`brew install
eza`, `apt install bat`, ...) and restart your shell — no repo changes
needed.

| Tool | Alias / integration in `.clirc` | Example commands |
|---|---|---|
| [`bat`](https://github.com/sharkdp/bat) | `cat` / `c` → `bat` | `cat file.rs` / `c file.rs` — syntax-highlighted view (via the alias)<br>`bat -A file.txt` — show non-printable characters<br>`git diff \| bat` — colorized diff paging |
| [`eza`](https://github.com/eza-community/eza) | `ls` / `ll` / `la` / `lt` | `ls` — icons + colors (`eza --icons`)<br>`ll` — long listing with git status (`eza -la --icons --git`)<br>`lt` — 2-level tree view (`eza --tree --icons --level=2`) |
| [`fd`](https://github.com/sharkdp/fd) | `f` (normalized from `fdfind` on Debian/Ubuntu) | `f pattern` — find files/dirs matching pattern<br>`f -e md` — find by extension<br>`f -t d node_modules` — find directories only |
| [`ripgrep`](https://github.com/BurntSushi/ripgrep) | `r` → `rg` | `r "TODO"` — recursive search from here<br>`r -i "error" src/` — case-insensitive, scoped to a dir<br>`r -l "foo"` — list matching filenames only |
| [`zoxide`](https://github.com/ajeetdsouza/zoxide) | adds `z` | `z dotfiles` — jump to the best match for "dotfiles"<br>`z foo bar` — match on multiple terms<br>`z -` — jump back to the previous directory |

### One palette across all of them

Out of the box each of these tools picks its own colors, so a directory is
one shade in `ls` and a different one in `fd`. `.clirc` points all four at
the same five bright-ANSI slots the prompt uses:

| Slot | Color | In the prompt | In the tools |
|---|---|---|---|
| 9 | bright red | username | your username in `ll`, broken links, deleted files, the `rg` match |
| 10 | bright green | `∫` | executables, git-new |
| 11 | bright yellow | directory | directories, `rg` paths, git-modified |
| 12 | bright blue | git branch | dates, renames, device/special files |
| 14 | bright cyan | `λ` | symlinks, file sizes, `rg` line numbers |

They're palette *indices*, not fixed RGB, so they resolve against whatever
your terminal theme defines — switch terminal themes and the tools move with
the prompt instead of staying stuck on their own hardcoded colors.

How each tool gets there: `fd` reads `LS_COLORS`; `eza` layers `EZA_COLORS`
on top for its permission/size/date/git columns; `bat` uses the built-in
`ansi` theme (the only one that renders via the terminal's 16 colors rather
than hardcoded RGB); `rg` has no color env var at all, so it reads
`cli/.ripgreprc` via `RIPGREP_CONFIG_PATH`.

**macOS / Linux:** [Homebrew](https://brew.sh/).

**Windows:** [Windows Terminal](https://github.com/microsoft/terminal),
[`winget`](https://learn.microsoft.com/en-us/windows/package-manager/winget/) or
[Scoop](https://scoop.sh/), [`PSReadLine`](https://learn.microsoft.com/en-us/powershell/module/psreadline/)
(tab completion/history, ships with PowerShell 7+), [`gsudo`](https://github.com/gerardog/gsudo)
(a Windows `sudo`).

## Roadmap

- [ ] `shellcheck`/PSScriptAnalyzer wired into CI

---

MIT licensed, see [LICENSE](LICENSE).
