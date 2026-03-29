# declare-option str git_branch_name
# declare-option str awk_cmd 'awk'
declare-user-mode git

map global git <ret> ':git blame-jump<ret>' -docstring 'open last commit that touched current line'
map global git n ':git next-hunk<ret>' -docstring 'goto next hunk'
map global git p ':git prev-hunk<ret>' -docstring 'goto previous hunk'
map global git r ':git apply --cached --reverse<ret>' -docstring 'git undo add selection'
map global git a ':git apply --cached<ret>' -docstring 'git add selection'
map global git R ':git reset HEAD -- %val{buffile}<ret>' -docstring 'git reset file'
map global git A ':git add<ret>' -docstring 'git add file'

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

define-command git-diff-current-line-commit -docstring 'show the diff of the commit that last touched the current line' %{
    evaluate-commands %sh{
        commit=$(git blame -L"$kak_cursor_line,$kak_cursor_line" --porcelain "$kak_buffile" | head -1 | cut -d' ' -f1)
        if [ -z "$commit" ] || echo "$commit" | grep -qE '^0+$'; then
            echo "fail 'line has not been committed yet'"
        else
            echo "git show $commit"
        fi
    }
}

map global git D ':git-diff-current-line-commit<ret>' -docstring 'diff of commit at cursor line'
map global git l ':git log<ret>' -docstring 'log'
map global git b ':git blame<ret>' -docstring 'blame'
map global git B ':git blame-jump<ret>' -docstring 'blame jump'
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

map global git m ':git-conflicts<ret>' -docstring 'merge conflicts'
map global git h ':git-file-history<ret>' -docstring 'commits for current file'
map global user -docstring 'gitt' g ':enter-user-mode git<ret>'

# Git merge conflicts buffer
declare-option -hidden str git_conflicts_root

# Git file history buffers
declare-option -hidden str git_file_history_root
declare-option -hidden str git_file_history_path
declare-option -hidden str git_file_history_selected_hash

define-command git-conflicts -docstring 'list files with merge conflicts' %{
    evaluate-commands %sh{
        toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$toplevel" ]; then
            echo "fail 'not in a git repository'"
            exit
        fi
        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-git-conflicts.XXXXXXXX)/fifo
        mkfifo ${output}
        ( cd "$toplevel" && git diff --name-only --diff-filter=U > ${output} 2>&1 ) > /dev/null 2>&1 < /dev/null &
        printf %s\\n "
            try %{ delete-buffer *git-conflicts* }
            evaluate-commands -try-client %opt[toolsclient] %{
                edit! -fifo ${output} -scroll *git-conflicts*
                set-option buffer filetype git-conflicts
                set-option buffer git_conflicts_root '${toplevel}'
                hook -once buffer BufCloseFifo .* %{
                    nop %sh{ rm -r \$(dirname ${output}) }
                }
            }
        "
    }
}

define-command -hidden git-conflicts-jump %{
    evaluate-commands -save-regs 'f' %{
        execute-keys -draft 'xH"fy'
        evaluate-commands -try-client %opt{jumpclient} %{
            edit -existing "%opt{git_conflicts_root}/%reg{f}"
            try %{ focus }
        }
    }
}

hook global WinSetOption filetype=git-conflicts %{
    map -docstring 'jump to file' buffer normal <ret> ':git-conflicts-jump<ret>'
}

hook global WinSetOption filetype=(?!git-conflicts).* %{
    unmap buffer normal <ret> ':git-conflicts-jump<ret>'
}

define-command git-file-history -docstring 'list commits that changed current file' %{
    evaluate-commands %sh{
        if [ -z "$kak_buffile" ]; then
            echo "fail 'current buffer is not backed by a file'"
            exit
        fi

        file_dir=$(dirname "$kak_buffile")
        toplevel=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$toplevel" ]; then
            echo "fail 'current file is not in a git repository'"
            exit
        fi

        relpath="${kak_buffile#"$toplevel"/}"
        if [ "$relpath" = "$kak_buffile" ]; then
            echo "fail 'could not resolve file path from repository root'"
            exit
        fi

        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-git-file-history.XXXXXXXX)/fifo
        mkfifo "$output"
        (
            git -C "$toplevel" log --follow --format='%H%x09%cn%x09%s' -- "$relpath" \
                | while IFS=$'\t' read -r full_hash committer subject; do
                    short_hash=$(git -C "$toplevel" rev-parse --short=4 "$full_hash" 2>/dev/null)
                    printf '%s (%s): %s\n' "$short_hash" "$committer" "$subject"
                done > "$output" 2>&1
        ) > /dev/null 2>&1 < /dev/null &

        escaped_toplevel=$(printf "%s" "$toplevel" | sed "s/'/'\\\\''/g")
        escaped_relpath=$(printf "%s" "$relpath" | sed "s/'/'\\\\''/g")

        printf %s\\n "
            try %{ delete-buffer *git-file-history* }
            evaluate-commands -try-client %opt[toolsclient] %{
                edit! -fifo ${output} -scroll *git-file-history*
                set-option buffer filetype git-file-history
                set-option buffer git_file_history_root '${escaped_toplevel}'
                set-option buffer git_file_history_path '${escaped_relpath}'
                hook -once buffer BufCloseFifo .* %{
                    nop %sh{ rm -r \\$(dirname ${output}) }
                }
            }
        "
    }
}

define-command -hidden git-file-history-select-hash %{
    evaluate-commands -draft %{
        execute-keys 'x'
        set-option buffer git_file_history_selected_hash %sh{
            printf '%s' "$kak_selection" | sed -E 's/^([0-9a-fA-F]+).*/\1/'
        }
    }
}

define-command -hidden git-file-history-open-commit %{
    git-file-history-select-hash

    evaluate-commands %sh{
        hash="$kak_opt_git_file_history_selected_hash"
        if ! printf '%s' "$hash" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
            echo "fail 'no commit hash on current line'"
            exit
        fi

        root="$kak_opt_git_file_history_root"
        short_hash=$(printf '%s' "$hash" | cut -c1-12)

        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-git-show.XXXXXXXX)/fifo
        mkfifo "$output"
        ( git -C "$root" show "$hash" > "$output" 2>&1 ) > /dev/null 2>&1 < /dev/null &

        printf %s\\n "
            evaluate-commands -try-client %opt[toolsclient] %{
                edit! -fifo ${output} -scroll *git-diff-${short_hash}*
                set-option buffer filetype diff
                hook -once buffer BufCloseFifo .* %{
                    nop %sh{ rm -r \\$(dirname ${output}) }
                }
            }
        "
    }
}

define-command -hidden git-file-history-open-commit-file %{
    git-file-history-select-hash

    evaluate-commands %sh{
        hash="$kak_opt_git_file_history_selected_hash"
        if ! printf '%s' "$hash" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
            echo "fail 'no commit hash on current line'"
            exit
        fi

        root="$kak_opt_git_file_history_root"
        file="$kak_opt_git_file_history_path"
        short_hash=$(printf '%s' "$hash" | cut -c1-12)

        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-git-show-file.XXXXXXXX)/fifo
        mkfifo "$output"
        ( git -C "$root" show "$hash" -- "$file" > "$output" 2>&1 ) > /dev/null 2>&1 < /dev/null &

        printf %s\\n "
            evaluate-commands -try-client %opt[toolsclient] %{
                edit! -fifo ${output} -scroll *git-file-diff-${short_hash}*
                set-option buffer filetype diff
                hook -once buffer BufCloseFifo .* %{
                    nop %sh{ rm -r \\$(dirname ${output}) }
                }
            }
        "
    }
}

hook global WinSetOption filetype=git-file-history %{
    map -docstring 'open current-file diff only' buffer normal <ret> ':git-file-history-open-commit-file<ret>'
    map -docstring 'open full commit diff' buffer normal <a-ret> ':git-file-history-open-commit<ret>'
}

hook global WinSetOption filetype=(?!git-file-history).* %{
    unmap buffer normal <ret> ':git-file-history-open-commit<ret>'
    unmap buffer normal <a-ret> ':git-file-history-open-commit-file<ret>'
}

# Git interactive rebase keybindings
# Press a key to change the action for the current line's commit
define-command -hidden git-rebase-set-action -params 1 %{
    evaluate-commands -draft %{
        execute-keys 'ghw'
        execute-keys "c%arg{1} <esc>"
    }
}

define-command fzf-git-changed -docstring 'fzf browse git changed files (staged and unstaged)' %{ evaluate-commands %sh{
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$toplevel" ]; then
        echo "fail 'not in a git repository'"
        exit
    fi
    # List changed files: both staged and unstaged, deduplicated
    items_cmd="cd $toplevel && git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null"
    items_cmd="($items_cmd) | sort -u"

    [ -n "${kak_client_env_TMUX}" ] && additional_flags="--expect ${kak_opt_fzf_vertical_map:-ctrl-v} --expect ${kak_opt_fzf_horizontal_map:-ctrl-s}"

    printf "%s\n" "fzf -preview -kak-cmd %{edit -existing} -items-cmd %{$items_cmd} -fzf-args %{-m --expect ${kak_opt_fzf_window_map:-ctrl-w} $additional_flags --preview 'cd $toplevel && git diff HEAD -- {} 2>/dev/null || cat {}'} -filter %{perl -pe \"if (/${kak_opt_fzf_window_map:-ctrl-w}|${kak_opt_fzf_vertical_map:-ctrl-v}|${kak_opt_fzf_horizontal_map:-ctrl-s}|^$/) {} else {print \\\"$toplevel/\\\"}\"}"
}}

hook global ModuleLoaded fzf %{
    map global fzf -docstring "git changed files" 'c' '<esc>: fzf-git-changed<ret>'
}

hook global WinSetOption filetype=git-rebase %{
    map window normal p ':git-rebase-set-action pick<ret>'    -docstring 'pick'
    map window normal e ':git-rebase-set-action edit<ret>'    -docstring 'edit'
    map window normal r ':git-rebase-set-action reword<ret>'  -docstring 'reword'
    map window normal s ':git-rebase-set-action squash<ret>'  -docstring 'squash'
    map window normal f ':git-rebase-set-action fixup<ret>'   -docstring 'fixup'
    map window normal d ':git-rebase-set-action drop<ret>'    -docstring 'drop'

    hook -once -always window WinSetOption filetype=.* %{
        unmap window normal p
        unmap window normal e
        unmap window normal r
        unmap window normal s
        unmap window normal f
        unmap window normal d
    }
}
