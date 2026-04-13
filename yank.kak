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

declare-user-mode yank
map global user -docstring 'yank mode' y ':enter-user-mode yank<ret>'
map global yank -docstring 'current file path' p ':copy-file-path<ret>'
map global yank -docstring 'current file name' f ':copy-file-name<ret>'

