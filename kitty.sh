#!/bin/sh
# kitty window management for kakoune clients (used by kitty.kak).
# Everything goes through kitty remote control, which Omarchy enables
# (allow_remote_control socket-only, listen_on in /etc/xdg/kitty/kitty.conf).
# The caller sets KITTY_LISTEN_ON and KITTY_WINDOW_ID to the socket and window
# of the kakoune client, see kitty.kak.
#
#   kitty.sh ide <session>                 tools left (30% wide), main right 80% high, docs below 20%
#   kitty.sh reset <session>               rebuild the ide layout once tools/docs are closed
#   kitty.sh split <r|d> <session> [cmds]  open a client right of / below the client's window
#   kitty.sh focus                         focus the client's window
#   kitty.sh select <l|r|u|d>              move focus in a direction
#   kitty.sh zoom                          toggle the stack layout, like tmux's zoom
#   kitty.sh popup <script>                run a script in an overlay over the client's window

win=${KITTY_WINDOW_ID:?}
rc() { kitten @ "$@"; }

# Layout of the tab that holds a window
layout() { rc ls --match "id:$1" | jq -r '.[].tabs[].layout'; }

# Zoom is the stack layout. Toggling it from the window's tab restores the
# previous layout with its splits intact. toggle_layout only knows the active
# tab, so focus the window first (remote control can't scope actions to a tab).
unzoom() {
    [ "$(layout "$1")" = stack ] || return 0
    rc focus-window --match "id:$1"
    rc action toggle_layout stack
}

# Start a kakoune client in a new window next to $win, with extra launch
# options from $launch_opts. Prints the new window's id.
spawn() {
    session=$1; shift
    if [ $# -gt 0 ]; then set -- kak -c "$session" -e "$*"; else set -- kak -c "$session"; fi
    # shellcheck disable=SC2086
    rc launch --type=window --match "window_id:$win" --next-to "id:$win" --cwd="$PWD" $launch_opts "$@"
}

# Open a client right of (r) or below (d) the window
split() {
    dir=$1; session=$2; shift 2
    unzoom "$win"
    [ "$dir" = d ] && loc=hsplit || loc=vsplit
    launch_opts="--location=$loc" spawn "$session" "$@" >/dev/null
}

ide() {
    session=$1
    # The ide layout needs manual splits (this also leaves the stack layout)
    rc goto-layout --match "window_id:$win" splits
    # "before" splits along splits_axis (horizontal by default): tools left of main
    launch_opts='--location=before --bias=30 --keep-focus' \
        spawn "$session" "rename-client tools; try %{ buffer %opt{ide_tools_buffer} }" >/dev/null || return
    launch_opts='--location=hsplit --bias=20 --keep-focus' \
        spawn "$session" "rename-client docs; try %{ buffer %opt{ide_docs_buffer} }" >/dev/null || return
    rc focus-window --match "id:$win"
}

# Wait for the old tools/docs windows to close, then rebuild from main
reset() {
    session=$1
    for _ in $(seq 30); do
        rc ls --match "title:.* - (tools|docs)@\\[$session\\] - Kakoune\$" >/dev/null 2>&1 || break
        sleep 0.1
    done
    ide "$session"
}

select_dir() {
    case $1 in
        l) side=left ;; r) side=right ;; u) side=top ;; d) side=bottom ;;
        *) echo "kitty.sh select: unknown direction $1" >&2; return 1 ;;
    esac
    unzoom "$win"
    # neighbors holds window group ids; the tab's groups map them back to windows
    target=$(rc ls --match "id:$win" | jq -r --arg s "$side" '
        .[].tabs[] | (.windows[0].neighbors[$s] // [])[0] as $group |
        .groups[] | select(.id == $group) | .windows[-1]')
    [ -n "$target" ] && rc focus-window --match "id:$target"
}

case $1 in
    ide)    shift; ide "$@" ;;
    reset)  shift; reset "$@" ;;
    split)  shift; split "$@" ;;
    focus)  unzoom "$win"; rc focus-window --match "id:$win" ;;
    select) shift; select_dir "$@" ;;
    zoom)   rc action toggle_layout stack ;;
    popup)  rc launch --type=overlay --match "window_id:$win" --next-to "id:$win" --cwd="$PWD" "$2" >/dev/null ;;
    *)      echo "usage: kitty.sh ide|reset|split|focus|select|zoom|popup ..." >&2; exit 1 ;;
esac
