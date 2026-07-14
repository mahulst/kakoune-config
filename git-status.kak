# A porcelain git status.
provide-module git-status %{
  require-module git-shell
  require-module git-commit2

  # Commands.
  define-command git-status %{
    edit -scratch '*git-status*'
    set-option buffer filetype git-porcelain-status

    git-status-refresh
    git-status-help
  }

  # Refresh.
  define-command git-status-refresh %{
    set-option buffer readonly false
    execute-keys -draft "%%|git status --porcelain --no-renames<ret>"
    set-option buffer readonly true
  }

  # Go to the file under primary cursor.
  define-command git-status-gf %{
    execute-keys -with-hooks ',gl<a-/>^([^ ]| [^ ])<ret><a-e>_gf'
  }

  # Show the diff for the given file.
  define-command git-status-diff -params .. %{
    evaluate-commands %{
      execute-keys ",gl<a-/>^([^ ]| [^ ])<ret><a-e>_:git diff %arg{@} <c-r>.<ret>"
    }
  }

  # Toggle showing inline diff.
  define-command git-status-inline-diff-toggle -params .. %{
    set-option buffer readonly false

    evaluate-commands -draft %{
      try %{
        execute-keys -draft 'ghjL_'
        git-status-inline-diff-show %arg{@}
      } catch %{
        git-status-inline-diff-hide
      }
    }

    set-option buffer readonly true
  }

  # Show the inline diff for the given file.
  define-command -hidden git-status-inline-diff-show -params .. %{
    evaluate-commands -draft -save-regs ab %{
      execute-keys ',gh"byll<a-e>_"ayo<esc>'
      try %{
        evaluate-commands "git-status-inline-diff-show-%reg{b} %arg{@}"
      } catch %{
        # non-cached
        git-status-inline-diff-show- --cached %arg{@}
      }
    }
  }

  define-command -hidden git-status-inline-diff-show- -params .. %{
    execute-keys "|git diff %arg{@} <c-r>a<ret>_>"
  }

  # Show the inline diff for the given file.
  define-command -hidden git-status-inline-diff-hide %{
    execute-keys -draft 'gl<a-/>^([^ ]| [^ ])<ret>jgh<a-i>id'
  }

  # Stage files.
  define-command git-status-stage %{
    evaluate-commands -draft %{
      execute-keys '<a-s>gl<a-/>^([^ ]| [^ ])<ret>f l<a-e>'
      execute-keys -itersel ':git-shell add <c-r>.<ret>'
      git-status-refresh
    }
  }

  # Unstage files.
  define-command git-status-unstage %{
    evaluate-commands -draft %{
      execute-keys '<a-s>ghf l<a-e>'
      execute-keys -itersel ':git-shell reset <c-r>.<ret>'
      git-status-refresh
    }
  }

  # Restore file.
  define-command git-status-restore %{
    evaluate-commands -draft %{
      execute-keys '<a-s>ghf l<a-e>'
      execute-keys -itersel ':git-shell checkout <c-r>.<ret>'
      git-status-refresh
    }
  }

  # Help.
  define-command -hidden git-status-help %{
    info -title "git-status bindings" "<ret>: open file under cursor
<tab>: toggle inline diff

d:     diff file
D:     diff staged

s:     stage file(s)
S:     unstage file(s)
Z:     restore (discard) file(s)

C:     commit mode
?:     show this help"
  }

  add-highlighter shared/git-porcelain-status group
  add-highlighter shared/git-porcelain-status/unknown regex '^(\?\?)' 1:yellow
  add-highlighter shared/git-porcelain-status/staged-added regex '^(A|M|D|U)' 1:green
  add-highlighter shared/git-porcelain-status/staged-added-modified regex '^.(A|M|D|U)' 1:value
  add-highlighter shared/git-porcelain-status/diff-header-diff regex "^\s+(diff[^\n]+)" 1:default+b
  add-highlighter shared/git-porcelain-status/diff-header-index regex "^\s+(index)\s+([0-9a-f]+)..([0-9a-f]+)\s+([0-9]+)" 1:blue 2:value 3:magenta 4:comment
  add-highlighter shared/git-porcelain-status/diff-header-minus regex "^\s+(---[^\n]+)" 1:red
  add-highlighter shared/git-porcelain-status/diff-header-plus regex "^\s+(\+\+\+[^\n]+)" 1:green
  add-highlighter shared/git-porcelain-status/diff-header-at regex "^\s+(@@[^@]+@@)" 1:cyan
  add-highlighter shared/git-porcelain-status/diff-delta-minus regex "^\s+(-[^\n]*)" 1:red
  add-highlighter shared/git-porcelain-status/diff-delta-plus regex "^\s+(\+[^\n]*)" 1:green

  # Hooks.
  hook -group git-status global BufSetOption filetype=git-porcelain-status %{
    add-highlighter buffer/git-porcelain-status ref git-porcelain-status

    map buffer normal C       ':enter-user-mode git-commit2<ret>'
    map buffer normal d       ':git-status-diff<ret>'
    map buffer normal D       ':git-status-diff --staged<ret>'
    map buffer normal s       ':git-status-stage<ret>'
    map buffer normal S       ':git-status-unstage<ret>'
    map buffer normal Z       ':git-status-restore<ret>'
    map buffer normal <ret>   ':git-status-gf<ret>'
    map buffer normal <tab>   ':git-status-inline-diff-toggle<ret>'
    map buffer normal '?'     ':git-status-help<ret>'
  }
}
