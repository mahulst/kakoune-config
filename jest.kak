declare-option -docstring "regex describing file paths and line numbers" \
    regex \
    jest_file_pattern \
    "((?:\w|\.|/)+\.\w+)(?::(\d+):(\d+)|$)"
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient
# declare-option -hidden int cargo_current_error_line
declare-option -hidden str jest_workspace_root

hook global WinSetOption filetype=jest %{
    #hook buffer -group cargo-hooks NormalKey <ret> cargo-jump
    map -docstring "Jump to current error" buffer normal <ret> %{: jest-open-file<ret>}
    map -docstring "Jump to current error" buffer normal n %{: jest-next-error<ret>}
}

add-highlighter shared/jest group
add-highlighter shared/jest/ regex "(^FAIL) " 1:red
add-highlighter shared/jest/ regex "(^PASS) " 1:green

hook -group jest-highlight global WinSetOption filetype=jest %{
    add-highlighter window/jest ref jest
}

hook global WinSetOption filetype=(?!jest).* %{
    unmap buffer normal <ret> %{: jest-open-file<ret>}
}

declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient

define-command jest-next-error %{
    try %{
        set-register "b" %reg{/}
        set-register "/" "FAIL "
        execute-keys "n"
    } catch %{
    	fail "No failed tests found"
    }
    set-register "/" %reg{b}
}
define-command jest-open-file %{
    evaluate-commands -save-regs fl %{

        set-register "b" %reg{/}
        set-register "/" %opt{jest_file_pattern}
        execute-keys "n"

        set-register "/" %reg{b}
	    edit-line-column %reg{1} %reg{2}
    }
}


define-command jest-run-file -docstring 'Run current buffer as jest test' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'DEBUG_PRINT_LIMIT=100000 COLORS=false npx jest -- ${filename%.*}' jest"
    } 
}


define-command jest-run-all -docstring 'Run all tests' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %{
        run-in-fifo 'DEBUG_PRINT_LIMIT=100000 COLORS=false npx jest' jest
    }
}

declare-user-mode jest

map -docstring "Run all test" \
	global jest t %{: jest-run-all  <ret>}
map -docstring "Run test" \
	global jest f %{: jest-run-file <ret>}

