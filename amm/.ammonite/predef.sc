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


private def prompt =
  s"${LightCyan("λ")} ${LightRed(user)}${LightCyan(":")} ${LightYellow(path)} ${LightGreen("∫")} "

repl.prompt.bind(prompt)
