declare-option str webcommand "/Applications/Nix\ Apps/Firefox.app/Contents/MacOS/firefox --new-tab "
define-command open-in-browser -params 1 %{
    nop %sh{
        eval "$kak_opt_webcommand" $1
    }
}
