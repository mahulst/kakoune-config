declare-option -docstring "regex describing cargo error references" \
    regex \
    cargo_error_pattern \
    "^\h*(?:error|warning|note)(?:\[[A-Z0-9]+\])?: ([^\n]*)\n *--> ([^\n]*?):(\d+)(?::(\d+))?"

declare-option -docstring "regex describing file paths and line numbers" \
    regex \
    cargo_file_pattern \
    "(\w|\.|/)+:\d+:\d+"
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient

declare-option -hidden str cargo_workspace_root

add-highlighter shared/cargo group
add-highlighter shared/cargo/ regex "^(error(?:\[[A-Z0-9]+\])?:)" 1:red
add-highlighter shared/cargo/ regex "^(warning(?:\[[A-Z0-9]+\])?:)" 1:yellow
add-highlighter shared/cargo/ regex "^(note(?:\[[A-Z0-9]+\])?:)" 1:green
add-highlighter shared/cargo/ regex "^ +\|[ |]+(-+[^\n]*)$" 1:cyan
add-highlighter shared/cargo/ regex "^ +\|[ |]+(\^+[^\n]*)$" 1:red

hook -group cargo-highlight global WinSetOption filetype=cargo %{
    add-highlighter window/cargo ref cargo
}

hook global WinSetOption filetype=cargo %{
    #hook buffer -group cargo-hooks NormalKey <ret> cargo-jump
    map -docstring "Jump to current error" buffer normal <ret> %{: cargo-jump<ret>}
    map -docstring "Jump to file on current line" buffer user "f" %{: cargo-open-file<ret>}
    map -docstring "Go to next error" buffer normal "n" %{: cargo-next-error<ret>}
    map -docstring "Go to previous error" buffer normal "p" %{: cargo-previous-error<ret>}
}

hook -group cargo-highlight global WinSetOption filetype=(?!cargo).* %{
    try %{
        remove-highlighter window/cargo
    }
}

hook global WinSetOption filetype=(?!cargo).* %{
    #remove-hooks buffer cargo-hooks
    unmap buffer normal <ret> %{: cargo-jump<ret>}
    unmap buffer user f %{: cargo-open-file<ret>}
    unmap buffer normal "n" %{: cargo-next-error<ret>}
    unmap buffer normal "p" %{: cargo-previous-error<ret>}
}

declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient

define-command -hidden cargo-open-error -params 4 %{
    evaluate-commands -try-client %opt{jumpclient} %{
        edit -existing "%arg{1}" "%arg{2}" "%arg{3}"
        info -anchor "%arg{2}.%arg{3}" "%arg{4}"
        try %{ focus }
    }
}

define-command -hidden cargo-jump %{
    evaluate-commands %{
        # We may be in the middle of an error.
        # To find it, we search for the next error
        # (which definitely moves us past the end of this error)
        # and then search backward
        execute-keys "/" %opt{cargo_error_pattern} <ret>
        execute-keys <a-/> %opt{cargo_error_pattern} <ret><a-:> "<a-;>"

        # We found a Cargo error, let's open it.
        cargo-open-error \
            "%opt{cargo_workspace_root}%reg{2}" \
            "%reg{3}" \
            "%sh{ echo ${kak_main_reg_4:-1} }" \
            "%reg{1}"
    }
}

define-command edit-line-column -params 2 %{
    evaluate-commands -try-client %opt{jumpclient} %{
        edit -existing "%arg{1}" "%arg{2}" 

        try %{ focus }
    }
} -docstring "Like edit but understands file:line:col parameters"

define-command cargo-open-file %{

    evaluate-commands -save-regs fl %{

        execute-keys -draft "g" "h" "/" %opt{cargo_file_pattern} <ret> "<a-;>" ";T:" '"fy' 'llT:"ly'

	edit-line-column %reg{f} %reg{l}
    }
}

define-command cargo-next-error -docstring 'Jump to the next cargo error' %{
    try %{
        evaluate-commands -try-client %opt{jumpclient} %{
            set-register "b" %reg{/}
            set-register "/" %opt{cargo_error_pattern}
            execute-keys "n"
        }
    } catch %{
    	fail "No Cargo errors found"
    }
    set-register "/" %reg{b}
}

define-command cargo-previous-error -docstring 'Jump to the previous cargo error' %{
    try %{
        evaluate-commands -try-client %opt{jumpclient} %{
            set-register "b" %reg{/}
            set-register "/" %opt{cargo_error_pattern}
            execute-keys "<a-n>"
        }
    } catch %{
    	fail "No Cargo errors found"
    }
    set-register "/" %reg{b}
}

define-command cargo-run-example -docstring 'Run current buffer as example' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'cargo run --example ${filename%.*}' cargo"
    }
}

define-command cargo-run-example-release -docstring 'Run current buffer as example in release' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'cargo run --example ${filename%.*} --release' cargo"
    }
}

define-command cargo-run-run -docstring 'Run as "cargo run"' %{
    evaluate-commands %sh{
        echo "run-in-fifo 'cargo run' cargo"
    }
}
define-command cargo-run-run-release -docstring 'Run as "cargo run --release"' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %sh{
        echo "run-in-fifo 'cargo run --release' cargo"
    }
}

declare-user-mode cargo

map -docstring "Run" \
	global cargo r %{: cargo-run-run <ret>}
map -docstring "Run --release" \
	global cargo R %{: cargo-run-run-release <ret>}
map -docstring "Run tests" \
	global cargo t %{: run-in-fifo 'cargo test' cargo<ret>}
map -docstring "Run example" \
	global cargo e %{: cargo-run-example <ret>}
map -docstring "Run example --release" \
	global cargo E %{: cargo-run-example-release<ret>}
map -docstring "Check syntax" \
	global cargo c %{: run-in-fifo 'cargo check --all-targets'  cargo<ret>}
map -docstring "Build documentation" \
	global cargo d %{: run-in-fifo 'cargo doc' cargo<ret>}

