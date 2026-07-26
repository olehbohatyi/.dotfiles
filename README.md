# .dotfiles

My shell config for Bash, Zsh, PowerShell (Windows PowerShell 5.1 and
PowerShell 7+), and the Ammonite Scala REPL. One prompt shape and color
scheme across all of them, installed via [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html)
so everything is a symlink back into this repo, not a copy that drifts.

```
λ username: .dotfiles (main) ∫
```

Cyan `λ`, red username, yellow directory, dim git branch, green `∫`. Same
shape, same colors, in every shell. Running as root/Administrator swaps in a
plain red `user path #` instead, as a "be careful" cue.

## What's here

```
amm/.ammonite/    Ammonite REPL predef: helper.sc, import.sc, predef.sc
bash/             .bash_profile, .bashrc
zsh/              .zshrc
pwsh/             profile.ps1
git/              .aliases — git aliases, included from ~/.gitconfig
install.sh        Stow-based installer: bash, zsh, amm, git (macOS/Linux)
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

This symlinks `bash/`, `zsh/`, `amm/`, and `git/` into `$HOME` and registers
`~/.aliases` in your `~/.gitconfig`. Install only a subset with
`./install.sh zsh git`.

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

## Suggested companion tools

Not installed by this repo, but pair well with it:

**Cross-platform:** [`ripgrep`](https://github.com/BurntSushi/ripgrep) (`rg`),
[`fzf`](https://github.com/junegunn/fzf), [`bat`](https://github.com/sharkdp/bat),
[`fd`](https://github.com/sharkdp/fd), [`zoxide`](https://github.com/ajeetdsouza/zoxide),
[`direnv`](https://direnv.net/), [Neovim](https://neovim.io/).

**macOS / Linux:** [Homebrew](https://brew.sh/), [`eza`](https://github.com/eza-community/eza)
(a maintained `ls` replacement), [`tmux`](https://github.com/tmux/tmux), `htop`/`btop`.

**Windows:** [Windows Terminal](https://github.com/microsoft/terminal),
[`winget`](https://learn.microsoft.com/en-us/windows/package-manager/winget/) or
[Scoop](https://scoop.sh/), [`PSReadLine`](https://learn.microsoft.com/en-us/powershell/module/psreadline/)
(tab completion/history, ships with PowerShell 7+), [`gsudo`](https://github.com/gerardog/gsudo)
(a Windows `sudo`).

## Roadmap

- [ ] Editor config (Neovim/VS Code settings) as its own Stow package
- [ ] `shellcheck`/PSScriptAnalyzer wired into CI

---

MIT licensed, see [LICENSE](LICENSE).
