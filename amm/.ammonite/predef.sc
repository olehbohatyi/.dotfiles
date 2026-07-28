import fansi.Attrs.*, fansi.Color.*, $file.helper, $file.`import`, helper.*, `import`.*

interp.colors().prompt() = Empty

// `.last`, never `.baseName`: os-lib's baseName strips what it considers an
// extension, so a dotfile-style name like `.dotfiles` is read as *all*
// extension and comes back "" (an empty path segment in the prompt), and
// `my.app` silently truncates to `my`. Same trap as .NET's BaseName — see
// the PowerShell note in CLAUDE.md. `.last` returns the segment verbatim.
private val user = os.home.last

private def path = os.pwd match
  case some if some == os.home => "~"
  case some if some == os.root => some.toString
  case some                    => some.last


// The same git segment bash/.bashrc, zsh/.zshrc and pwsh/profile.ps1 show:
// bright blue " (branch)" right after the directory, and nothing at all
// outside a repo. Carries its own leading space so the space disappears
// along with the branch, exactly like `$(git_branch)` does in the shells.
// Detached HEAD falls back to the short SHA, matching profile.ps1.
//
// A prompt must never fail to render, so both failure modes are handled:
// check = false keeps a non-repo directory (or a repo with no commits yet)
// from throwing on a nonzero exit, and the try/catch covers git being
// missing from PATH entirely, which makes os.proc throw before it even runs.
// stderr is piped rather than inherited so git's "not a git repository"
// never leaks into the REPL.
private def gitBranch: String =
  try
    def git(args: String*): String =
      val r = os.proc("git", args).call(cwd = os.pwd, check = false, stderr = os.Pipe)
      if r.exitCode == 0 then r.out.text().trim else ""
    git("rev-parse", "--abbrev-ref", "HEAD") match
      case ""     => ""
      case "HEAD" => git("rev-parse", "--short", "HEAD") match
        case ""  => ""
        case sha => s" ($sha)"
      case b      => s" ($b)"
  catch case _: Throwable => ""

private def prompt =
  s"${LightCyan("λ")} ${LightRed(user)}${LightCyan(":")} ${LightYellow(path)}${LightBlue(gitBranch)} ${LightGreen("∫")} "

repl.prompt.bind(prompt)
