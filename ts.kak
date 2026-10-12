declare-user-mode ts
map -docstring "Run eslint" global ts e %{: run-eslint<ret>}
map -docstring "Run tsc" global ts t %{: run-tsc<ret>}

map -docstring "Run jest" global user <t> \
    %{:enter-user-mode ts<ret>}

define-command run-eslint %{
    evaluate-commands %{
        run-in-fifo 'npx eslint "./**/*.{js,jsx,ts,tsx}"' grep
    }
}

define-command run-tsc %{
    evaluate-commands %{
        run-in-fifo 'npx tsc --noEmit' tsc
    }
}


hook global WinSetOption filetype=tsc %{
    map -docstring "Jump to current error" buffer normal <ret> %{: tsc-jump<ret>}
}

hook global WinSetOption filetype=tsc-moon %{
    map -docstring "Jump to current moon tsc error" buffer normal <ret> %{: tsc-moon-jump<ret>}
}


hook global WinSetOption filetype=(?!tsc).* %{
    unmap buffer normal <ret> %{: tsc-jump<ret>}
}

hook global WinSetOption filetype=(?!tsc-moon).* %{
    unmap buffer normal <ret> %{: tsc-moon-jump<ret>}
}

declare-option -docstring "regex describing tsc error references" \
    regex \
    tsc_error_pattern \
    "^((?:\w|\.|/|-)+\.\w+)\((\d+),\d+\):"

declare-option -docstring "regex describing moon tsc error references" \
    regex \
    tsc_moon_error_pattern \
    "^[^|\n]+\|\h*((?:\w|\.|/|-)+\.\w+)\((\d+),\d+\):"

declare-option -docstring "regex describing moon tsc working directory lines" \
    regex \
    tsc_moon_run_dir_pattern \
    "\(in\h+([^\)\n]+)\)\h*$"

define-command -hidden tsc-jump %{
    evaluate-commands %{
        execute-keys "/" %opt{tsc_error_pattern} <ret>
        execute-keys <a-/> %opt{tsc_error_pattern} <ret><a-:> "<a-;>"

        edit-line-column %reg{1} %reg{2}
    }
}

define-command -hidden tsc-moon-jump %{
    evaluate-commands -save-regs bflr/ %{
        set-register "b" %reg{/}
        set-register "r" ""

        set-register "/" %opt{tsc_moon_error_pattern}
        execute-keys "n"
        execute-keys <a-/> %opt{tsc_moon_error_pattern} <ret><a-:> "<a-;>"

        set-register "f" %reg{1}
        set-register "l" %reg{2}

        try %{
            set-register "/" %opt{tsc_moon_run_dir_pattern}
            execute-keys <a-/> %opt{tsc_moon_run_dir_pattern} <ret><a-:> "<a-;>"
            set-register "r" %reg{1}
        }

        set-register "/" %reg{b}

        evaluate-commands %sh{
            file="$kak_reg_f"
            line="$kak_reg_l"
            run_dir="$kak_reg_r"

            if [ -n "$run_dir" ]; then
                case "$file" in
                    /*) target="$file" ;;
                    *) target="$run_dir/$file" ;;
                esac
            else
                target="$file"
            fi

            escaped_target=${target//\'/\'\"\'\"\'}
            printf "edit-line-column '%s' '%s'\n" "$escaped_target" "$line"
        }
    }
}
