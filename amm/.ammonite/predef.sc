import fansi.Attrs.*, fansi.Color.*, $file.helper, helper.*

interp.colors().prompt() = Empty

private val user = os.home.baseName

private def path = os.pwd match
  case some if some == os.home => "~"
  case some if some == os.root => some.toString
  case some                    => some.baseName


private def prompt =
  s"${LightCyan("λ")} ${LightRed(user)}${LightCyan(":")} ${LightYellow(path)} ${LightGreen("∫")} "

repl.prompt.bind(prompt)
