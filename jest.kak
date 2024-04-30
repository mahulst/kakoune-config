declare-option -docstring "regex describing file paths and line numbers" \
    regex \
    jest_file_pattern \
    "(\w|\.|/)+:\d+:\d+"
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient
# declare-option -hidden int cargo_current_error_line
declare-option -hidden str jest_workspace_root

define-command -params .. \
    -docstring %{jest [<arguments>]: jest utility wrapper
All the optional arguments are forwarded to the jest utility} \
    jest  %{
    evaluate-commands %sh{
        workspace_root=$(
            file_path="$kak_buffile"
            dir=$(dirname "$file_path")

            while [[ "$dir" != '/' && ! -f "$dir/package.json" ]]; do
              dir=$(dirname "$dir")
            done

            echo $dir
        )

        quoted_workspace_root="'""$(
            printf %s "$workspace_root" |
            sed -e "s/'/''/g"
        )""/'"

        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-jest.XXXXXXXX)/fifo

mkfifo ${output}
        ( eval npm run test  "$@" > ${output} 2>&1 ) > /dev/null 2>&1 < /dev/null &

        printf %s\\n "
            evaluate-commands -try-client '$kak_opt_toolsclient' %{
               write-all

               edit! -fifo ${output} -scroll *jest*
               set-option buffer filetype jest
               # set-option buffer cargo_current_error_line 1
               set-option buffer jest_workspace_root $quoted_workspace_root
               hook -once buffer BufCloseFifo .* %{
                   nop %sh{ rm -r $(dirname ${output}) }
                   evaluate-commands -try-client '$kak_client' %{
                       echo -- Completed jest $*
                   }
               }
           }
        "
    }
}

# add-highlighter shared/cargo group
# add-highlighter shared/cargo/ regex "^(error(?:\[[A-Z0-9]+\])?:)" 1:red
# add-highlighter shared/cargo/ regex "^(warning(?:\[[A-Z0-9]+\])?:)" 1:yellow
# add-highlighter shared/cargo/ regex "^(note(?:\[[A-Z0-9]+\])?:)" 1:green
# add-highlighter shared/cargo/ regex "^ +\|[ |]+(-+[^\n]*)$" 1:cyan
# add-highlighter shared/cargo/ regex "^ +\|[ |]+(\^+[^\n]*)$" 1:red
# add-highlighter shared/cargo/ line '%opt{cargo_current_error_line}' default+b

# hook -group cargo-highlight global WinSetOption filetype=cargo %{
#     add-highlighter window/cargo ref cargo
# }

hook global WinSetOption filetype=jest %{
    #hook buffer -group cargo-hooks NormalKey <ret> cargo-jump
    map -docstring "Jump to current error" buffer normal <ret> %{: jest-jump<ret>}
    map -docstring "Jump to file on current line" buffer user "f" %{: jest-open-file<ret>}
}

# hook -group cargo-highlight global WinSetOption filetype=(?!cargo).* %{
#     remove-highlighter window/cargo
# }

hook global WinSetOption filetype=(?!jest).* %{
    #remove-hooks buffer cargo-hooks
    unmap buffer normal <ret> %{: jest-jump<ret>}
    unmap buffer user f %{: jest-open-file<ret>}
}

declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient


define-command -hidden jest-jump %{
    evaluate-commands %{
        # We may be in the middle of an error.
        # To find it, we search for the next error
        # (which definitely moves us past the end of this error)
        # and then search backward
        # execute-keys "/" %opt{cargo_error_pattern} <ret>
        # execute-keys <a-/> %opt{cargo_error_pattern} <ret><a-:> "<a-;>"

        # # We found a Cargo error, let's open it.
        # set-option buffer cargo_current_error_line "%val{cursor_line}"
        # cargo-open-error \
        #     "%opt{cargo_workspace_root}%reg{2}" \
        #     "%reg{3}" \
        #     "%sh{ echo ${kak_main_reg_4:-1} }" \
        #     "%reg{1}"
    }
}



define-command jest-open-file %{
    evaluate-commands -save-regs fl %{

        execute-keys -draft "g" "h" "/" %opt{jest_file_pattern} <ret> "<a-;>" ";T:" '"fy' 'llT:"ly'

	edit-line-column %reg{f} %reg{l}
    }
}


define-command jest-run-file -docstring 'Run current buffer as jest test' %{
    evaluate-commands %{
        write-all
        set-register e %sh{
            filename=$(basename "$kak_buffile")
            echo "${filename%.*}"
        } 
    }

    evaluate-commands %{
        jest %reg{e}
    }
}

define-command jest-run-last-test -docstring 'Run last ran example' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %{
        jest %reg{e}
    }
}
define-command jest-run-all -docstring 'Run all tests' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %{
        jest 
    }
}

declare-user-mode jest

map -docstring "Run last test" \
	global jest r %{: jest-run-last-test  <ret>}
map -docstring "Run all test" \
	global jest t %{: jest-run-all  <ret>}
map -docstring "Run test" \
	global jest f %{: jest-run-file <ret>}

