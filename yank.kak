define-command copy-file-path %{
    evaluate-commands -save-regs '"' %sh{
        printf '%s' "$kak_buffile" | eval "$kak_opt_extra_yank_system_clipboard_cmd"
    }
    echo -markup "{info}File path copied to clipboard."
}

define-command copy-file-name %{
    evaluate-commands -save-regs '"' %sh{
        filename=$(basename "$kak_buffile")
        printf '%s' "$filename" | eval "$kak_opt_extra_yank_system_clipboard_cmd"
    }
    echo -markup "{info}File name copied to clipboard."
}

define-command yank-diff-registers -docstring 'open diff for registers a and b' %{
    evaluate-commands %sh{
        tmp_a=$(mktemp "${TMPDIR:-/tmp}/kak-diff-a.XXXXXX")
        tmp_b=$(mktemp "${TMPDIR:-/tmp}/kak-diff-b.XXXXXX")
        tmp_out=$(mktemp "${TMPDIR:-/tmp}/kak-diff-out.XXXXXX")

        printf '%s' "${kak_main_reg_a-}" >"$tmp_a"
        printf '%s' "${kak_main_reg_b-}" >"$tmp_b"

        diff -u -U 1000000 -L 'a' -L 'b' "$tmp_a" "$tmp_b" >"$tmp_out"
        status=$?
        if [ "$status" -gt 1 ]; then
            rm -f "$tmp_a" "$tmp_b" "$tmp_out"
            printf "fail 'diff failed'\n"
            exit 1
        fi
        if [ "$status" -eq 0 ]; then
            printf 'no diff found\n' >"$tmp_out"
        fi

        cat <<EOF
try %{ delete-buffer *diff* }
edit -scratch *diff*
set-option buffer filetype diff
evaluate-commands -save-regs '"' -buffer *diff* %{
    set-register dquote %file{$tmp_out}
    execute-keys 'i<c-r>"<esc>'
}
nop %sh{ rm -f '$tmp_a' '$tmp_b' '$tmp_out' }
EOF
    }
}

define-command yank-diff-selection-clipboard -docstring 'open diff for selection and clipboard' %{
    evaluate-commands -save-regs z %{
        execute-keys -draft '"zy'
        evaluate-commands %sh{
            tmp_a=$(mktemp "${TMPDIR:-/tmp}/kak-diff-a.XXXXXX")
            tmp_b=$(mktemp "${TMPDIR:-/tmp}/kak-diff-b.XXXXXX")
            tmp_out=$(mktemp "${TMPDIR:-/tmp}/kak-diff-out.XXXXXX")

            printf '%s' "${kak_main_reg_z-}" >"$tmp_a"

            if [ -n "${kak_opt_kakboard_paste_cmd-}" ]; then
                eval "$kak_opt_kakboard_paste_cmd" >"$tmp_b"
            elif [ -n "${kak_opt_extra_paste_system_clipboard_cmd-}" ]; then
                eval "$kak_opt_extra_paste_system_clipboard_cmd" >"$tmp_b"
            else
                rm -f "$tmp_a" "$tmp_b" "$tmp_out"
                printf "fail 'no clipboard paste command configured'\n"
                exit 1
            fi

            diff -u -U 1000000 -L 'selection' -L 'clipboard' "$tmp_a" "$tmp_b" >"$tmp_out"
            status=$?
            if [ "$status" -gt 1 ]; then
                rm -f "$tmp_a" "$tmp_b" "$tmp_out"
                printf "fail 'diff failed'\n"
                exit 1
            fi
            if [ "$status" -eq 0 ]; then
                printf 'no diff found\n' >"$tmp_out"
            fi

            cat <<EOF
try %{ delete-buffer *diff* }
edit -scratch *diff*
set-option buffer filetype diff
evaluate-commands -save-regs '"' -buffer *diff* %{
    set-register dquote %file{$tmp_out}
    execute-keys 'i<c-r>"<esc>'
}
nop %sh{ rm -f '$tmp_a' '$tmp_b' '$tmp_out' }
EOF
        }
    }
}

define-command copy-branch-name %{
    evaluate-commands -save-regs '"' %sh{
        branch=$(cd "$(dirname "$kak_buffile")" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [ -z "$branch" ]; then
            echo "fail 'not in a git repository'"
        else
            if [[ "$OSTYPE" == "darwin"* ]]; then
                printf '%s' "$branch" | pbcopy
            else
                printf '%s' "$branch" | xclip -selection clipboard
            fi
            echo "echo -markup '{info}Branch name copied to clipboard: $branch'"
        fi
    }
}

declare-user-mode yank
map global user -docstring 'yank mode' y ':enter-user-mode yank<ret>'
map global yank -docstring 'current file path' p ':copy-file-path<ret>'
map global yank -docstring 'current file name' f ':copy-file-name<ret>'
map global yank -docstring 'current git branch name' b ':copy-branch-name<ret>'
map global yank -docstring 'diff registers a and b' d ':yank-diff-registers<ret>'
map global yank -docstring 'diff selection and clipboard' c ':yank-diff-selection-clipboard<ret>'
