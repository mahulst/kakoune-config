# declare-option str git_branch_name
# declare-option str awk_cmd 'awk'
declare-user-mode git

map global git <ret> ':git blame-jump<ret>' -docstring 'open last commit that touched current line'
map global git n ':git next-hunk<ret>' -docstring 'goto next hunk'
map global git p ':git prev-hunk<ret>' -docstring 'goto previous hunk'

# Main hook (git branch update, gutters)
hook global -group git-main-hook NormalIdle .* %{
  # Update git diff column signs
  try %{ git update-diff }
   # Update branch name
}

# enable flag-lines hl for git diff
hook global WinCreate .* %{
    add-highlighter window/git-diff flag-lines Default git_diff_flags
}
# trigger update diff if inside git dir
hook global BufOpenFile .* %{
    evaluate-commands -draft %sh{
        cd $(dirname "$kak_buffile")
        if [ $(git rev-parse --git-dir 2>/dev/null) ]; then
            for hook in WinCreate BufReload BufWritePost; do
                printf "hook buffer -group git-update-diff %s .* 'git update-diff'\n" "$hook"
            done
        fi
    }
}
# ## Blame current line
set-face global GitBlameLineRef red,black
set-face global GitBlameLineSummary green,black
set-face global GitBlameLineAuthor blue,black
set-face global GitBlameLineTime default,black@comment

define-command git-blame-current-line %{
  info -markup -style above -anchor "%val{cursor_line}.%val{cursor_column}" -- %sh{git blame -L$kak_cursor_line,$kak_cursor_line $kak_bufname | sed -rn 's/^([^ ]+) \((.*) ([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]).*\).*$/{git_current_line_hash}\1 {git_current_line_author}\2 {git_current_line_date}\3/p'}
}

map global git b ':git blame<ret>' -docstring 'blame'
map global git s ':git status<ret>' -docstring 'status'
map global git d ':git diff<ret>' -docstring 'diff'
map global git c ':git-blame-current-line<ret>' -docstring 'blame current line'

define-command git-permalink -docstring "Yank GitHub permalink" %{
    evaluate-commands %sh{
        USER="$(git remote get-url origin | rg -or '$1' '^git@github.com:([^/]+).*$')"
        REPO="$(git remote get-url origin | rg -or '$1' '^git@github.com:[^/]+/(.*)\.git$')"
        BRANCH="$(git branch --show-current)"
        FILE="$kak_bufname"
        START="$(echo "$kak_selections_char_desc" | cut -d, -f1 | cut -d. -f1)"
        END="$(echo "$kak_selections_char_desc" | cut -d, -f2 | cut -d. -f1)"
        URL="https://github.com/$USER/$REPO/blob/$BRANCH/$FILE?plain=1#L$START-L$END"
        echo "set-register '\"' $URL"
    }
}   
map global git y ":git-permalink<ret>" -docstring "󰿨  Yank permalink"

define-command git-open -docstring "Open github link" %{
    evaluate-commands %sh{
        USER="$(git remote get-url origin | rg -or '$1' '^git@github.com:([^/]+).*$')"
        REPO="$(git remote get-url origin | rg -or '$1' '^git@github.com:[^/]+/(.*)\.git$')"
        BRANCH="$(git branch --show-current)"
        FILE="$kak_bufname"
        START="$(echo "$kak_selections_char_desc" | cut -d, -f1 | cut -d. -f1)"
        END="$(echo "$kak_selections_char_desc" | cut -d, -f2 | cut -d. -f1)"
        URL="https://github.com/$USER/$REPO/blob/$BRANCH/$FILE?plain=1#L$START-L$END"
        echo "open-in-browser $URL"
    }
}
map global git o ":git-open<ret>" -docstring "  Open permalink"

map global user -docstring 'gitt' g ':enter-user-mode git<ret>'
