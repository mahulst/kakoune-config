declare-option -hidden str grep_selection_text
declare-option -hidden str grep_buffile_ext
declare-option -hidden str grep_package_dir

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

define-command grep-smart-package -docstring 'grep selection (or prompt) scoped to the closest package.json directory. results shown in toolsclient' %~
    set-option window grep_selection_text %sh{
        if [ ${#kak_selection} -gt 1 ]; then
            printf '%s' "$kak_selection"
        fi
    }
    set-option window grep_package_dir %sh{
        dir="${kak_buffile%/*}"
        while [ -n "$dir" ] && [ "$dir" != "/" ]; do
            if [ -f "$dir/package.json" ]; then
                printf '%s' "$dir"
                exit
            fi
            dir="${dir%/*}"
        done
    }
    evaluate-commands %sh{
        if [ -z "$kak_opt_grep_package_dir" ]; then
            printf "fail 'no package.json found'\n"
        elif [ -n "$kak_opt_grep_selection_text" ]; then
            printf "grep -F '%s' '%s'\n" "$kak_opt_grep_selection_text" "$kak_opt_grep_package_dir"
        else
            printf "grep-smart-package-prompt\n"
        fi
    }
~

define-command -hidden grep-smart-package-prompt %{
    prompt "grep (%opt{grep_package_dir}): " %{ grep %val{text} %opt{grep_package_dir} }
}
