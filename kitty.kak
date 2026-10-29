# Clients inside kitty. By default the window user mode and the ide command open
# new OS windows of the same kitty, tiled by Hyprland (hypr.kak + hypr.sh). With
# kitty_splits they use kitty windows (splits) in the client's tab instead,
# through kitty.sh. fzf popups are a kitty overlay either way.
#
# Needs remote control, which Omarchy enables for every kitty (allow_remote_control
# socket-only and listen_on in /etc/xdg/kitty/kitty.conf), so each client has
# KITTY_LISTEN_ON and KITTY_WINDOW_ID in its environment.

declare-option -docstring %{inside kitty, open ide and split clients as kitty splits in the current tab instead of as new OS windows (set it in kakrc)} \
    bool kitty_splits false

declare-option -hidden str kitty_script %sh{ echo "${kak_source%/*}/kitty.sh" }

# The bundled kitty module aliases focus to kitty-focus, which can't raise another
# OS window under Hyprland. Focus through Hyprland instead, or, with splits, through
# kitty while leaving the stack layout first, like tmux's select-pane does when zoomed.
hook global ModuleLoaded kitty %{
    alias global focus kitty-focus-client
    # new/terminal open an OS window too unless splits are wanted
    evaluate-commands %sh{
        [ "$kak_opt_kitty_splits" = true ] || echo 'set-option global kitty_window_type os-window'
    }
}

define-command kitty-focus-client -params ..1 -docstring 'kitty-focus-client [<client>]: focus the window of a kakoune client' %{
    evaluate-commands %sh{
        [ "$kak_opt_kitty_splits" = true ] && cmd=kitty-focus-split || cmd=hypr-focus
        printf '%s' "$cmd"
        [ $# -eq 1 ] && printf " '%s'" "$(printf %s "$1" | sed "s/'/''/g")"
        echo
    }
}
complete-command -menu kitty-focus-client client

define-command -hidden kitty-focus-split -params ..1 %{
    evaluate-commands -client %sh{ printf %s "${1:-$kak_client}" } %{
        nop %sh{
            KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
                sh "$kak_opt_kitty_script" focus
        }
    }
}

define-command kitty-split -params 1.. -docstring 'kitty-split <r|d> [<commands>]: open a client in a new kitty window right/below' %{
    nop %sh{
        dir=$1; shift
        KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
            sh "$kak_opt_kitty_script" split "$dir" "$kak_session" "$@"
    }
}

define-command kitty-select -params 1 -docstring 'kitty-select <l|r|u|d>: move focus in a direction' %{
    nop %sh{
        KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
            sh "$kak_opt_kitty_script" select "$1"
    }
}

define-command kitty-zoom -docstring 'toggle the stack layout: show only the focused window' %{
    nop %sh{
        KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
            sh "$kak_opt_kitty_script" zoom
    }
}

define-command -hidden kitty-ide-layout %{
    nop %sh{
        KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
            sh "$kak_opt_kitty_script" ide "$kak_session"
    }
}

# Runs in the background: it waits for the old tools/docs clients to exit, which
# this server only gets to once the shell returns
define-command -hidden kitty-ide-reset %{
    nop %sh{
        KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
            sh "$kak_opt_kitty_script" reset "$kak_session" </dev/null >/dev/null 2>&1 &
    }
}

# fzf pickers run in an overlay over the current window, like the tmux popup
# they get inside tmux
define-command kitty-popup -params 1 -docstring 'kitty-popup <script>: run a script in an overlay over the current window' %{
    nop %sh{
        KITTY_LISTEN_ON="$kak_client_env_KITTY_LISTEN_ON" KITTY_WINDOW_ID="$kak_client_env_KITTY_WINDOW_ID" \
            sh "$kak_opt_kitty_script" popup "$1"
    }
}
