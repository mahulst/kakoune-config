eval %sh{ kak-tree-sitter -dks --session $kak_session }

source ~/.config/kak/cargo.kak
source ~/.config/kak/kak-fetch.kak
source ~/.config/kak/git.kak

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

# window
declare-user-mode window
map global window -docstring 'select pane left' h %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -L}<ret>}
map global window -docstring 'select pane down' j %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -D}<ret>}
map global window -docstring 'select pane up' k %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -U}<ret>}
map global window -docstring 'select pane right' l %{:nop %sh{TMUX="${kak_client_env_TMUX}" tmux select-pane -R}<ret>}
map global user -docstring 'window mode' w ':enter-user-mode window<ret>'

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
            tmux select-layout tiled
            tmux resize-pane -t 0 -y 90
            tmux resize-pane -t 1 -x 140
            tmux select-pane -t 0
            tmux move-pane -s 3 -t 1
            tmux resize-pane -t 2 -y 20
            tmux select-pane -t 0
        fi
    }

}

map -docstring "Ruhn commands" global user <r> \
    %{:enter-user-mode cargo<ret>}


