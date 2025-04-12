# /Users/mahulst/projects/odin/test/main.odin(4:8) Error:

declare-option -docstring "regex describing file paths and line numbers" \
    regex \
    odin_compile_file_pattern \
    "([/a-zA-Z0-9.-]*)\((\d+):(\d+)\) Error:"


define-command build-odin -docstring 'Compile odin project' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %sh{
        current_path=$(pwd)
        echo "run-in-fifo 'odin build ${current_path}' odin-compile"
    }
}


define-command run-odin -docstring 'run odin project' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %sh{
        current_path=$(pwd)
        echo "run-in-fifo 'odin run ${current_path}' odin-compile"
    }
}

hook global WinSetOption filetype=odin-compile %{
    #hook buffer -group cargo-hooks NormalKey <ret> cargo-jump
    map -docstring "Jump to current error" buffer normal <ret> %{: odin-compile-open-file<ret>}
    map -docstring "Jump to current error" buffer normal n %{: odin-compile-next-error<ret>}
}

add-highlighter shared/odin-compile group
add-highlighter shared/odin-compile/ regex "(Error: )" 1:red

hook -group odin-highlight global WinSetOption filetype=odin-compile %{
    add-highlighter window/odin-compile ref odin-compile
}

hook global WinSetOption filetype=(?!odin-compile).* %{
    unmap buffer normal <ret> %{: odin-compile-open-file<ret>}
    unmap buffer normal n %{: odin-compile-next-error<ret>}
}

declare-user-mode odin

map global user -docstring 'odin' o ':enter-user-mode odin<ret>'

map -docstring "build" \
	global odin b %{: build-odin <ret>}

map -docstring "run" \
	global odin r %{: run-odin <ret>}

def open_changed_file_picker %{
  prompt changed_files: -menu -shell-script-candidates "git status -z --no-renames | tr '\0' '\n'" %{
    edit -existing -- %sh{printf '%s' "$kak_text" | cut -c 4-}
  }
}

map -docstring 'open changed file picker' global user <c-p> ':open_changed_file_picker<ret>'

define-command odin-compile-next-error %{
    try %{
        set-register "b" %reg{/}
        set-register "/" "\d+:\d+\) Error: "
        execute-keys "n"
    } catch %{
    	fail "No errors found"
    }
    set-register "/" %reg{b}
}

define-command odin-compile-open-file %{
    evaluate-commands -save-regs fl %{

        set-register "b" %reg{/}
        set-register "/" %opt{odin_compile_file_pattern}
        execute-keys "n"

        set-register "/" %reg{b}
	    edit-line-column %reg{1} %reg{2}
    }
}
