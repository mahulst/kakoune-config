define-command vue-comment-line -docstring 'context-aware (un)comment for Vue SFC files' %{
    evaluate-commands -save-regs 'a' %{
        # In a draft context, search backward for the nearest top-level
        # <script, <style, or <template tag to determine which block the
        # cursor is in.
        try %{
            evaluate-commands -draft %{
                execute-keys '<a-/>^\s*<lt>(script|style|template)<ret>'
                set-register a %sh{
                    printf '%s' "$kak_selection" | grep -oE '(script|style|template)' | head -1
                }
            }
        } catch %{
            set-register a 'unknown'
        }
        # Use the detected block type to set the right comment options
        # and invoke the appropriate comment command.
        evaluate-commands %sh{
            case "$kak_reg_a" in
                *script*)
                    printf '%s\n' \
                        "set-option window comment_line '//'" \
                        "set-option window comment_block_begin '/*'" \
                        "set-option window comment_block_end '*/'" \
                        "comment-line"
                    ;;
                *style*)
                    printf '%s\n' \
                        "set-option window comment_block_begin '/*'" \
                        "set-option window comment_block_end '*/'" \
                        "vue-comment-block-per-line"
                    ;;
                *template*)
                    printf '%s\n' \
                        "set-option window comment_block_begin '<!--'" \
                        "set-option window comment_block_end '-->'" \
                        "vue-comment-block-per-line"
                    ;;
                *)
                    echo "fail 'vue-comment-line: could not detect block type'"
                    ;;
            esac
        }
    }
}

define-command vue-comment-block-per-line -hidden -docstring 'apply comment-block to each line individually' %{
    evaluate-commands -save-regs '"/' -draft %{
        # Extend to full lines, then split into individual lines
        execute-keys x<a-s>

        try %{
            # Drop blank/whitespace-only lines
            execute-keys <a-K>\A\s*\z<ret>
        } catch %{
            # All lines are blank, nothing to do
            fail 'no non-blank lines to comment'
        }

        try %{
            # Check if all lines are already block-commented: try to match
            set-register / "\A\s*\Q%opt{comment_block_begin}\E.*\Q%opt{comment_block_end}\E\s*\z"
            execute-keys "s<ret>"
            # All matched -> uncomment: remove the delimiters
            set-register / "\Q%opt{comment_block_begin}\E\s?|\s?\Q%opt{comment_block_end}\E"
            execute-keys s<ret>d
        } catch %{
            # Not all commented -> comment each line
            # Select line content (skip indentation)
            execute-keys gi<a-l>
            set-register '"' "%opt{comment_block_begin} "
            execute-keys -draft P
            set-register '"' " %opt{comment_block_end}"
            execute-keys p
        }
    }
}

hook global WinSetOption filetype=vue %{
    map window user '/' ':vue-comment-line<ret>' -docstring 'comment line (vue-aware)'
}
