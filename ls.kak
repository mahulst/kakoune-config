declare-option str ls_command ls
declare-option str-list ls_args -a -p -L
declare-option str ls_working_directory

define-command ls -params 0..1 %{
  ls_impl %sh{
    if [ "$#" -eq 0 ]
    then
      dirname "$kak_bufname"
    else
      printf '.'
    fi
  }
}

define-command -hidden ls_impl -params 1 %{
  evaluate-commands -save-regs '"' %{
    try %{
      delete-buffer '*ls*'
    }
    fifo %opt{ls_command} %opt{ls_args} %arg{1}
    rename-buffer '*ls*'
    set-option buffer filetype ls
    set-option buffer ls_working_directory %sh{
      realpath -- "$1"
    }
  }
}

complete-command ls file

add-highlighter shared/ls regex '^[^\n]*/$' 0:value

hook global BufCreate '\*ls\*' %{
  set-option buffer filetype ls
}

hook global BufSetOption filetype=ls %{
  add-highlighter buffer/ls ref ls
  map -docstring 'jump to files or directories' buffer normal <ret> ':jump_to_files_or_directories<ret>'
  map -docstring 'jump to files or directories and close ls buffer' buffer normal <s-ret> ':jump_to_files_or_directories_and_close_ls_buffer<ret>'
}

define-command -hidden jump_to_files_or_directories %{
  evaluate-commands -draft %{
    execute-keys 'x<a-s><a-K>^\n<ret>H'
    evaluate-commands -draft -verbatim try %{
      execute-keys '<a-,><a-K>/$<ret>'
      evaluate-commands -itersel %{
        evaluate-commands -draft -verbatim edit -existing -- "%opt{ls_working_directory}/%val{selection}"
      }
    }
    evaluate-commands -draft -verbatim try %{
      execute-keys ',<a-K>/$<ret>'
      evaluate-commands -client %val{client} -verbatim edit -existing -- "%opt{ls_working_directory}/%val{selection}"
    } catch %{
      evaluate-commands -client %val{client} -verbatim ls_impl "%opt{ls_working_directory}/%val{selection}"
    }
  }
}

define-command -hidden jump_to_files_or_directories_and_close_ls_buffer %{
  jump_to_files_or_directories
  delete-buffer '*ls*'
}


define-command fifo -params 1.. %{
  evaluate-commands %sh{
    fifo=$(mktemp -u)
    mkfifo "$fifo"
    { "$@" > "$fifo" 2>&1; } < /dev/null > /dev/null 2>&1 &
    cat <<EOF
      edit! -fifo "$fifo" -- "$fifo"
      hook -always -once buffer BufCloseFifo "" %{
        nop %sh{
          unlink "$fifo"
        }
      }
EOF
  }
}
map global user L ": ls<ret>" -docstring "Explore directory"

complete-command fifo shell

alias global ! fifo
