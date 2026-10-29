# eval %sh{ kak-tree-sitter -dks --init "$kak_session" --with-highlighting --with-text-objects -vvvvv }
hook global WinSetOption filetype %{
    echo -debug "Filetype changed to: %val{filetype}"
}
map global user D ':buffer *debug* <ret>' -docstring 'open debug buffer'

hook -group lsp-language-id global BufCreate .*[.]tsx %{
    hook -group lsp-language-id buffer BufSetOption filetype=typescript %{
        set-option buffer lsp_language_id typescriptreact
    }
}
set-option global grepcmd 'rg -Hn --no-heading --hidden'

hook global BufOpenFile .*\.vue$ %{
    set-option buffer filetype vue
    set-option buffer lsp_language_id vue
}

hook global BufSetOption kts_lang=(javascript|typescript) %{
  eval %sh{
    case $kak_bufname in
      (*\.jsx) echo "set-option buffer kts_lang jsx";;
      (*\.tsx) echo "set-option buffer kts_lang tsx";;
    esac
  }
}

map global goto d <esc>:lsp-definition<ret> -docstring 'LSP definition'
map global goto r <esc>:lsp-references<ret> -docstring 'LSP references'
map global goto y <esc>:lsp-type-definition<ret> -docstring 'LSP type definition'

set-face global CursorLine "default,rgba:77777720"
define-command ui-cursorline-enable -docstring 'enable cursor line' %{
    add-highlighter window/cursorline line %val{cursor_line} CursorLine
    hook window -group ui-cursorline RawKey .* %{
        remove-highlighter window/cursorline
        add-highlighter window/cursorline line %val{cursor_line} CursorLine
    }
    echo -markup "{Information}cursor line enabled"
}
hook global WinSetOption filetype=vue %{
    require-module html
    add-highlighter window/vue ref html
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
source ~/.config/kak/fifo.kak
source ~/.config/kak/switch-case.kak
source ~/.config/kak/servers.kak
source ~/.config/kak/cargo.kak
source ~/.config/kak/ls.kak
source ~/.config/kak/ts.kak
source ~/.config/kak/moon.kak
source ~/.config/kak/odin.kak
source ~/.config/kak/yank.kak
source ~/.config/kak/harpoon.kak
source ~/.config/kak/snippet.kak
source ~/.config/kak/buffer.kak
source ~/.config/kak/kaktree/rc/kaktree.kak
source ~/.config/kak/clipboard.kak
source ~/.config/kak/web.kak
source ~/.config/kak/git.kak
source ~/.config/kak/git-shell.kak
source ~/.config/kak/git-commit.kak
source ~/.config/kak/git-status.kak
require-module git-status
source ~/.config/kak/jest.kak
source ~/.config/kak/c.kak
source ~/.config/kak/godot.kak
source ~/.config/kak/grep.kak
source ~/.config/kak/tab.kak
source ~/.config/kak/fzf/rc/fzf.kak
source ~/.config/kak/fzf/rc/modules/fzf-cd.kak  
source ~/.config/kak/fzf/rc/modules/fzf-file.kak  
source ~/.config/kak/fzf/rc/modules/fzf-buffer.kak  
source ~/.config/kak/fzf/rc/modules/fzf-grep.kak  
source ~/.config/kak/fzf/rc/modules/fzf-project.kak  
source ~/.config/kak/fzf/rc/modules/fzf-search.kak
source ~/.config/kak/jai.kak
source ~/.config/kak/tasks.kak
source ~/.config/kak/timesheet.kak
source ~/.config/kak/http.kak
source ~/.config/kak/hunk.kak
source ~/.config/kak/hypr.kak
source ~/.config/kak/kitty.kak
source ~/.config/kak/vue.kak
source ~/.config/kak/agentwatch.kak
hook global WinCreate .* %{ kakboard-enable }
hook global WinSetOption filetype=kaktree %{
    remove-highlighter buffer/numbers
    remove-highlighter buffer/matching
    remove-highlighter buffer/wrap
    remove-highlighter buffer/show-whitespaces
}
# Require the module up front: requiring it inside kaktree-enable corrupts the
# rest of that command's body on newer Kakoune ("kaktree--enablP: no such command")
require-module kaktree
kaktree-enable
define-command -override kaktree-toggle %{
    evaluate-commands %sh{
        # If the kaktree client already exists (e.g. IDE mode), display there.
        # Otherwise take over the current window: point kaktreeclient at the
        # current client so the tree opens in place instead of a new pane.
        if printf '%s\n' "$kak_client_list" | grep -qw "$kak_opt_kaktreeclient"; then
            echo "kaktree--display"
        else
            echo "set-option global kaktree__jumpclient %val{client}"
            echo "set-option global kaktreeclient %val{client}"
            echo "kaktree--display"
        fi
    }
}
map global user T ':kaktree-toggle<ret>'  -docstring 'display file tree'
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

define-command duplicate-line -docstring 'duplicate current line(s) without touching registers' %{
    echo -debug "duplicate-line fired"
    execute-keys -save-regs 'z' 'x"zy;"zp'
}
map global user d ':duplicate-line<ret>' -docstring 'duplicate line'

colorscheme catppuccin_macchiato
set-option global ui_options terminal_enable_mouse=false

add-highlighter global/ number-lines -relative -separator '  ' -min-digits 3

declare-option str extra_yank_system_clipboard_cmd %sh{
  if [ "$(uname)" = "Darwin" ]; then echo 'pbcopy'
  elif [ -n "$WAYLAND_DISPLAY" ]; then echo 'wl-copy >/dev/null 2>&1'
  else echo 'xclip -selection clipboard'
  fi
}

declare-option str extra_paste_system_clipboard_cmd %sh{
  if [ "$(uname)" = "Darwin" ]; then echo 'pbpaste'
  elif [ -n "$WAYLAND_DISPLAY" ]; then echo 'wl-paste -n'
  else echo 'xsel -ob'
  fi
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
hook global WinSetOption filetype=(vue|rust|javascript|nix|typescript|json|tsx|css|html) %{
    echo -debug %opt{filetype}
    lsp-enable-window
}

define-command prettier -docstring 'run prettier over current file' %{
    nop %sh{npx prettier --stdin-filepath=%val{buffile}}
}

hook global WinSetOption filetype=(rust) %{
    #remove-hooks buffer cargo-hooks
    unmap global lsp f ":format <ret>"
    map global lsp f ":lsp-formatting <ret>" -docstring "format using lsp"
}

hook global WinSetOption filetype=(javascript|typescript|tsx|json|html|vue) %{
  evaluate-commands %sh{
    if [ -n "$kak_buffile" ]; then
      dir=$(dirname "$kak_buffile")
    else
      dir="$PWD"
    fi
    git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
    pkg_json="$git_root/package.json"

    if [ -n "$git_root" ] && [ -f "$pkg_json" ] && grep -q '"oxfmt"' "$pkg_json"; then
      printf 'set-option window formatcmd "npx oxfmt --stdin-filepath=%%val{buffile}"\n'
      printf 'map global lsp f ":format <ret>" -docstring "format oxfmt"\n'
    else
      printf 'set-option window formatcmd "npx prettier --stdin-filepath=%%val{buffile}"\n'
      printf 'map global lsp f ":format <ret>" -docstring "format prettier"\n'
    fi
  }
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
define-command -override toggle-wrap -docstring 'toggle line wrapping' %{
    try %{
        add-highlighter window/wrap wrap -word -indent
        echo 'wrap on'
    } catch %{
        remove-highlighter window/wrap
        echo 'wrap off'
    }
}
# The window user mode and the ide command have three backends, picked per client:
# tmux panes inside tmux, kitty splits inside kitty when kitty_splits is set
# (kitty.kak), and Hyprland-tiled windows otherwise (hypr.kak; inside kitty those
# are OS windows of the client's kitty).
# window-dispatch <tmux command> <kitty command> <hyprland command> [args...]
define-command -hidden window-dispatch -params 3.. %{
    evaluate-commands %sh{
        if [ -n "$kak_client_env_TMUX" ]; then cmd=$1
        elif [ -n "$kak_client_env_KITTY_WINDOW_ID" ] && [ "$kak_opt_kitty_splits" = true ]; then cmd=$2
        else cmd=$3
        fi
        shift 3
        printf '%s' "$cmd"
        for arg; do printf " '%s'" "$(printf %s "$arg" | sed "s/'/''/g")"; done
        echo
    }
}

define-command tmux-split -params 1 -docstring 'tmux-split <r|d>: open a client in a new pane right/below' %{
    nop %sh{
        [ "$1" = d ] && flag=-v || flag=-h
        TMUX="$kak_client_env_TMUX" tmux split-window $flag kak -c "$kak_session"
    }
}

define-command tmux-select -params 1 -docstring 'tmux-select <l|d|u|r>: focus the pane in a direction' %{
    nop %sh{ TMUX="$kak_client_env_TMUX" tmux select-pane -$(echo "$1" | tr ldur LDUR) }
}

define-command tmux-zoom -docstring 'toggle zoom of the current pane' %{
    nop %sh{ TMUX="$kak_client_env_TMUX" tmux resize-pane -Z }
}

define-command window-split -params 1 -docstring 'window-split <h|v>: open a new client below (h) or right (v)' %{
    window-dispatch tmux-split kitty-split hypr-split %sh{ [ "$1" = h ] && printf d || printf r }
}

define-command window-select -params 1 -docstring 'window-select <l|d|u|r>: focus the pane/window in a direction' %{
    window-dispatch tmux-select kitty-select hypr-select %arg{1}
}

define-command window-zoom-toggle -docstring 'maximize/restore the current pane/window' %{
    window-dispatch tmux-zoom kitty-zoom hypr-zoom
}

# fzf pickers: the plugin uses a tmux popup inside tmux; elsewhere a kitty
# overlay or a floating ghostty window (class kak.popup, see hypr/hyprland.lua)
define-command -hidden window-popup -params 1 %{
    evaluate-commands %sh{
        [ -n "$kak_client_env_KITTY_WINDOW_ID" ] && cmd=kitty-popup || cmd=hypr-popup
        printf "%s '%s'\n" "$cmd" "$(printf %s "$1" | sed "s/'/''/g")"
    }
}
hook global ModuleLoaded fzf %{
    set-option global fzf_popup_command window-popup
}

map global window -docstring 'select pane left' h ':window-select l<ret>'
map global window -docstring 'select pane down' j ':window-select d<ret>'
map global window -docstring 'select pane up' k ':window-select u<ret>'
map global window -docstring 'select pane right' l ':window-select r<ret>'
map global window -docstring 'zoom' z ':window-zoom-toggle<ret>'
map global window -docstring 'split horizontal' <minus> ':window-split h<ret>'
map global window -docstring 'split vertical' '|'  ':window-split v<ret>'
map global window -docstring 'start ide' 'i'  ":ide <ret>"
map global window -docstring 'reset ide layout' 'r'  ":ide-reset <ret>"
map global window -docstring 'toggle wrap' 'w'  ":toggle-wrap<ret>"
map global user -docstring 'close all' 'Q'  ":close-ide <ret>"
map global user -docstring 'close window' 'q'  ":quit<ret>"
map global window -docstring 'close buffer' 'x'  ":delete-buffer <ret>"
map global window -docstring 'close buffer' 'X'  ":delete-buffer! <ret>"

map global user -docstring 'window mode' w ':enter-user-mode window<ret>'

map global window  -docstring 'zoom docs' d ":zoom docs<ret>"
map global window  -docstring 'zoom tools' t ":zoom tools<ret>"
map global window  -docstring 'zoom code' c ":zoom main<ret>"

map global window  -docstring 'focus docs' D ":focus docs<ret>"
map global window  -docstring 'focus tools' T ":focus tools<ret>"
map global window  -docstring 'focus code' C ":focus main<ret>"

# name the current client as one of the ide clients and point the matching option at it
declare-user-mode window-name
define-command ide-name-client -params 1 -docstring %{ide-name-client <main|docs|tools>: rename the current client and set jumpclient/docsclient/toolsclient} %{
    rename-client %arg{1}
    evaluate-commands %sh{
        case "$1" in
            main)  echo "set-option global jumpclient main" ;;
            docs)  echo "set-option global docsclient docs" ;;
            tools) echo "set-option global toolsclient tools" ;;
        esac
    }
    echo "client named %arg{1}"
}
map global window -docstring 'name client' n ':enter-user-mode window-name<ret>'
map global window-name -docstring 'name code (main)' c ':ide-name-client main<ret>'
map global window-name -docstring 'name docs' d ':ide-name-client docs<ret>'
map global window-name -docstring 'name tools' t ':ide-name-client tools<ret>'

define-command zoom -params 1 %{
    focus %arg{1}
    window-zoom-toggle
}
# IDE command
 
declare-option bool is_in_ide_mode 'false'
# Buffers the tools/docs clients reopen on when ide-reset rebuilds the layout
declare-option -hidden str ide_tools_buffer
declare-option -hidden str ide_docs_buffer
define-command ide  %{
    evaluate-commands %sh{
        if [ "$kak_opt_is_in_ide_mode" = "false" ]; then
            echo "echo 'Switching to ide'"
       else 
            echo "fail 'Already in ide mode'"
      fi
    }
    set-option global is_in_ide_mode 'true'


    rename-client main
    set-option global jumpclient main
    set-option global toolsclient tools
    set-option global docsclient docs

    window-dispatch ide-tmux kitty-ide-layout hypr-ide-layout
}

define-command -hidden ide-tmux %{
    set-option local windowing_placement horizontal
    new %{rename-client tools; try %{ buffer %opt{ide_tools_buffer} }}
    new %{rename-client docs; try %{ buffer %opt{ide_docs_buffer} }}

    nop %sh{
        export TMUX="$kak_client_env_TMUX"
        tmux select-layout main-vertical
        tmux swap-pane -s 3 -t 1
        tmux swap-pane -s 3 -t 2
        tmux resize-pane -t 2 -y 70%
        tmux select-pane -t 2
    }

}

# Rebuild the ide layout: close tools/docs and reopen them on the buffers they showed
define-command ide-reset -docstring 'restore the initial ide window layout' %{
    evaluate-commands %sh{
        [ "$kak_opt_is_in_ide_mode" = "true" ] || echo "fail 'Not in ide mode'"
    }
    set-option global ide_tools_buffer ''
    set-option global ide_docs_buffer ''
    evaluate-commands -try-client tools %{
        set-option global ide_tools_buffer %val{bufname}
        quit
    }
    evaluate-commands -try-client docs %{
        set-option global ide_docs_buffer %val{bufname}
        quit
    }
    evaluate-commands -client main %{ window-dispatch ide-tmux kitty-ide-reset hypr-ide-reset }
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

map -docstring "Run jest" global user <J> \
    %{:enter-user-mode jest<ret>}

declare-user-mode grep-mode
map -docstring "Grep" global user G ':enter-user-mode grep-mode<ret>'
map -docstring "grep (all files)" global grep-mode g ':grep-smart<ret>'
map -docstring "grep (same filetype)" global grep-mode f ':grep-smart-filetype<ret>'
map -docstring "grep (closest package.json)" global grep-mode p ':grep-smart-package<ret>'

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
declare-user-mode undo-tree
define-command try-undo-backward %{
    try %{
        execute-keys '<c-j>'
    }
}
define-command try-undo-forward %{
    try %{
        execute-keys '<c-k>'
    }
}

map global match-mode i '<a-i>' -docstring "Match inside"
map global undo-tree j ':try-undo-backward <ret>'
map global undo-tree k ':try-undo-forward <ret>'

map global user u ':enter-user-mode -lock undo-tree<ret>'  -docstring 'Undo Tree'
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


source ~/.config/kak/fzf/rc/modules/VCS/fzf-git.kak
source ~/.config/kak/fzf/rc/modules/fzf-vcs.kak
source ~/.config/kak/fzf/rc/modules/fzf-symbol.kak
