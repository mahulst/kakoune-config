declare-option -hidden str grep_selection_text
declare-option -hidden str grep_buffile_ext

define-command grep-smart -docstring 'grep selection if selected, otherwise prompt for pattern. results shown in toolsclient' %~
    set-option window grep_selection_text %sh{
        if [ ${#kak_selection} -gt 1 ]; then
            printf '%s' "$kak_selection"
        fi
    }
    evaluate-commands %sh{
        if [ -n "$kak_opt_grep_selection_text" ]; then
            printf "grep\n"
        else
            printf "grep-smart-prompt\n"
        fi
    }
~

define-command -hidden grep-smart-prompt %{
    prompt 'grep: ' %{ grep %val{text} }
}

define-command grep-smart-filetype -docstring 'grep selection (or prompt) in files with same extension as current buffer. results shown in toolsclient' %~
    set-option window grep_selection_text %sh{
        if [ ${#kak_selection} -gt 1 ]; then
            printf '%s' "$kak_selection"
        fi
    }
    set-option window grep_buffile_ext %sh{
        printf '%s' "${kak_buffile##*.}"
    }
    evaluate-commands %sh{
        ext="${kak_buffile##*.}"
        if [ -n "$kak_opt_grep_selection_text" ]; then
            printf "grep -F -g '*.%s' '%s'\n" "$ext" "$kak_opt_grep_selection_text"
        else
            printf "grep-smart-filetype-prompt\n"
        fi
    }
~

define-command -hidden grep-smart-filetype-prompt %{
    prompt "grep (*.%opt{grep_buffile_ext}): " %{ grep -g "*.%opt{grep_buffile_ext}" %val{text} }
}
