define-command copy-file-path %{
    evaluate-commands -save-regs '"' %sh{
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "$kak_buffile" | pbcopy
        else
            echo "$kak_buffile" | xclip -selection clipboard
        fi
    }
    echo -markup "{info}File path copied to clipboard."
}

define-command copy-file-name %{
    evaluate-commands -save-regs '"' %sh{
        filename=$(basename "$kak_buffile")
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "$filename" | pbcopy
        else
            echo "$filename" | xclip -selection clipboard
        fi
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

        diff -u -L 'a' -L 'b' "$tmp_a" "$tmp_b" >"$tmp_out"
        status=$?
        if [ "$status" -gt 1 ]; then
            rm -f "$tmp_a" "$tmp_b" "$tmp_out"
            printf "fail 'diff failed'\n"
            exit 1
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

declare-user-mode yank
map global user -docstring 'yank mode' y ':enter-user-mode yank<ret>'
map global yank -docstring 'current file path' p ':copy-file-path<ret>'
map global yank -docstring 'current file name' f ':copy-file-name<ret>'
map global yank -docstring 'diff registers a and b' d ':yank-diff-registers<ret>'
