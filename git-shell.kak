# Git wrapper that outputs stderr and stdout to the *git-shell* buffer.
provide-module git-shell %{
  # Options
  declare-option str git_bin "git --no-optional-locks"

  # Commands

  ## Wrapper shell command which prints the command at the bottom of the buffer, and its output (both stdout
  ## and stderr).
  define-command -override -hidden git-shell -params .. %{
    evaluate-commands -draft %{
      edit -scratch '*git-shell*'
      try %{
        add-highlighter buffer/ ref git-shell
      }

      execute-keys "geogit %arg{@}<ret><esc>"
      execute-keys "|%opt{git_bin} %arg{@} 2>&1<ret>o"
    }
  }

  # Highlighters
  set-face global GitShell black
  add-highlighter shared/git-shell regex '^(git [^\n]+)$' 1:GitShell
}
