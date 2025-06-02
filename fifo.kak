declare-option str last_command ''
declare-option str last_command_type ''

declare-option -docstring "regex describing format in which fifos are saved" \
    regex \
    fifo_list_item \
    "^(.*) \^\|\^ (.*)\n"

map -docstring "Rerun last fifo" \
	global user R %{: run-last-fifo <ret>}

map -docstring "See all fifo commands in this repo" \
	global user F %{: open-last-fifos <ret>}

define-command run-in-fifo -params 2..3 %{
    evaluate-commands %{
        write-all
    }
    set-option global last_command %arg{1}
    set-option global last_command_type %arg{2}

    evaluate-commands %sh{
        rootdir="$(git rev-parse --show-toplevel)"
        last_fifos_file="$rootdir/.kakoune-fifo.list"
        [[ -f "$last_fifos_file" ]] || touch "$last_fifos_file"
        if [ -z "$3" ]; then
            # Write everything you run in a list to rerun later
            echo "$1 ^|^ $2" >> "$last_fifos_file"

            # Clean duplicates from list
            awk '!seen[$0]++' "$last_fifos_file" > "${last_fifos_file}.tmp" \
              && mv "${last_fifos_file}.tmp" "$last_fifos_file"
        fi
        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-fifo.XXXXXXXX)/fifo
        mkfifo ${output}
        ( eval $1 > ${output} 2>&1 ) > /dev/null 2>&1 < /dev/null &

        printf %s\\n "
            evaluate-commands -try-client '$kak_opt_toolsclient' %{
               write-all
               edit! -fifo ${output} -scroll *compilation*
               set-option buffer filetype $2
               hook -once buffer BufCloseFifo .* %{
                   nop %sh{ rm -r $(dirname ${output}) }
                   evaluate-commands -try-client '$kak_client' %{
                       echo -- Completed $*
                   }
               }
           }
        "
    }
}
define-command open-last-fifos %{
    edit %sh{
        rootdir="$(git rev-parse --show-toplevel)"
        last_fifos_file="$rootdir/.kakoune-fifo.list"
        [[ -f "$last_fifos_file" ]] || touch "$last_fifos_file"
        printf "$last_fifos_file\n"
    }
    set buffer autoreload true
    set-option buffer filetype last-fifo-list
}

hook global WinSetOption filetype=last-fifo-list %{
    map -docstring "Jump to position" buffer normal <ret> %{: run-from-last-fifo-list<ret>}
}

hook global WinSetOption filetype=(?!last-fifo-list).* %{
    unmap buffer normal <ret> %{: run-from-last-fifo-list<ret>}
}

define-command run-from-last-fifo-list %{
    execute-keys "gh"
    set-register "b" %reg{/}
    set-register "/" %opt{fifo_list_item}
    execute-keys "<n>"

    set-register "/" %reg{b}
    run-in-fifo  %reg{1} %reg{2} true

}
define-command run-last-fifo -docstring 'Run last ran example' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %{
        run-in-fifo %opt{last_command} %opt{last_command_type} true
    }
}


