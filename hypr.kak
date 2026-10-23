# Window management outside tmux: Ghostty windows tiled by Hyprland.
# The window user mode and the ide command dispatch here when $TMUX is unset.
# The Hyprland side lives in hypr.sh.

declare-option -hidden str hypr_script %sh{ echo "${kak_source%/*}/hypr.sh" }

# Kakoune's wayland module doesn't know ghostty and falls back to foot
hook global ModuleLoaded wayland %{
    set-option global termcmd 'ghostty -e sh -c'
}

# The stock hyprland-focus uses the pre-Lua dispatch syntax and focuses by pid,
# which is shared by all windows of a single-instance ghostty. hypr.sh matches
# the terminal title instead ("... - <client>@[<session>] - Kakoune").
hook global ModuleLoaded hyprland %{
    alias global focus hypr-focus
}

define-command hypr-focus -params ..1 -docstring 'hypr-focus [<client>]: focus the window of a kakoune client' %{
    nop %sh{ sh "$kak_opt_hypr_script" focus "${1:-$kak_client}" "$kak_session" }
}
complete-command -menu hypr-focus client

define-command hypr-split -params 1.. -docstring 'hypr-split <r|d> [<commands>]: open a client in a new window right/below' %{
    nop %sh{
        dir=$1; shift
        TERMCMD="$kak_opt_termcmd" sh "$kak_opt_hypr_script" split "$dir" "$kak_session" "$@" </dev/null >/dev/null 2>&1 &
    }
}

define-command hypr-select -params 1 -docstring 'hypr-select <l|r|u|d>: move focus in a direction' %{
    nop %sh{ sh "$kak_opt_hypr_script" select "$1" }
}

define-command hypr-zoom -docstring 'toggle maximize of the focused window' %{
    nop %sh{ sh "$kak_opt_hypr_script" zoom }
}

# Runs in the background: the new clients have to connect to this server
define-command -hidden hypr-ide-layout %{
    nop %sh{
        TERMCMD="$kak_opt_termcmd" sh "$kak_opt_hypr_script" ide "$kak_session" </dev/null >/dev/null 2>&1 &
    }
}

define-command -hidden hypr-ide-reset %{
    nop %sh{
        TERMCMD="$kak_opt_termcmd" sh "$kak_opt_hypr_script" reset "$kak_session" </dev/null >/dev/null 2>&1 &
    }
}

# fzf pickers open in a floating window (class kak.popup, see hypr/hyprland.lua)
# instead of a tiled one, like the tmux popup they get inside tmux
define-command hypr-popup -params 1 -docstring 'hypr-popup <command>: run a command in a floating terminal' %{
    nop %sh{ setsid ghostty --class=kak.popup -e "$1" </dev/null >/dev/null 2>&1 & }
}
hook global ModuleLoaded fzf %{
    set-option global fzf_popup_command hypr-popup
}
