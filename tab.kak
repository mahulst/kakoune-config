# Spaces only, never tabs. Originally based on andreyorst/smarttab.kak,
# which also supported tab-based indent modes (noexpandtab/smarttab); those
# were removed so there is no code path left that can turn on tabs.

set-option global tabstop 4
set-option global indentwidth 4
set-option global aligntab false

define-command -override -hidden expandtab %{
    remove-hooks buffer expandtab-mode
    hook -group expandtab-mode buffer InsertChar '\t' %{ execute-keys -draft "h%opt{indentwidth}@" }
}

define-command -override -hidden update-tab-width -docstring "infers the indent width from the buffer's contents" %{
  try %{
    evaluate-commands -draft %{
      # find first run of spaces in a line
      execute-keys 'gk/^ +<ret>'

      set-option buffer tabstop %val{selection_length}
      set-option buffer indentwidth %val{selection_length}
    }
  } catch %{
    echo -debug "failed to infer tab width for buffer=%val{buffer}"
  }
}

# Re-sourcing this file (e.g. reloading the config live) would otherwise
# register every hook below a second time, so drop any prior copies first.
try %{ remove-hooks global tab-hooks }

hook -group tab-hooks global BufOpenFile .* expandtab
hook -group tab-hooks global BufNewFile  .* expandtab
hook -group tab-hooks global BufOpenFile .* update-tab-width
hook -group tab-hooks global BufWritePost .* update-tab-width

# Safety net: convert any tab that slips in some other way (paste, LSP edit,
# formatter output, ...) to spaces before the file is written, so tabs never
# actually hit disk. Makefiles are exempt since Make requires literal tabs
# for recipe lines.
hook -group tab-hooks global BufWritePre .* %{ evaluate-commands %sh{
    if [ "$kak_opt_filetype" != "makefile" ]; then
        printf "%s\n" "try %{ execute-keys -draft '%s\\t<ret>c    <esc>' }"
    fi
}}
