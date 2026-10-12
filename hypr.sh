#!/bin/sh
# Hyprland window management for kakoune clients (used by hypr.kak).
# Works with the dwindle and scrolling layouts, using the Lua dispatch syntax.
#
#   hypr.sh ide <session>                  tools left (30% wide), main right 80% high, docs below 20%
#   hypr.sh split <r|d> <session> [cmds]   open a client right of / below the focused window
#   hypr.sh focus <client> <session>       focus the window of a kakoune client
#   hypr.sh select <l|r|u|d>               move focus in a direction
#   hypr.sh zoom                           toggle maximize of the focused window
#
# $TERMCMD is the terminal prefix that takes a shell command, e.g. 'ghostty -e sh -c'.

dispatch() { hyprctl dispatch "$1" >/dev/null; }
layoutmsg() { dispatch "hl.dsp.layout(\"$1\")"; }
active() { hyprctl activewindow -j | jq -r .address; }
layout() { hyprctl activeworkspace -j | jq -r .tiledLayout; }
focus_address() { dispatch "hl.dsp.focus({ window = \"address:$1\" })"; }

# Restore the focused window if it is maximized/fullscreen. Otherwise the
# window that receives focus takes it over (misc:on_focus_under_fullscreen = 1)
unzoom() {
    case $(hyprctl activewindow -j | jq -r .fullscreen) in
        1) dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })' ;;
        2) dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen" })' ;;
    esac
}

# Start a kakoune client in a new terminal and print its window address once it
# has mapped (new windows take focus, so wait for the active window to change)
spawn() {
    session=$1; shift
    cmd="kak -c $session"
    [ $# -gt 0 ] && cmd="$cmd -e '$*'"
    before=$(active)
    setsid $TERMCMD "$cmd" </dev/null >/dev/null 2>&1 &
    for _ in $(seq 50); do
        now=$(active)
        if [ "$now" != "$before" ] && [ "$now" != null ]; then
            echo "$now"
            return
        fi
        sleep 0.1
    done
    return 1
}

# Open a client right of (r) or below (d) the focused window
split() {
    dir=$1; session=$2; shift 2
    if [ "$(layout)" = scrolling ]; then
        spawn "$session" "$@" >/dev/null || return
        # scrolling always opens a new column to the right; stack it instead
        [ "$dir" = d ] && layoutmsg "consume_or_expel prev"
    else
        layoutmsg "preselect $dir"
        spawn "$session" "$@" >/dev/null
    fi
}

ide() {
    session=$1
    main=$(active)
    if [ "$(layout)" = scrolling ]; then
        tools=$(spawn "$session" rename-client tools) || return
        layoutmsg "swapcol l"
        focus_address "$main"
        docs=$(spawn "$session" rename-client docs) || return
        layoutmsg "consume_or_expel prev"
    else
        layoutmsg "preselect l"
        tools=$(spawn "$session" rename-client tools) || return
        focus_address "$main"
        layoutmsg "preselect d"
        docs=$(spawn "$session" rename-client docs) || return
    fi
    sleep 0.2

    # Give main 80% of the column height, docs the rest
    focus_address "$main"
    dy=$(hyprctl clients -j | jq --arg m "$main" --arg d "$docs" '
        (map(select(.address == $m))[0].size[1]) as $mh |
        (map(select(.address == $d))[0].size[1]) as $dh |
        (($mh + $dh) * 0.8 - $mh) | floor')
    [ -n "$dy" ] && dispatch "hl.dsp.window.resize({ x = 0, y = $dy, relative = true })"

    # Tools gets 30% of the width, main/docs the rest
    if [ "$(layout)" = scrolling ]; then
        layoutmsg "colresize 0.7"
        focus_address "$tools"
        layoutmsg "colresize 0.3"
    else
        focus_address "$tools"
        dx=$(hyprctl clients -j | jq --arg t "$tools" --arg m "$main" '
            (map(select(.address == $t))[0].size[0]) as $tw |
            (map(select(.address == $m))[0].size[0]) as $mw |
            (($tw + $mw) * 0.3 - $tw) | floor')
        [ -n "$dx" ] && dispatch "hl.dsp.window.resize({ x = $dx, y = 0, relative = true })"
    fi
    focus_address "$main"
}

case $1 in
    ide)    shift; ide "$@" ;;
    split)  shift; split "$@" ;;
    focus)  unzoom; dispatch "hl.dsp.focus({ window = [==[title:.* - $2@\\[$3\\] - Kakoune]==] })" ;;
    select) unzoom; dispatch "hl.dsp.focus({ direction = \"$2\" })" ;;
    zoom)   dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })' ;;
    *)      echo "usage: hypr.sh ide|split|focus|select|zoom ..." >&2; exit 1 ;;
esac
