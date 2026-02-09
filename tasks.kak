# Tasks file support (.tasks)
# - <ret> toggles task state:
#   - Non-indented lines: no checkbox -> [] -> [x] -> []
#   - Indented lines with checkbox: toggle own checkbox
#   - Indented lines without checkbox: toggle first parent [] or [x] above
# - <s-ret> always prepends [] to the current line (indented or not)
# - Lines with [x] are green, lines with [] are orange

hook global BufCreate .*\.tasks %{
    set-option buffer filetype tasks
}

hook global WinSetOption filetype=tasks %{
    add-highlighter window/tasks-done regex '^\h*\[x\][^\n]*' 0:green
    add-highlighter window/tasks-pending regex '^\h*\[\][^\n]*' 0:yellow

    map window normal <ret> ':tasks-toggle<ret>'
    map window normal <s-ret> ':tasks-add-checkbox<ret>'

    hook -once -always window WinSetOption filetype=.* %{
        remove-highlighter window/tasks-done
        remove-highlighter window/tasks-pending
        unmap window normal <ret>
        unmap window normal <s-ret>
    }
}

define-command -hidden tasks-toggle %{
    evaluate-commands -draft %{
        # Select the entire current line
        execute-keys 'x'
        try %{
            # Check if line starts with whitespace (indented line)
            execute-keys 's^\h+<ret>'
            # Indented: check if first non-whitespace is a checkbox
            try %{
                execute-keys 'x'
                execute-keys 's^\h*(\[\]|\[x\])<ret>'
                # Has its own checkbox, toggle this line
                execute-keys 'x'
                tasks-toggle-line
            } catch %{
                # No checkbox on this indented line, toggle parent
                tasks-toggle-parent
            }
        } catch %{
            # Non-indented line: toggle directly
            tasks-toggle-line
        }
    }
}

define-command -hidden tasks-toggle-line %{
    # Operates on current selection (already in -draft from caller)
    try %{
        # Line has [x] -> replace with []
        execute-keys 's\[x\]<ret>'
        execute-keys 'c[]<esc>'
    } catch %{
        try %{
            # Line has [] -> replace with [x]
            execute-keys 's\[\]<ret>'
            execute-keys 'c[x]<esc>'
        } catch %{
            # Line has neither -> prepend [] after leading whitespace
            execute-keys 'ghw<a-;>i[]<esc>'
        }
    }
}

define-command -hidden tasks-toggle-parent %{
    # Search upward for the nearest line containing [] or [x]
    execute-keys 'gh<a-/>(\[\]|\[x\])<ret>x'
    tasks-toggle-line
}

define-command -hidden tasks-add-checkbox %{
    evaluate-commands -draft %{
        execute-keys 'x'
        try %{
            # Already has a checkbox, do nothing
            execute-keys 's^\h*(\[\]|\[x\])<ret>'
        } catch %{
            # Prepend [] after any leading whitespace
            try %{
                # Has leading whitespace: insert after it
                execute-keys 's^\h+<ret>'
                execute-keys 'a[]<esc>'
            } catch %{
                # No leading whitespace: prepend at start
                execute-keys 'ghi[]<esc>'
            }
        }
    }
}
