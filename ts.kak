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


hook global WinSetOption filetype=(?!tsc).* %{
    unmap buffer normal <ret> %{: tsc-jump<ret>}
}

declare-option -docstring "regex describing tsc error references" \
    regex \
    tsc_error_pattern \
    "^((?:\w|\.|/|-)+\.\w+)\((\d+),\d+\):"

define-command -hidden tsc-jump %{
    evaluate-commands %{
        execute-keys "/" %opt{tsc_error_pattern} <ret>
        execute-keys <a-/> %opt{tsc_error_pattern} <ret><a-:> "<a-;>"

	    edit-line-column %reg{1} %reg{2}
    }
}
