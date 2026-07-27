# CLAUDE.md

Guidance for agents/contributors working in this repo.

## What this is

Personal dotfiles: shell/REPL config for Bash, Zsh, PowerShell, and
Ammonite, installed as symlinks via GNU Stow. No application code — only
startup scripts and install tooling.

## Layout

```
amm/.ammonite/    Ammonite predef: helper.sc, import.sc, predef.sc
bash/             .bash_profile, .bashrc
zsh/              .zshrc
pwsh/             profile.ps1 (not stowed — see below)
git/              .aliases — included from ~/.gitconfig via include.path
cli/              .clirc — modern CLI tool integration, sourced by bash+zsh
install.sh        Stow installer: bash/zsh/amm/git/cli (macOS/Linux)
install.ps1       Profile installer for pwsh/profile.ps1 (any OS)
```

Each package directory except `git/` mirrors `$HOME` exactly — `stow bash`
links `bash/.bashrc` → `~/.bashrc`. Don't add a file to a package unless it
belongs at that identical path under `$HOME`.

`pwsh/` isn't stowed: `$PROFILE.CurrentUserAllHosts` resolves to a
different path per PS edition/OS, so it needs runtime resolution, not a
static symlink target — `install.ps1` handles it. Never hardcode a profile
path; PowerShell's own `$PROFILE` already accounts for edition/OS and
Documents-folder redirection.

`git/.aliases` is an include fragment (`git config --global include.path
~/.aliases`), not a full `.gitconfig` — never let it own
`user.name`/`user.email`/signing config.

## The shared prompt

Same shape and colors in every shell:

```
λ <user>: <dir> (<git-branch>) ∫
```

Cyan `λ`, red user, yellow dir, blue git branch, green `∫`; a plain dim-red
`<user> <path> #` as root/Administrator. Change the design in
`bash/.bashrc`, `zsh/.zshrc`, and `pwsh/profile.ps1` together — never just
one (Ammonite's `helper.sc` follows the same palette minus the path
segment).

**Color mapping** (pwsh shipped the wrong shade here twice — check this
when touching any prompt color): bash's bright codes (`\e[0;9Xm`) and zsh's
`%F{8-15}` map to PowerShell's plain color names (`Red`, `Green`, `Yellow`,
`Blue`, `Cyan`) — not `Dark*`. Standard/dim ANSI (`\e[0;3Xm` / `%F{0-7}`)
maps to `Dark*`. Git branch is bright blue everywhere: `\e[0;94m` / `%F{12}`
/ `Blue`.

## Per-language conventions

- **PowerShell**: follow https://learn.microsoft.com/en-us/powershell/.
  Comment-based help on any parameterized script. Full cmdlet names, not
  aliases. No Windows-only env vars (`$env:USERPROFILE`, `$env:USERNAME`)
  — gate on `$IsWindows` (absent in 5.1, which is always Windows). Get a
  path's leaf with `Split-Path -Leaf`, not `(Get-Item $x).BaseName` —
  `BaseName` strips what .NET treats as an "extension," which for a
  dotfile-style name like `.dotfiles` is the entire name, leaving `""`.
- **Zsh**: zsh-native (`%n`/`%~`/`%F{n}`, `setopt PROMPT_SUBST`, `[[ ]]`),
  not bash-isms. https://www.bash2zsh.com/zsh_refcard/refcard.pdf
- **Bash**: portable, quoted, `[ ]`/`[[ ]]`.
  https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html
  `.bash_profile` only sources `.bashrc` — all logic lives in `.bashrc`
  (login shells don't read `.bashrc` on their own; see below).
- **Ammonite**: idiomatic Scala, https://ammonite.io/#Ammonite-REPL.
  `predef.sc` runs on every REPL start — keep it fast/side-effect-light.
  `helper.sc`/`import.sc` are opt-in via `$file`.

## bash_profile vs bashrc

Login shells (Terminal.app, TTY, `bash -l`) read `.bash_profile`, not
`.bashrc`; non-login interactive shells read only `.bashrc`.
`.bash_profile` sources `.bashrc` so both get the same prompt/functions.
Keep all logic in `.bashrc`.

## cli/.clirc — modern CLI tooling

Sourced from both `bash/.bashrc` and `zsh/.zshrc` (guarded by `[ -f
~/.clirc ]`, since not every machine has run the installer yet). Wires in
bat/eza/fd/rg/zoxide as aliases or `eval`'d shell-init output, plus
single-letter shortcuts for the base commands themselves: `g`/`c`/`f`/`r`
for git/bat/fd/rg. Every block is gated on `command -v <tool>` so a machine
missing any of them just skips that line instead of breaking the shell —
this file should never be the reason a fresh clone's shell fails to start.

The `g` alias is a plain shell alias for `git`, distinct from `git/.aliases`
(those are `git <alias>` subcommands) — they combine, e.g. `g aa`.

Debian/Ubuntu package `bat` and `fd` under different binary names
(`batcat`, `fdfind`) to avoid clashing with unrelated existing packages.
`.clirc` checks both names; if you add a new tool here, check whether it
has the same problem before assuming the binary name matches the package
name.

zoxide needs to know which shell it's initializing for (`zoxide init bash`
vs `zoxide init zsh`). Since this file is shared, it branches on
`$ZSH_VERSION`/`$BASH_VERSION` once at the top rather than duplicating the
file per shell.

## Stow mirrors the filesystem, not git

Stow symlinks whatever's physically on disk, ignoring `.gitignore`. Every
package has a `.stow-local-ignore` so macOS's `.DS_Store` (regenerated any
time Finder opens the folder) never gets symlinked into `$HOME`. A
package-local `.stow-local-ignore` *replaces* Stow's default ignore list
rather than extending it, so every package repeats the full pattern set —
don't trim any of them down to "just the new pattern."

## Merging into a machine that already has dotfiles

Both installers offer two modes:
1. **Backup then stow (default)** — moves any real file at the target path
   to `~/.dotfiles-backup/<timestamp>/`, then symlinks. Hand-merge anything
   machine-specific afterward.
2. **`--adopt` / `-Adopt`** — pulls the existing file's content into the
   repo instead, overwriting the repo's copy. Review with `git diff` before
   committing.

Never hand-copy a live `.bashrc`/`.zshrc` over the repo's version outside
one of these flows — it silently drops whichever side didn't win.

## Testing changes

```bash
bash -n bash/.bashrc bash/.bash_profile cli/.clirc install.sh
zsh -n zsh/.zshrc cli/.clirc
```

`pwsh` is available locally — use it rather than skipping PowerShell
checks:
```bash
pwsh -NoProfile -Command '$e=$null;$t=$null
[System.Management.Automation.Language.Parser]::ParseFile("pwsh/profile.ps1",[ref]$t,[ref]$e) | Out-Null
if ($e.Count -eq 0) { "OK" } else { $e }'
```

Prefer dry-running the installers against a scratch `$HOME` over running
them for real, e.g. `HOME=/tmp/fake-home ./install.sh`. That's how a stray
`.DS_Store` getting symlinked, and a `--adopt` run overwriting the wrong
file, were both caught before they hit a real machine.
