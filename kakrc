eval %sh{ kak-tree-sitter -dks --session $kak_session }

source ~/.config/kak/cargo.kak
source ~/.config/kak/kak-fetch.kak
source ~/.config/kak/git.kak
source ~/.config/kak/filetree.kak

# highlight column 120
add-highlighter global/hl-col-120 column 120 default,rgb:221823+d

colorscheme one-dark
set-option global ui_options terminal_enable_mouse=false

add-highlighter global/ number-lines -relative

define-command my-file-picker %{
  prompt -shell-script-candidates 'fd --type file' open: %{ edit -existing %val{text} }
}
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
map -docstring "Find file" global user f ':my-file-picker<ret>' 
map -docstring "Write all" global user s ':write-all<ret>' 
map global user '/' ':comment-line<ret>' -docstring 'comment line'
map global user y ':extra-yank-system<ret>'  -docstring 'yank to system clipboard'
map global user p ':extra-paste-system<ret>' -docstring 'paste from system clipboard'

# lsp
eval %sh{kak-lsp --kakoune -s $kak_session}  # Not needed if you load it with plug.kak.
hook global WinSetOption filetype=(rust|javascript|typescript|css|html) %{
    lsp-enable-window
}
map global user c %{:enter-user-mode lsp<ret>} -docstring "LSP mode"
map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'
map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
map global object e '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
map global object k '<a-semicolon>lsp-object Class Interface Struct<ret>' -docstring 'LSP class interface or struct'
map global object d '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
map global object D '<a-semicolon>lsp-diagnostic-object<ret>' -docstring 'LSP errors'
map global lsp k ':lsp-hover<ret>'                  -docstring 'hover'
map global lsp K ':lsp-hover-buffer<ret>'           -docstring 'hover in a dedicated buffer'

# window
declare-user-mode window
define-command tmux-split -params 1 -docstring 'split tmux pane' %{
  nop %sh{
    tmux split-window $1 kak -c $kak_session
  }
}

map global window -docstring 'select pane left' h %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -L}<ret>}
map global window -docstring 'select pane down' j %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -D}<ret>}
map global window -docstring 'select pane up' k %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -U}<ret>}
map global window -docstring 'select pane right' l %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -R}<ret>}
map global window -docstring 'zoom' z %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux resize-pane -Z}<ret>}
map global window -docstring 'split horizontal' <minus> ":tmux-split -v<ret>"
map global window -docstring 'split vertical' '|'  ":tmux-split -h<ret>"
map global window -docstring 'start ide' 'i'  ":ide <ret>"
map global window -docstring 'start ide' 'x'  ":close-ide <ret>"

map global user -docstring 'window mode' w ':enter-user-mode window<ret>'

# IDE command
define-command ide -params 0..1 %{
    try %{ rename-session %arg{1} }


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

map -docstring "Git" global user <g> \
    %{:enter-user-mode git<ret>}


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

unmap global normal m
declare-user-mode match-mode
map global match-mode i '<a-i>' -docstring "Match inside"
map global match-mode a '<a-a>' -docstring "Match around"
map global match-mode s ':enter-user-mode surround-add<ret>'  -docstring 'add surrounding pairs'
map global match-mode r ':surround-replace<ret>'              -docstring 'replace surrounding pairs'
map -docstring "Match" global normal <m> \
    %{:enter-user-mode match-mode<ret>}

