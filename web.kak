declare-option str webcommand %sh{
    if [ "$(uname)" = "Darwin" ]; then
        echo '/Applications/Nix\ Apps/Firefox.app/Contents/MacOS/firefox --new-tab '
    else
        echo 'xdg-open '
    fi
}
define-command open-in-browser -params 1 %{
    nop %sh{
        eval "$kak_opt_webcommand" $1
    }
}
