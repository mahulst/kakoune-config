define-command compile-file-c -docstring 'Compile c file' %{
    evaluate-commands %{
        write-all
    }
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'gcc ${kak_buffile} -o ${filename%.*}' gcc"
    }
}

define-command run-compiled-file-c -docstring 'Run compiled c file' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo './${filename%.*}' exe"
    }
}
define-command compile-and-run-c -docstring 'Compile and run C file' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'gcc ${kak_buffile} -o ${filename%.*} && ./${filename%.*}' gcc"
    }
}
declare-user-mode cpp

map global user -docstring 'cpp' C ':enter-user-mode cpp<ret>'

map -docstring "Compile current file" \
	global cpp c %{: compile-file-c <ret>}

map -docstring "Run compiled file" \
	global cpp R %{: run-compiled-file-c <ret>}

map -docstring "Compile and run" \
	global cpp r %{: compile-and-run-c <ret> }




