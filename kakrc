eval %sh{ kak-tree-sitter -dks --init "$kak_session" --with-highlighting --with-text-objects -vvvvv }

hook global WinSetOption filetype %{
    echo -debug "Filetype changed to: %val{filetype}"
}
map global user d ':buffer *debug* <ret>' -docstring 'open debug buffer'

hook -group lsp-language-id global BufCreate .*[.]tsx %{
    hook -group lsp-language-id buffer BufSetOption filetype=typescript %{
        echo -debug "poop"
        set-option buffer lsp_language_id typescriptreact
    }
}
hook global BufSetOption kts_lang=(javascript|typescript) %{
  eval %sh{
    case $kak_bufname in
      (*\.jsx) echo "set-option buffer kts_lang jsx";;
      (*\.tsx) echo "set-option buffer kts_lang tsx";;
    esac
  }
}

set-face global CursorLine "default,rgba:77777720"
define-command ui-cursorline-enable -docstring 'enable cursor line' %{
    add-highlighter window/cursorline line %val{cursor_line} CursorLine
    hook window -group ui-cursorline RawKey .* %{
        remove-highlighter window/cursorline
        add-highlighter window/cursorline line %val{cursor_line} CursorLine
    }
    echo -markup "{Information}cursor line enabled"
}

hook global WinCreate .* %{
    ui-cursorline-enable 
}
map -docstring "next" global prompt "<c-n>" "<tab>"
map -docstring "prev" global prompt "<c-p>" "<s-tab>"
map -docstring "select" global prompt "<c-y>" "<ret>"

map -docstring "backspace" global prompt "<backspace>" "<left><del>"

hook global BufSetOption kts_lang=(javascript|typescript) %{
  eval %sh{
    case $kak_bufname in
      (*\.jsx) echo "set-option buffer kts_lang jsx";;
      (*\.tsx) echo "set-option buffer kts_lang tsx";;
    esac
  }
}
# Debugging face colors
declare-option range-specs face_colors

define-command color-faces %{
    buffer *debug*
    debug faces
    try %{ remove-highlighter buffer/face-colors }
    set-option buffer face_colors %val{timestamp}

    evaluate-commands -draft %{
        execute-keys '%' s^Faces:\n(<space>\*<space>[^\n]*\n)*<ret>
        execute-keys s ^<space>\*<space><ret>
        execute-keys lt:

        evaluate-commands -itersel %{
            eval %sh{
                printf "set-option -add buffer face_colors %s|%s\n" \
                "$kak_selection_desc" "$kak_selection"
            }
        }
    }

    add-highlighter buffer/face-colors ranges face_colors
}
evaluate-commands %sh{kak-popup init}
source ~/.config/kak/fifo.kak
source ~/.config/kak/switch-case.kak
source ~/.config/kak/servers.kak
source ~/.config/kak/cargo.kak
source ~/.config/kak/ls.kak
source ~/.config/kak/ts.kak
source ~/.config/kak/yank.kak
source ~/.config/kak/harpoon.kak
source ~/.config/kak/snippet.kak
source ~/.config/kak/buffer.kak
source ~/.config/kak/symbol.kak
source ~/.config/kak/kaktree/rc/kaktree.kak
source ~/.config/kak/clipboard.kak
source ~/.config/kak/web.kak
source ~/.config/kak/git.kak
source ~/.config/kak/jest.kak
source ~/.config/kak/c.kak
source ~/.config/kak/godot.kak
source ~/.config/kak/tab.kak
source ~/.config/kak/fzf/rc/fzf.kak
source ~/.config/kak/fzf/rc/modules/fzf-cd.kak  
source ~/.config/kak/fzf/rc/modules/fzf-file.kak  
source ~/.config/kak/fzf/rc/modules/fzf-buffer.kak  
source ~/.config/kak/fzf/rc/modules/fzf-grep.kak  
source ~/.config/kak/fzf/rc/modules/fzf-project.kak  
source ~/.config/kak/fzf/rc/modules/fzf-search.kak
hook global BufOpenFile .* expandtab
hook global BufNewFile  .* expandtab
hook global WinCreate .* %{ kakboard-enable }
hook global WinSetOption filetype=kaktree %{
    remove-highlighter buffer/numbers
    remove-highlighter buffer/matching
    remove-highlighter buffer/wrap
    remove-highlighter buffer/show-whitespaces
}
kaktree-enable
map global user T ':kaktree--display<ret>'  -docstring 'display file tree'
# buffer mappings
map global user l ": recent-buffers-pick-link<ret>" -docstring "recent buffers"
set-face global HiddenSelection 'white,bright-red+F'
# add docstring for html tags
map -docstring 'tag' global object t 'c<lt>\w[\w-]*\h*[^<gt>]*?(?<lt>!/)<gt>,<lt>/\w[\w-]*(?<lt>!/)<gt><ret>'
declare-option range-specs hidden_selections_indicator_ranges
declare-option str hidden_selections_above_and_below_indicator '●'
declare-option str hidden_selections_above_indicator '▲'
declare-option str hidden_selections_below_indicator '▼'

# Add cursor when extra selections are outside of screen
define-command update_hidden_selections_indicator_ranges %{
  set-option window hidden_selections_indicator_ranges %val{timestamp}

  try %{
    # Determine multiple selections.
    execute-keys -draft '<a-,>'

    try %{
      # Determine hidden selections above and below.
      execute-keys -draft -save-regs '^tb' 'Zgt"tZgbx;"bZe"tzb"tz"b<a-z>u<a-z>a<a-,>'
      set-option -add window hidden_selections_indicator_ranges "%val{cursor_line}.%val{cursor_char_column}+1|{HiddenSelection}%opt{hidden_selections_above_and_below_indicator}"
    } catch %{
      # Determine hidden selections above.
      execute-keys -draft -save-regs '^t' 'Zgt"tZb"tzGe<a-z>a<a-,>'
      set-option -add window hidden_selections_indicator_ranges "%val{cursor_line}.%val{cursor_char_column}+1|{HiddenSelection}%opt{hidden_selections_above_indicator}"
    } catch %{
      # Determine hidden selections below.
      execute-keys -draft -save-regs '^b' 'Zgbx;"bZe"bzGg<a-z>a<a-,>'
      set-option -add window hidden_selections_indicator_ranges "%val{cursor_line}.%val{cursor_char_column}+1|{HiddenSelection}%opt{hidden_selections_below_indicator}"
    } catch %{
    }
  }
}

define-command sequence %{

    execute-keys '10<plus>i,<space><c-r>#<esc>'
}
hook global NormalIdle '' update_hidden_selections_indicator_ranges
hook global InsertIdle '' update_hidden_selections_indicator_ranges
hook global PromptIdle '' update_hidden_selections_indicator_ranges

# add-highlighter global/hidden_selections_indicator ref hidden_selections_indicator_ranges
add-highlighter global/hidden_selections_indicator replace-ranges hidden_selections_indicator_ranges #remove duplicate cursors with esc 
map global normal <esc> ';,'

colorscheme catppuccin_macchiato
set-option global ui_options terminal_enable_mouse=false

add-highlighter global/ number-lines -relative

declare-option str extra_yank_system_clipboard_cmd %sh{
  test "$(uname)" = "Darwin" && echo 'pbcopy' || echo 'xclip'
}

declare-option str extra_paste_system_clipboard_cmd %sh{
 test "$(uname)" = "Darwin" && echo 'pbpaste' || echo 'xsel -ob'
}
define-command extra-yank-system -docstring 'yank into the system clipboard' %{
  execute-keys -draft "<a-!>%opt{extra_yank_system_clipboard_cmd}<ret>"
}

define-command extra-paste-system -docstring 'paste from the system clipboard' %{
  execute-keys -draft "!%opt{extra_paste_system_clipboard_cmd}<ret>"
}
map -docstring "Find " global user f ':fzf-mode<ret>' 
map -docstring "Write all" global user s ':write-all<ret>' 
map global user '/' ':comment-line<ret>' -docstring 'comment line'


# lsp
eval %sh{kak-lsp --kakoune -s $kak_session}  # Not needed if you load it with plug.kak.
# set global lsp_debug true
lsp-enable
declare-option -hidden str modeline_progress ""
define-command -hidden -params 6 -override lsp-handle-progress %{
    set global modeline_progress %sh{
        if ! "$6"; then
            echo "$2${5:+" ($5%)"}${4:+": $4"}"
        fi
    }
}


set global modelinefmt "%%opt{modeline_progress} %opt{modelinefmt}"
hook global WinSetOption filetype=(rust|javascript|nix|typescript|json|tsx|css|html) %{
    echo -debug %opt{filetype}
    lsp-enable-window
}
# define-command prettier -docstring 'run prettier over current file' %{
#     nop %sh{ npx prettier --write %val{buffile}}
# }

hook global WinSetOption filetype=(rust) %{
    #remove-hooks buffer cargo-hooks
    unmap global lsp f ":format <ret>"
    map global lsp f ":lsp-formatting <ret>" -docstring "format using lsp"
}

hook global WinSetOption filetype=(javascript|typescript|tsx|json|html) %{
  set-option window formatcmd "npx prettier --stdin-filepath=%val{buffile}"

  map global lsp f ":format <ret>" -docstring "format prettier"
}
map global user c %{:enter-user-mode lsp<ret>} -docstring "LSP mode"
map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'
map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
map global object e '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
map global object k '<a-semicolon>lsp-object Class Interface Struct<ret>' -docstring 'LSP class interface or struct'
map global object d '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
map global object D '<a-semicolon>lsp-diagnostic-object<ret>' -docstring 'LSP errors'
map global lsp K ':lsp-hover<ret>'                  -docstring 'hover'
map global lsp k ':lsp-hover-buffer<ret>'           -docstring 'hover in a dedicated buffer'

# window
declare-user-mode window
define-command tmux-split -params 2 -docstring 'split tmux pane' %{
    nop %sh{
        tmux split-window $1 kak -c "$kak_session" 
    }
}

map global window -docstring 'select pane left' h %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -L}<ret>}
map global window -docstring 'select pane down' j %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -D}<ret>}
map global window -docstring 'select pane up' k %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -U}<ret>}
map global window -docstring 'select pane right' l %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -R}<ret>}
map global window -docstring 'zoom' z %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux resize-pane -Z}<ret>}
map global window -docstring 'split horizontal' <minus> ":tmux-split -v new<ret>"
map global window -docstring 'split vertical' '|'  ":tmux-split -h new<ret>"
map global window -docstring 'start ide' 'i'  ":ide <ret>"
map global window -docstring 'close ide' 'x'  ":close-ide <ret>"

map global user -docstring 'window mode' w ':enter-user-mode window<ret>'

# IDE command
 
declare-option bool is_in_ide_mode 'false'
define-command ide  %{
    evaluate-commands %sh{
        if [ "$kak_opt_is_in_ide_mode" = "false" ]; then
            echo "echo 'Switching to ide'"
       else 
            echo "fail 'Already in ide mode'"
      fi
    }
    set-option global is_in_ide_mode 'true'


    set-option local windowing_placement horizontal;
    rename-client main
    set-option global jumpclient main

    new rename-client tools
    set-option global toolsclient tools

    new rename-client docs
    set-option global docsclient docs

    nop %sh{
        if [[ -n $TMUX ]]; then
            tmux select-layout main-vertical
            tmux swap-pane -s 3 -t 1
            tmux swap-pane -s 3 -t 2
            tmux resize-pane -t 2 -y 70%
            tmux select-pane -t 2
        fi
    }

}

define-command close-ide %{
    evaluate-commands -try-client %opt{toolsclient} %{
        quit
    }
    evaluate-commands -try-client %opt{docsclient} %{
        quit
    }
    evaluate-commands -try-client %opt{jumpclient} %{
        quit
    }
}

map -docstring "Run commands" global user <r> \
    %{:enter-user-mode cargo<ret>}

map -docstring "Run jest" global user <j> \
    %{:enter-user-mode jest<ret>}

define-command -override add-surrounding-pair -params 2 -docstring 'add surrounding pairs left and right to selection' %{
  evaluate-commands -no-hooks -save-regs '"' %{
    set-register '"' %arg{1}
    execute-keys -draft P
    set-register '"' %arg{2}
    execute-keys -draft p
  }
}

define-command surround-replace -docstring 'prompt for a surrounding pair and replace it with another' %{
  on-key %{
    surround-replace-sub %val{key}
  }
}

define-command -hidden surround-replace-sub -params 1 %{
	on-key %{
            evaluate-commands -no-hooks -draft %{
              execute-keys "<a-a>%arg{1}"

              # select the surrounding pair and add the new one around it
              enter-user-mode surround-add
              execute-keys %val{key}
            }

            # delete the old one
            match-delete-surround-key %arg{1}
	}
}

define-command -hidden match-delete-surround-key -params 1 %{
  execute-keys -draft "<a-a>%arg{1}i<del><esc>a<backspace><esc>"
}

declare-user-mode surround-add
map global surround-add "'" ":add-surrounding-pair ""'"" ""'""<ret>" -docstring 'surround selections with quotes'
map global surround-add ' ' ':add-surrounding-pair " " " "<ret>'     -docstring 'surround selections with pipes'
map global surround-add '"' ':add-surrounding-pair ''"'' ''"''<ret>' -docstring 'surround selections with double quotes'
map global surround-add '(' ':add-surrounding-pair ( )<ret>'         -docstring 'surround selections with curved brackets'
map global surround-add ')' ':add-surrounding-pair ( )<ret>'         -docstring 'surround selections with curved brackets'
map global surround-add '*' ':add-surrounding-pair * *<ret>'         -docstring 'surround selections with stars'
map global surround-add '<' ':add-surrounding-pair <lt> <gt><ret>'   -docstring 'surround selections with chevrons'
map global surround-add '>' ':add-surrounding-pair <lt> <gt><ret>'   -docstring 'surround selections with chevrons'
map global surround-add '[' ':add-surrounding-pair [ ]<ret>'         -docstring 'surround selections with square brackets'
map global surround-add ']' ':add-surrounding-pair [ ]<ret>'         -docstring 'surround selections with square brackets'
map global surround-add '_' ':add-surrounding-pair "_" "_"<ret>'     -docstring 'surround selections with underscores'
map global surround-add '{' ':add-surrounding-pair { }<ret>'         -docstring 'surround selections with angle brackets'
map global surround-add '|' ':add-surrounding-pair | |<ret>'         -docstring 'surround selections with pipes'
map global surround-add '}' ':add-surrounding-pair { }<ret>'         -docstring 'surround selections with angle brackets'
map global surround-add '«' ':add-surrounding-pair « »<ret>'         -docstring 'surround selections with French chevrons'
map global surround-add '»' ':add-surrounding-pair « »<ret>'         -docstring 'surround selections with French chevrons'
map global surround-add '“' ':add-surrounding-pair “ ”<ret>'         -docstring 'surround selections with French chevrons'
map global surround-add '”' ':add-surrounding-pair “ ”<ret>'         -docstring 'surround selections with French chevrons'
map global surround-add ` ':add-surrounding-pair ` `<ret>'           -docstring 'surround selections with ticks'

define-command text-object-indented-paragraph %{
  execute-keys -draft -save-regs '' '<a-i>pZ'
  execute-keys '<a-i>i<a-z>i'
}

unmap global normal m
declare-user-mode match-mode
map global match-mode i '<a-i>' -docstring "Match inside"
map global match-mode b ':text-object-indented-paragraph <ret>' -docstring "Match inside indented block"
map global match-mode a '<a-a>' -docstring "Match around"
map global match-mode m 'M' -docstring "Match matching symbol"
map global match-mode s ':enter-user-mode surround-add<ret>'  -docstring 'add surrounding pairs'
map global match-mode r ':surround-replace<ret>'              -docstring 'replace surrounding pairs'
map -docstring "Match" global normal <m> \
    %{:enter-user-mode match-mode<ret>}


# scratch files
declare-user-mode scratch

map -docstring "Scratch file" global user e  %{:enter-user-mode scratch<ret>}

map -docstring "JSON" global scratch j %{
    evaluate-commands %sh {
      echo ":edit /tmp/json_scratch_$(mktemp --dry-run XXXXXX).json <ret>"
      echo ":set buffer filetype json <ret>"
    }
}
