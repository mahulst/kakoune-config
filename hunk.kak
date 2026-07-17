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
set-face global HunkDocsTitle blue,default+b
set-face global HunkDocsLine green,default
set-face global HunkDocsMeta comment

# Highlighting for the *hunk-comments* docs buffer.
hook global WinSetOption filetype=hunk-comments %{
    add-highlighter window/hunk-docs group
    add-highlighter window/hunk-docs/header regex ^(#\h[^\n]*) 1:HunkDocsTitle
    add-highlighter window/hunk-docs/line regex ^[^:\n]*:(\d+): 1:HunkDocsLine
    add-highlighter window/hunk-docs/lline regex ^(L\d+:) 1:HunkDocsLine
    add-highlighter window/hunk-docs/meta regex ^(•[^\n]*) 1:HunkDocsMeta
    map buffer normal <ret> ':hunk-docs-goto<ret>' -docstring 'go to comment source line'
    map buffer user x ':hunk-clear-line<ret>' -docstring 'clear comment on this line'
    hook -once -always window WinSetOption filetype=.* %{
        remove-highlighter window/hunk-docs
        unmap buffer normal <ret> ':hunk-docs-goto<ret>'
        unmap buffer user x ':hunk-clear-line<ret>'
    }
}

# --- Options -------------------------------------------------------------
# Gutter flag symbol shown next to lines that carry a Hunk comment.
declare-option -docstring 'gutter symbol for Hunk-commented lines' str hunk_flag_symbol '!'

# Per-buffer line-specs for the flag-lines highlighter (line|face|text ...).
declare-option -hidden line-specs hunk_comment_flags

# In-memory index for the current buffer, encoded as newline-separated
# "line<tab>count" pairs. Lets navigation/docs commands work without shelling
# out again.
declare-option -hidden str hunk_comment_lines

# Absolute path of the source file whose comments are shown in the
# *hunk-comments* docs buffer. Used to jump back on <ret>.
declare-option -hidden str hunk_docs_source_file

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

            # Reload the session's diff first so the current line is inside an
            # up-to-date hunk (equivalent to pressing "r" in the hunk TUI).
            hunk session reload "$sid" -- diff >/dev/null 2>&1

            out=$(hunk session comment add "$sid" \
                --file "$relpath" --new-line "$line" \
                --summary "$summary" --focus 2>&1)

            # hunk exits 0 even on error, so detect success by output text.
            case "$out" in
                "Added live comment"*)
                    echo "info 'Hunk comment added on line $line'"
                    echo "hunk-refresh"
                    ;;
                *)
                    msg=$(printf '%s' "$out" | sed "s/'/''/g")
                    echo "fail 'hunk: $msg'"
                    ;;
            esac
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

        # Reload the session's diff so newly-changed lines become commentable
        # (equivalent to pressing "r" in the hunk TUI).
        hunk session reload "$sid" -- diff >/dev/null 2>&1

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
            [ "$cnt" -gt 1 ] 2>/dev/null && label="${symbol}${symbol}"
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

# --- Docs render helper ---------------------------------------------------
# Show the given text in the *hunk-comments* scratch buffer, in the docs
# client when one exists (falls back to the current client otherwise).
define-command -hidden hunk-render-docs -params 3 %{
    evaluate-commands %sh{
        title="$1"
        srcfile="$3"
        tmp=$(mktemp "${TMPDIR:-/tmp}/hunk-comments.XXXXXX")
        printf '%s\n\n%s\n' "$title" "$2" > "$tmp"
        client="$kak_opt_docsclient"
        [ -z "$client" ] && client="$kak_client"
        srcesc=$(printf '%s' "$srcfile" | sed "s/'/''/g")
        printf "evaluate-commands -client %%{%s} %%{\n" "$client"
        printf "  edit! -scratch *hunk-comments*\n"
        printf "  set-option buffer readonly false\n"
        printf "  execute-keys '%%%%|cat %s<ret>'\n" "$tmp"
        printf "  set-option buffer readonly true\n"
        printf "  set-option buffer filetype hunk-comments\n"
        printf "  set-option buffer hunk_docs_source_file '%s'\n" "$srcesc"
        printf "}\n"
        ( sleep 2; rm -f "$tmp" ) >/dev/null 2>&1 &
    }
}

# Jump from a comment line in the docs buffer to its source line, in the jump
# client. Supports two line formats:
#   <relpath>:<n>: text   -> jump to repo-root/<relpath> at line n
#   L<n>: text            -> jump to the stored base file at line n
# hunk_docs_source_file holds either the repo root (list view) or a file
# (single-line view); we resolve accordingly.
define-command -hidden hunk-docs-goto %{
    evaluate-commands -save-regs 'a' %{
        execute-keys 'x'
        set-register a %val{selection}
        execute-keys 'gh'
        evaluate-commands %sh{
            base="$kak_opt_hunk_docs_source_file"
            [ -z "$base" ] && { echo "fail 'no source for this docs buffer'"; exit; }

            linetext="$kak_reg_a"
            # Try "<relpath>:<n>: ..." first.
            rel=$(printf '%s' "$linetext" | sed -n 's/^\([^:]*\):\([0-9]\{1,\}\):.*/\1/p')
            ln=$(printf '%s' "$linetext" | sed -n 's/^[^:]*:\([0-9]\{1,\}\):.*/\1/p')

            if [ -n "$rel" ] && [ -n "$ln" ]; then
                if [ -d "$base" ]; then
                    target="$base/$rel"
                else
                    target="$rel"
                fi
            else
                # Fallback: "L<n>: ..." using the stored base file.
                ln=$(printf '%s' "$linetext" | sed -n 's/^[[:space:]]*L\([0-9]\{1,\}\):.*/\1/p')
                [ -z "$ln" ] && { echo "fail 'not a comment line'"; exit; }
                target="$base"
            fi

            tgtesc=$(printf '%s' "$target" | sed "s/'/''/g")
            printf "evaluate-commands -try-client %%{%s} %%{ edit -existing '%s' %s }\n" "$kak_opt_jumpclient" "$tgtesc" "$ln"
        }
    }
}

# Delete the comment(s) on the docs line under the cursor. Parses the
# "<relpath>:<n>: text" prefix, resolves matching noteId(s) from the session
# and removes them.
define-command -hidden hunk-clear-line %{
    evaluate-commands -save-regs 'a' %{
        execute-keys 'x'
        set-register a %val{selection}
        execute-keys 'gh'
        evaluate-commands %sh{
            base="$kak_opt_hunk_docs_source_file"
            [ -z "$base" ] && { echo "fail 'no source for this docs buffer'"; exit; }

            linetext="$kak_reg_a"
            rel=$(printf '%s' "$linetext" | sed -n 's/^\([^:]*\):\([0-9]\{1,\}\):.*/\1/p')
            ln=$(printf '%s' "$linetext" | sed -n 's/^[^:]*:\([0-9]\{1,\}\):.*/\1/p')
            text=$(printf '%s' "$linetext" | sed -n 's/^[^:]*:[0-9]\{1,\}: \(.*\)/\1/p')

            if [ -z "$rel" ] || [ -z "$ln" ]; then
                # Single-line "L<n>:" view: base is the file, rel derived below.
                ln=$(printf '%s' "$linetext" | sed -n 's/^[[:space:]]*L\([0-9]\{1,\}\): \(.*\)/\1/p')
                text=$(printf '%s' "$linetext" | sed -n 's/^[[:space:]]*L[0-9]\{1,\}: \(.*\)/\1/p')
                [ -z "$ln" ] && { echo "fail 'not a comment line'"; exit; }
            fi

            if [ -d "$base" ]; then
                repo="$base"
            else
                repo=$(cd "$(dirname "$base")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
                rel="${base#"$repo"/}"
            fi

            sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
                [ .sessions[] | select(.repoRoot == $r) ]
                | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
            [ -z "$sid" ] && { echo "fail 'no active Hunk review for this repository'"; exit; }

            json=$(hunk session comment list "$sid" --type all --json 2>/dev/null)
            ids=$(printf '%s' "$json" | jq -r \
                --arg f "$rel" --argjson l "$ln" --arg t "$text" '
                .comments[]
                | select(.filePath == $f)
                | select((if .line != null then .line elif .newRange != null then .newRange[0] else null end) == $l)
                | select(((.summary // .body // "")) == $t)
                | (.noteId // .commentId // .id // empty)' 2>/dev/null)

            [ -z "$ids" ] && { echo "fail 'no matching Hunk comment on this line'"; exit; }

            n=0
            for id in $ids; do
                hunk session comment rm "$sid" "$id" >/dev/null 2>&1 && n=$((n+1))
            done

            echo "info 'Removed $n Hunk comment(s)'"
            echo "hunk-list-comments"
        }
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
        fileesc=$(printf '%s' "$file" | sed "s/'/''/g")
        printf "hunk-render-docs 'Hunk comments (line %s)' '%s' '%s'\n" "$line" "$escaped" "$fileesc"
    }
}

# --- List all comments for the whole session (docs window) ----------------
define-command hunk-list-comments -docstring 'list all Hunk comments for the session' %{
    evaluate-commands %sh{
        file="$kak_buffile"
        [ -z "$file" ] && { echo "info 'No Hunk comments.'"; exit; }

        repo=$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
        [ -z "$repo" ] && { echo "info 'No Hunk comments.'"; exit; }

        sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
            [ .sessions[] | select(.repoRoot == $r) ]
            | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
        [ -z "$sid" ] && { echo "info 'No Hunk comments.'"; exit; }
        json=$(hunk session comment list "$sid" --type all --json 2>/dev/null)
        [ $? -ne 0 ] && { echo "info 'No Hunk comments.'"; exit; }

        # Group all comments by file, emit "<relpath>:<line>: text" lines with
        # a blank-line-separated header per file. The <relpath>:<line> prefix
        # lets <ret> jump to the right file and line.
        body=$(printf '%s' "$json" | jq -r '
            [ .comments[]
              | { file: .filePath,
                  line: (if .line != null then .line elif .newRange != null then .newRange[0] else null end),
                  text: (.summary // .body // "") }
              | select(.line != null and .file != null) ]
            | group_by(.file)
            | map(
                .[0].file as $f
                | "# \($f)\n" +
                  ( sort_by(.line)
                    | map("\($f):\(.line): \(.text)")
                    | join("\n") )
              )
            | join("\n\n")' 2>/dev/null)

        [ -z "$body" ] && { echo "info 'No Hunk comments.'"; exit; }

        escaped=$(printf '%s' "$body" | sed "s/'/''/g")
        repoesc=$(printf '%s' "$repo" | sed "s/'/''/g")
        printf "hunk-render-docs 'Hunk comments (session)' '%s' '%s'\n" "$escaped" "$repoesc"
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

# --- Clear: delete all comments for the session ---------------------------
define-command hunk-clear-comments -docstring 'delete ALL Hunk comments for the session' %{
    prompt 'Delete ALL Hunk comments? (type yes): ' %{
        evaluate-commands %sh{
            [ "$kak_text" != "yes" ] && { echo "info 'Cancelled.'"; exit; }

            file="$kak_buffile"
            repo=$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
            # Fallback for the *hunk-comments* scratch buffer, which has no
            # backing file: its stored base is the repo root.
            if [ -z "$repo" ]; then
                base="$kak_opt_hunk_docs_source_file"
                [ -d "$base" ] && repo="$base"
            fi
            [ -z "$repo" ] && { echo "fail 'not in a git repository'"; exit; }

            sid=$(hunk session list --json 2>/dev/null | jq -r --arg r "$repo" '
                [ .sessions[] | select(.repoRoot == $r) ]
                | sort_by(.launchedAt) | reverse | .[0].sessionId // empty' 2>/dev/null)
            [ -z "$sid" ] && { echo "fail 'no active Hunk review for this repository'"; exit; }

            out=$(hunk session comment clear "$sid" --all --yes 2>&1)
            case "$out" in
                *[Cc]leared*|*[Rr]emoved*)
                    echo "info 'All Hunk comments cleared'"
                    echo "hunk-refresh"
                    ;;
                *)
                    msg=$(printf '%s' "$out" | sed "s/'/''/g")
                    echo "fail 'hunk: $msg'"
                    ;;
            esac
        }
    }
}

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
map global hunk R ':hunk-clear-comments<ret>' -docstring 'delete ALL comments'

map global user h ':enter-user-mode hunk<ret>' -docstring 'Hunk review mode'
