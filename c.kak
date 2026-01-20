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
        echo "run-in-fifo 'gcc -L. -I../inc ${kak_buffile} -o ${filename%.*} && ./${filename%.*}' gcc"
    }
}

define-command compile-and-run-c-with-make -docstring 'Compile and run C file' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'make -B && make run' gcc"
    }
}

define-command flash-to-board -docstring 'Flash output.bin to board' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'st-flash  --reset write output.bin 0x08000000' stlink"
    }
}

define-command bear-make -docstring 'Bear -- make' %{
    evaluate-commands %sh{
        echo "run-in-fifo 'bear -- make -B' gcc"
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

map -docstring "Make and run" \
	global cpp m %{: compile-and-run-c-with-make <ret> }

map -docstring "Flash" \
	global cpp f %{: flash-to-board <ret> }

map -docstring "Generate compile-commands (bear)" \
	global cpp b %{: bear-make <ret> }




