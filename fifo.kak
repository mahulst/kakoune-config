declare-option str last_command ''
declare-option str last_command_type ''

map -docstring "Rerun last fifo" \
	global user R %{: run-last-fifo <ret>}

define-command run-in-fifo -params 2 %{
    evaluate-commands %{
        write-all
    }
    set-option global last_command %arg{1}
    set-option global last_command_type %arg{2}

    evaluate-commands %sh{
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

define-command run-last-fifo -docstring 'Run last ran example' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %{
        run-in-fifo %opt{last_command} %opt{last_command_type}
    }
}

