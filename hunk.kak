# hunk.kak - Hunk (local-first code review) integration
#
# Talks to the `hunk session` CLI to create and query inline review comments
# for the active review session whose repo root matches the current buffer.
#
# Keybindings: <space>h enters "hunk" review mode, then:
#   <ret> / h  -> show comments for the current line in the docs/info window
#   r          -> refresh review state (rebuild index + gutter flags)
#   c          -> add a comment on the current line
#   l          -> list all comments for the current file
#   n / p      -> jump to next / previous commented line

# --- Faces ---------------------------------------------------------------
set-face global HunkComment blue,default
set-face global HunkCommentLine default,default@comment

# --- Options -------------------------------------------------------------
# Gutter flag symbol shown next to lines that carry a Hunk comment.
declare-option -docstring 'gutter symbol for Hunk-commented lines' str hunk_flag_symbol '󰆉'

# Per-buffer line-specs for the flag-lines highlighter (line|face|text ...).
declare-option -hidden line-specs hunk_comment_flags

# In-memory index for the current buffer, encoded as newline-separated
# "line<tab>count" pairs. Lets navigation/docs commands work without shelling
# out again.
declare-option -hidden str hunk_comment_lines

# --- Highlighter ---------------------------------------------------------
hook global WinCreate .* %{
    add-highlighter window/hunk-comments flag-lines HunkCommentLine hunk_comment_flags
}

# Refresh automatically when a buffer backed by a file is opened.
hook global BufOpenFile .* %{
    try %{ hunk-refresh }
}

# --- Comment: add on current line ----------------------------------------
define-command hunk-comment -docstring 'add a Hunk review comment on the current line' %{
    prompt 'Hunk comment: ' %{
        evaluate-commands %sh{
            summary="$kak_text"
            file="$kak_buffile"
            line="$kak_cursor_line"

            if [ -z "$file" ]; then
                echo "fail 'current buffer is not backed by a file'"
                exit
            fi
            if [ -z "$summary" ]; then
                echo "fail 'empty comment'"
                exit
            fi

            repo=$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
            if [ -z "$repo" ]; then
                echo "fail 'current file is not in a git repository'"
                exit
            fi

            # Resolve the newest active session for this repo. --repo fails
            # when multiple sessions match, and hunk exits 0 on error.
            sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
                [ .sessions[] | select(.repoRoot == $r) ]
                | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
            if [ -z "$sid" ]; then
                echo "fail 'no active Hunk review for this repository'"
                exit
            fi

            relpath="${file#"$repo"/}"

            out=$(hunk session comment add "$sid" \
                --file "$relpath" --new-line "$line" \
                --summary "$summary" --focus 2>&1)
            status=$?

            if [ "$status" -ne 0 ]; then
                msg=$(printf '%s' "$out" | sed "s/'/''/g")
                echo "fail 'hunk: $msg'"
                exit
            fi

            echo "info 'Hunk comment added on line $line'"
            echo "hunk-refresh"
        }
    }
}

# --- Refresh: rebuild the in-memory index + gutter flags ------------------
define-command hunk-refresh -docstring 'refresh Hunk review state for the current buffer' %{
    evaluate-commands %sh{
        file="$kak_buffile"
        [ -z "$file" ] && exit

        repo=$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
        [ -z "$repo" ] && exit

        relpath="${file#"$repo"/}"

        sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
            [ .sessions[] | select(.repoRoot == $r) ]
            | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
        [ -z "$sid" ] && exit

        json=$(hunk session comment list "$sid" --file "$relpath" --type all --json 2>/dev/null)
        [ $? -ne 0 ] && exit
        [ -z "$json" ] && exit

        # Count comments per new-line for this file.
        # Emits: "line count" lines, then the flag-lines spec string.
        symbol="$kak_opt_hunk_flag_symbol"

        pairs=$(printf '%s' "$json" | jq -r --arg f "$relpath" '
            [ .comments[]
              | select(.filePath == $f)
              | (if .line != null then .line
                 elif .newRange != null then .newRange[0]
                 else null end)
              | select(. != null) ]
            | group_by(.) | map({line: .[0], count: length})
            | .[] | "\(.line)\t\(.count)"' 2>/dev/null)

        # Build the newline-separated index option value.
        index=$(printf '%s' "$pairs" | tr '\t' ' ')

        # Build flag-lines specs: "line|{HunkComment}<symbol>"
        specs=""
        while IFS='	' read -r ln cnt; do
            [ -z "$ln" ] && continue
            label="$symbol"
            [ "$cnt" -gt 1 ] 2>/dev/null && label="${symbol}${cnt}"
            specs="$specs '${ln}|{HunkComment}${label}'"
        done <<EOF
$pairs
EOF

        # Encode index for storage in a str option (space-separated line:count).
        stored=$(printf '%s' "$pairs" | tr '\t' ':' | tr '\n' ' ')
        stored=$(printf '%s' "$stored" | sed "s/'/''/g")

        printf 'set-option buffer hunk_comment_lines %%{%s}\n' "$stored"
        if [ -n "$specs" ]; then
            printf 'set-option buffer hunk_comment_flags %s %s\n' "$kak_timestamp" "$specs"
        else
            printf 'set-option buffer hunk_comment_flags %s\n' "$kak_timestamp"
        fi
    }
}

# --- Docs window: show comments for the current line ----------------------
define-command hunk-show-comments -docstring 'show Hunk comments for the current line in the docs window' %{
    evaluate-commands %sh{
        file="$kak_buffile"
        line="$kak_cursor_line"

        if [ -z "$file" ]; then
            echo "info 'No Hunk comments.'"
            exit
        fi

        repo=$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$repo" ]; then
            echo "info 'No Hunk comments.'"
            exit
        fi

        relpath="${file#"$repo"/}"

        sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
            [ .sessions[] | select(.repoRoot == $r) ]
            | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
        if [ -z "$sid" ]; then
            echo "info 'No Hunk comments.'"
            exit
        fi

        json=$(hunk session comment list "$sid" --file "$relpath" --type all --json 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$json" ]; then
            echo "info 'No Hunk comments.'"
            exit
        fi

        body=$(printf '%s' "$json" | jq -r --arg f "$relpath" --argjson l "$line" '
            [ .comments[]
              | select(.filePath == $f)
              | { line: (if .line != null then .line elif .newRange != null then .newRange[0] else null end),
                  text: (.summary // .body // ""),
                  author: (.author // .source // "unknown"),
                  time: (.createdAt // "") }
              | select(.line == $l) ]
            | if length == 0 then "" else
                map("• \(.author)\(if .time != "" then " (" + .time + ")" else "" end)\n  \(.text)")
                | join("\n\n")
              end' 2>/dev/null)

        if [ -z "$body" ]; then
            echo "info 'No Hunk comments.'"
            exit
        fi

        escaped=$(printf '%s' "$body" | sed "s/'/''/g")
        printf "info -title 'Hunk comments (line %s)' '%s'\n" "$line" "$escaped"
    }
}

# --- List all comments for the current file (docs window) -----------------
define-command hunk-list-comments -docstring 'list all Hunk comments for the current file' %{
    evaluate-commands %sh{
        file="$kak_buffile"
        [ -z "$file" ] && { echo "info 'No Hunk comments.'"; exit; }

        repo=$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
        [ -z "$repo" ] && { echo "info 'No Hunk comments.'"; exit; }

        relpath="${file#"$repo"/}"
        sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
            [ .sessions[] | select(.repoRoot == $r) ]
            | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
        [ -z "$sid" ] && { echo "info 'No Hunk comments.'"; exit; }
        json=$(hunk session comment list "$sid" --file "$relpath" --type all --json 2>/dev/null)
        [ $? -ne 0 ] && { echo "info 'No Hunk comments.'"; exit; }

        body=$(printf '%s' "$json" | jq -r --arg f "$relpath" '
            [ .comments[]
              | select(.filePath == $f)
              | { line: (if .line != null then .line elif .newRange != null then .newRange[0] else null end),
                  text: (.summary // .body // "") }
              | select(.line != null) ]
            | sort_by(.line)
            | if length == 0 then "" else
                map("L\(.line): \(.text)") | join("\n")
              end' 2>/dev/null)

        [ -z "$body" ] && { echo "info 'No Hunk comments.'"; exit; }

        escaped=$(printf '%s' "$body" | sed "s/'/''/g")
        printf "info -title 'Hunk comments (%s)' '%s'\n" "$relpath" "$escaped"
    }
}

# --- Navigation between commented lines -----------------------------------
define-command -hidden hunk-jump -params 1 %{
    evaluate-commands %sh{
        dir="$1"
        cur="$kak_cursor_line"
        # hunk_comment_lines is "line:count line:count ..."
        lines=$(printf '%s' "$kak_opt_hunk_comment_lines" | tr ' ' '\n' | cut -d: -f1 | grep -E '^[0-9]+$' | sort -n)

        if [ -z "$lines" ]; then
            echo "fail 'no Hunk comments in this file'"
            exit
        fi

        target=""
        if [ "$dir" = "next" ]; then
            target=$(printf '%s\n' "$lines" | awk -v c="$cur" '$1 > c {print; exit}')
            [ -z "$target" ] && target=$(printf '%s\n' "$lines" | head -1)
        else
            target=$(printf '%s\n' "$lines" | awk -v c="$cur" '$1 < c {t=$1} END {print t}')
            [ -z "$target" ] && target=$(printf '%s\n' "$lines" | tail -1)
        fi

        if [ -z "$target" ]; then
            echo "fail 'no Hunk comments in this file'"
            exit
        fi

        echo "execute-keys ${target}g"
    }
}

define-command hunk-next-comment -docstring 'jump to next Hunk-commented line' %{ hunk-jump next }
define-command hunk-prev-comment -docstring 'jump to previous Hunk-commented line' %{ hunk-jump prev }

# --- Keybindings ----------------------------------------------------------
# <space>h enters Hunk mode. The primary action (show comments for the
# current line) is on <ret> and h, so <space>hh / <space>h<ret> shows docs,
# while <space>hr refreshes, <space>hc adds a comment, etc.
declare-user-mode hunk
map global hunk <ret> ':hunk-show-comments<ret>' -docstring 'show comments for current line'
map global hunk h ':hunk-show-comments<ret>'  -docstring 'show comments for current line'
map global hunk c ':hunk-comment<ret>'        -docstring 'add comment on current line'
map global hunk r ':hunk-refresh<ret>'        -docstring 'refresh review state'
map global hunk l ':hunk-list-comments<ret>'  -docstring 'list comments for current file'
map global hunk n ':hunk-next-comment<ret>'   -docstring 'next commented line'
map global hunk p ':hunk-prev-comment<ret>'   -docstring 'previous commented line'

map global user h ':enter-user-mode hunk<ret>' -docstring 'Hunk review mode'
