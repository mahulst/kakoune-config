define-command switch_case -params 1 %{
    evaluate-commands %{
        execute-keys "| ccase -t %arg{1}<ret>"
    }
}
declare-user-mode case

map global user -docstring 'switch case' k ':enter-user-mode case<ret>'

map -docstring "to snake" \
	global case s %{:switch_case snake <ret>}
map -docstring "to screamingsnake" \
	global case S %{:switch_case screamingsnake <ret>}
map -docstring "to camel" \
	global case c %{:switch_case camel <ret>}
map -docstring "to pascal" \
	global case C %{:switch_case pascal <ret>}
map -docstring "to lower" \
	global case l %{:switch_case lower <ret>}
map -docstring "to kebab" \
	global case k %{:switch_case kebab <ret>}

