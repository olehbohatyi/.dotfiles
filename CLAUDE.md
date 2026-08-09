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
                  .ripgreprc — rg colors, loaded via RIPGREP_CONFIG_PATH
claude/.claude/   settings.json — Claude Code config (see below)
install.sh        Stow installer: bash/zsh/amm/git/cli/claude (macOS/Linux)
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

Cyan `λ`, red user, yellow dir, blue git branch, green `∫`. As
root/Administrator it drops to the standard (non-bright) end of the same
palette and swaps the sigil, keeping the directory and git segment:

```
<user> <dir> (<git-branch>) #
```

dark-red user (`\e[0;31m` / `%F{1}` / `DarkRed`), grey dir (`\e[0;37m` /
`%F{7}` / `Gray`), dim git branch (`\e[0;90m` / `%F{8}` / `DarkGray`). Change
the design in
`bash/.bashrc`, `zsh/.zshrc`, `pwsh/profile.ps1` **and
`amm/.ammonite/predef.sc`** together — never just one. All four render the
full shape including the git segment. Ammonite gets there through fansi
(`LightCyan`/`LightRed`/`LightYellow`/`LightBlue`/`LightGreen`), which emits
the same bright codes but closes each span with `\e[39m` instead of leaving
the color sticky the way the bash/zsh strings do — same result on screen.

All four resolve the branch identically: `git rev-parse --abbrev-ref HEAD`,
falling back to `git rev-parse --short HEAD` when that returns the literal
`HEAD`, so a detached HEAD reads `(abc1234)` everywhere and a directory
outside any repo shows no segment at all. bash/zsh used to pipe `git branch`
through sed, which cost a second process, scaled with the branch count, and
printed `((HEAD detached at abc1234))` — don't reintroduce it.

The shells keep their own copy of `git_branch` rather than sharing one from
`cli/.clirc`, because that file is sourced conditionally (`[ -f ~/.clirc ]`)
and a machine without it would leave the prompt calling a function that
doesn't exist. The two copies must stay byte-identical; `test.sh` checks.

**Escapes must be marked zero-width.** bash wraps every sequence in
`\[ \]`, zsh in `%{ %}`. These tell readline/zle the bytes occupy no
columns; without them the shell counts all 46 escape bytes as printable and
believes an 80-column terminal has 1 usable column, which corrupts wrapping
on long lines and redraws during `Ctrl-R`. pwsh avoids the problem entirely
by writing the prompt with `Write-Host` rather than a string, and Ammonite
by letting fansi measure it. Any new colored prompt segment needs the
wrapper — it's invisible until a command gets long enough to wrap.

**zsh uses literal `\e[...m`, not `%F{n}`.** `%F` consults terminfo, so on a
TERM advertising only 8 colors (`xterm`, `linux`, `xterm-color`) every index
≥ 8 degrades to `\e[39m` — default foreground — and the prompt renders
colorless, while bash's hardcoded bytes stay colored. Verified across
`xterm-256color`/`xterm`/`screen`/`linux`/`dumb`: the literal form emits
identical bytes under all of them. The `$'...'` quoting expands `\e` once at
assignment while leaving `$(git_branch)` for `PROMPT_SUBST` to run per
redraw — don't switch it to double quotes, which would freeze the branch at
shell start.

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
  `helper.sc`/`import.sc` are opt-in via `$file`. Get a path segment with
  `os.Path.last`, **never `.baseName`** — os-lib strips what it reads as an
  extension, so `.dotfiles` (all "extension") returns `""` and blanks the
  prompt's directory, and `my.app` silently becomes `my`. `os.home.baseName`
  has the same failure on a `first.last`-style home directory. This is the
  exact trap described in the PowerShell bullet above; both languages have
  it, so check any new path-splitting code in either against a dotfile name.

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

## Unified tool colors

`.clirc` themes bat/eza/fd/rg onto the same five bright-ANSI slots as the
prompt (9 red, 10 green, 11 yellow, 12 blue, 14 cyan) — the palette table
lives in `.clirc` itself, above the exports. **These are palette indices,
never RGB or hex.** That's what makes the tools track the terminal theme the
same way `%F{11}` does; hardcoding `38;2;r;g;b` anywhere here would freeze
one tool against a moving background. The prompt palette and this table are
one design — change the prompt in `bash/.bashrc` + `zsh/.zshrc` +
`pwsh/profile.ps1` and update the `.clirc` table in the same commit.

Each tool needs a different mechanism, and only one of the four is a
straightforward env var:

- **fd** reads `LS_COLORS` (so does GNU `ls`; BSD `ls` on macOS wants
  `LSCOLORS`, a different format, and is left alone because `ls` is aliased
  to eza anyway).
- **eza** reads `LS_COLORS` as a base, then `EZA_COLORS` for the columns
  only it has. Watch out: `tw` exists in *both* with unrelated meanings —
  "other-writable dir" in `LS_COLORS`, "other-write permission bit" in
  `EZA_COLORS`.
- **bat** ignores env colors entirely; its themes carry hardcoded RGB. Only
  the `ansi` theme renders through the terminal's 16 colors — `base16` and
  `base16-256` are 256-color and will *not* follow the palette. Don't
  "upgrade" `BAT_THEME` to a prettier theme without accepting that it opts
  bat out of the shared palette.
- **rg** has no color env var at all, which is why `cli/.ripgreprc` exists.

## Scala tooling and the sun.misc.Unsafe warning

JDK 24+ implements JEP 498 and prints a four-line deprecation warning every
time `scala.runtime.LazyVals` touches `sun.misc.Unsafe` — which is every amm,
`scala` and sbt start. `.clirc` wraps those three commands to pass
`--sun-misc-unsafe-memory-access=allow`, which suppresses the notice without
changing behaviour (`deny` is the value that actually breaks the calls).

Three things about that block are load-bearing:

- **Never `export JAVA_OPTS` with this flag.** It exists only on JDK 24+; an
  older JVM exits with "Unrecognized option" rather than starting, so a
  global export would break *every* Java program on a machine pinned to
  JDK 21 — not just the Scala ones.
- **The probe is lazy and cached.** It runs `java --sun-misc-unsafe-memory-
  access=allow -version` the first time one of the wrappers is used, not at
  shell startup, because that costs ~90ms and would be paid by every new
  shell. It tests the flag rather than parsing a version number, so it stays
  correct across whatever JDK a project pins.
- **The tools disagree about how to take JVM flags.** amm and sbt read
  `JAVA_OPTS` (amm's launcher is literally `exec java $JAVA_OPTS`), but the
  `scala` launcher reads no environment variable at all and accepts only
  `-J<flag>` on the command line — verified against scala 3.3.7, where
  setting `JAVA_OPTS` changes nothing. Don't collapse the three wrappers
  into one shared mechanism.

`JDK_JAVA_OPTIONS` looks like a tidier single answer and isn't: the JVM
announces it with its own `NOTE: Picked up JDK_JAVA_OPTIONS` line, trading
four lines of noise for one. sbt also reads the flag from a checked-in
`.sbtopts`/`.jvmopts` as `-J--sun-misc-unsafe-memory-access=allow`, which is
the right place for it when a build must not depend on the shell.

`RIPGREP_CONFIG_PATH` is the one export that's guarded on the file existing.
rg treats a missing config path as a hard error and prints `failed to read
the file specified in RIPGREP_CONFIG_PATH` on *every* invocation instead of
searching — so an unguarded export would break `rg` on any machine that
hasn't stowed `cli` yet. That's the same "never break a fresh clone's shell"
rule the `command -v` guards follow; keep the `[ -f ]` test.

## claude/ — Claude Code settings

Only `settings.json` is tracked. Everything else Claude Code puts in
`~/.claude` (`sessions/`, `cache/`, `telemetry/`, `projects/`, `backups/`,
`shell-snapshots/`, ...) is machine-local runtime state, and `projects/`
holds full conversation transcripts — none of it belongs in git.

**`install.sh` must `mkdir -p ~/.claude` before stowing this package.** Stow
only folds into a target directory that already exists; on a fresh machine
where `~/.claude` is absent it symlinks the *whole directory* into the repo,
and every subsequent session then writes its transcripts into git. Verified
both ways against a scratch `$HOME` — don't remove that guard.

`amm` needs the identical guard on `~/.ammonite` and gets it from the same
`case` block in `install.sh`. Ammonite fills that directory with `history`,
`cache/`, `.scala-build/` and per-JDK `rt-*.jar` files that run to hundreds
of megabytes, so a missed fold there doesn't just leak state — it commits
JARs. Any future package whose target directory is *also* the tool's runtime
directory belongs in that block too.

Both `.gitignore` and `.stow-local-ignore` here are **allowlists** — ignore
everything, then re-include only `settings.json` (plus the two ignore files
themselves, for git). Don't convert either back into a list of runtime
directory names: a denylist goes stale the moment Claude Code writes
somewhere new, and the thing leaking would be conversation transcripts.
`settings.local.json`, Claude Code's machine-local override file, is covered
by the same blanket rule rather than being named.

Two things that make the allowlists work, both verified against a scratch
`$HOME` and with `git check-ignore -v`:

- git won't descend into an excluded directory, so `.claude/` has to be
  un-ignored on its own line before `!.claude/settings.json` can match.
- Stow's ignore patterns are Perl regexes, so the negative lookahead
  `^/\.claude/(?!settings\.json$).*` is valid. It only covers paths *under*
  `.claude/`, so the standard default patterns above it are still load-
  bearing — without them a stray `claude/.DS_Store` gets symlinked into
  `$HOME`.

Permission rules use prefix-wildcard matching, so `Bash(git *)` would also
match `git push` and `git reset --hard`. The allowlist therefore names
read-only subcommands individually (`Bash(git log *)`, `Bash(git status)`)
rather than wildcarding the whole command — keep it that way when adding
entries.

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
./test.sh
```

Runs the syntax checks for all three shells plus a regression test for every
bug that has actually bitten this repo: prompt colour parity between bash and
zsh, escapes wrapped zero-width, no `%F{n}`, TERM-independence, `git_branch`
not drifting between its two copies, the `.baseName`/`.BaseName` traps, ignore
files not drifting, and the installer against a scratch `$HOME`. It writes
only inside `mktemp -d`, needs no network, and skips optional tools (zsh,
pwsh) rather than failing when they're absent.

**Add a case to `test.sh` for any bug you fix here.** Every check in it
exists because something broke first, which is what makes it worth running.
Confirm a new check actually fails against the unfixed code before trusting
it — three of the original checks passed for the wrong reason (they were
matching the explanatory comments rather than the code), and only a
deliberate mutation caught that.

The individual commands, if you want to run one directly:

```bash
bash -n bash/.bashrc bash/.bash_profile cli/.clirc install.sh test.sh
zsh -n zsh/.zshrc cli/.clirc
```

```bash
pwsh -NoProfile -Command '$e=$null;$t=$null
[System.Management.Automation.Language.Parser]::ParseFile("pwsh/profile.ps1",[ref]$t,[ref]$e) | Out-Null
if ($e.Count -eq 0) { "OK" } else { $e }'
```

Prefer dry-running the installers against a scratch `$HOME` over running
them for real, e.g. `HOME=/tmp/fake-home ./install.sh`. That's how a stray
`.DS_Store` getting symlinked, and a `--adopt` run overwriting the wrong
file, were both caught before they hit a real machine.
